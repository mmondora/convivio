/**
 * Extract Wine from Photo
 *
 * Pipeline:
 * 1. Receive photo URL from Firebase Storage
 * 2. Google Vision API for OCR
 * 3. Claude for interpretation and mapping to Wine schema
 * 4. Fuzzy matching with existing wines
 * 5. Return extracted data + suggested matches
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { ImageAnnotatorClient } from '@google-cloud/vision';
import Anthropic from '@anthropic-ai/sdk';
import { logger } from 'firebase-functions';
import { z } from 'zod';
import type {
  ExtractWineRequest,
  ExtractWineResponse,
  ExtractionResult,
  Wine
} from '../types';

const db = getFirestore();
const vision = new ImageAnnotatorClient();

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

// ============================================================
// VALIDATION
// ============================================================

const RequestSchema = z.object({
  photoUrl: z.string().url(),
  userId: z.string().min(1),
});

const ExtractedWineSchema = z.object({
  name: z.object({ value: z.string(), confidence: z.number() }).optional(),
  producer: z.object({ value: z.string(), confidence: z.number() }).optional(),
  vintage: z.object({ value: z.string(), confidence: z.number() }).optional(),
  type: z.object({ value: z.string(), confidence: z.number() }).optional(),
  region: z.object({ value: z.string(), confidence: z.number() }).optional(),
  country: z.object({ value: z.string(), confidence: z.number() }).optional(),
  grapes: z.object({ value: z.array(z.string()), confidence: z.number() }).optional(),
  alcohol: z.object({ value: z.number(), confidence: z.number() }).optional(),
});

// ============================================================
// MAIN FUNCTION
// ============================================================

export const extractWineFromPhoto = onCall<ExtractWineRequest>(
  {
    region: 'europe-west1',
    memory: '512MiB',
    timeoutSeconds: 60,
    secrets: ['ANTHROPIC_API_KEY'],
  },
  async (request): Promise<ExtractWineResponse> => {
    // Validate request
    const validation = RequestSchema.safeParse(request.data);
    if (!validation.success) {
      throw new HttpsError('invalid-argument', 'Invalid request: ' + validation.error.message);
    }

    const { photoUrl, userId } = validation.data;

    // Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Cannot extract for another user');
    }

    logger.info('Starting wine extraction', { userId, photoUrl });

    try {
      // Step 1: OCR with Vision API
      const ocrText = await performOcr(photoUrl);
      logger.info('OCR completed', { textLength: ocrText.length });

      if (!ocrText || ocrText.length < 10) {
        return {
          success: false,
          error: 'Nessun testo rilevato nell\'immagine',
        };
      }

      // Step 2: LLM interpretation
      const extractedFields = await interpretWithLlm(ocrText);
      logger.info('LLM interpretation completed', { fields: Object.keys(extractedFields) });

      // Step 3: Calculate overall confidence
      const overallConfidence = calculateOverallConfidence(extractedFields);

      // Step 4: Find similar wines
      const suggestedMatches = await findSimilarWines(userId, extractedFields);
      logger.info('Found similar wines', { count: suggestedMatches.length });

      const extraction: ExtractionResult = {
        ocrText,
        extractedFields,
        overallConfidence,
      };

      return {
        success: true,
        extraction,
        suggestedMatches,
      };

    } catch (error) {
      logger.error('Extraction failed', { userId, error });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Estrazione fallita: ' + (error as Error).message);
    }
  }
);

// ============================================================
// OCR
// ============================================================

async function performOcr(imageUrl: string): Promise<string> {
  const [result] = await vision.textDetection(imageUrl);
  const detections = result.textAnnotations;

  if (!detections || detections.length === 0) {
    return '';
  }

  // First detection is the full text
  return detections[0].description || '';
}

// ============================================================
// LLM INTERPRETATION
// ============================================================

const EXTRACTION_PROMPT = `Analizza il seguente testo estratto da un'etichetta di vino e identifica le informazioni chiave.

TESTO OCR:
{ocr_text}

Estrai le seguenti informazioni se presenti, con un livello di confidenza (0.0-1.0):
- name: Nome del vino (es. "Barolo", "Amarone della Valpolicella")
- producer: Produttore/Cantina (es. "Giacomo Conterno", "Antinori")
- vintage: Anno di vendemmia (es. "2018")
- type: Tipo di vino (red, white, rosé, sparkling, dessert, fortified)
- region: Regione di produzione (es. "Piemonte", "Toscana")
- country: Paese (es. "Italia", "Francia")
- grapes: Vitigni utilizzati (array, es. ["Nebbiolo"], ["Sangiovese", "Merlot"])
- alcohol: Gradazione alcolica in % (es. 14.5)

Regole:
- Se un'informazione non è chiaramente presente, non includerla
- La confidenza riflette quanto sei sicuro dell'informazione estratta
- Per il tipo di vino, deducilo dal vitigno o dalla denominazione se non esplicito
- Normalizza i nomi delle regioni e dei paesi

Rispondi SOLO con JSON valido nel seguente formato:
{
  "name": { "value": "Nome Vino", "confidence": 0.95 },
  "producer": { "value": "Cantina", "confidence": 0.90 },
  "vintage": { "value": "2018", "confidence": 0.98 },
  "type": { "value": "red", "confidence": 0.95 },
  "region": { "value": "Piemonte", "confidence": 0.85 },
  "country": { "value": "Italia", "confidence": 0.90 },
  "grapes": { "value": ["Nebbiolo"], "confidence": 0.80 },
  "alcohol": { "value": 14.5, "confidence": 0.95 }
}`;

async function interpretWithLlm(ocrText: string): Promise<ExtractionResult['extractedFields']> {
  const prompt = EXTRACTION_PROMPT.replace('{ocr_text}', ocrText);

  // Log AI input
  logger.info('=== AI REQUEST (extractWineFromPhoto) ===');
  logger.info('OCR TEXT:', { ocrText });

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    messages: [
      { role: 'user', content: prompt }
    ],
  });

  const responseText = response.content
    .filter(block => block.type === 'text')
    .map(block => (block as { type: 'text'; text: string }).text)
    .join('');

  // Log AI output
  logger.info('=== AI RESPONSE (extractWineFromPhoto) ===');
  logger.info('RESPONSE:', { responseText });

  // Parse JSON response
  try {
    const jsonText = responseText
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();

    const parsed = JSON.parse(jsonText);
    const validated = ExtractedWineSchema.parse(parsed);

    return validated;
  } catch (error) {
    logger.error('Failed to parse LLM response', { error, responseText });
    return {};
  }
}

// ============================================================
// CONFIDENCE CALCULATION
// ============================================================

function calculateOverallConfidence(fields: ExtractionResult['extractedFields']): number {
  const confidences: number[] = [];

  if (fields.name?.confidence) confidences.push(fields.name.confidence * 1.5); // Weight name higher
  if (fields.producer?.confidence) confidences.push(fields.producer.confidence);
  if (fields.vintage?.confidence) confidences.push(fields.vintage.confidence);
  if (fields.type?.confidence) confidences.push(fields.type.confidence);
  if (fields.region?.confidence) confidences.push(fields.region.confidence);
  if (fields.country?.confidence) confidences.push(fields.country.confidence);

  if (confidences.length === 0) return 0;

  const sum = confidences.reduce((a, b) => a + b, 0);
  return Math.min(1, sum / (confidences.length + 0.5)); // Normalize
}

// ============================================================
// SIMILAR WINE MATCHING
// ============================================================

async function findSimilarWines(
  userId: string,
  fields: ExtractionResult['extractedFields']
): Promise<Wine[]> {
  if (!fields.name?.value) {
    return [];
  }

  const searchName = fields.name.value.toLowerCase();
  const searchProducer = fields.producer?.value?.toLowerCase();

  // Get user's cellars
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();

  if (cellarsSnapshot.empty) {
    return [];
  }

  // Get all wine IDs from user's cellars
  const wineIds = new Set<string>();
  for (const cellarDoc of cellarsSnapshot.docs) {
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles').get();
    bottlesSnapshot.docs.forEach(b => wineIds.add(b.data().wineId));
  }

  // Find matching wines
  const matches: { wine: Wine; score: number }[] = [];
  for (const wineId of wineIds) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (!wineDoc.exists) continue;

    const wine = { id: wineDoc.id, ...wineDoc.data() } as Wine;
    const wineName = wine.name.toLowerCase();
    const wineProducer = wine.producer?.toLowerCase();

    // Calculate similarity score
    let score = 0;

    // Name matching
    if (wineName.includes(searchName) || searchName.includes(wineName)) {
      score += 50;
    } else {
      const nameWords = searchName.split(/\s+/);
      const matchingWords = nameWords.filter(w => wineName.includes(w));
      score += (matchingWords.length / nameWords.length) * 30;
    }

    // Producer matching
    if (searchProducer && wineProducer) {
      if (wineProducer.includes(searchProducer) || searchProducer.includes(wineProducer)) {
        score += 30;
      }
    }

    // Type matching
    if (fields.type?.value && wine.type === fields.type.value) {
      score += 10;
    }

    // Region matching
    if (fields.region?.value && wine.region?.toLowerCase().includes(fields.region.value.toLowerCase())) {
      score += 10;
    }

    if (score > 20) {
      matches.push({ wine, score });
    }
  }

  // Sort by score and return top 5
  return matches
    .sort((a, b) => b.score - a.score)
    .slice(0, 5)
    .map(m => m.wine);
}

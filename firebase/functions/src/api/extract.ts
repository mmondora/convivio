/**
 * Extract Wine from Photo
 * 
 * Pipeline completa:
 * 1. Ricevi URL immagine (già caricata su Firebase Storage)
 * 2. Google Vision API per OCR
 * 3. Claude per interpretazione e mapping su schema Wine
 * 4. Fuzzy matching su vini esistenti
 * 5. Ritorna dati estratti + suggerimenti match
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { ImageAnnotatorClient } from '@google-cloud/vision';
import Anthropic from '@anthropic-ai/sdk';
import { logger } from 'firebase-functions';
import { z } from 'zod';
import type { 
  ExtractWineRequest, 
  ExtractWineResponse, 
  ExtractionResult, 
  Wine,
  WineType 
} from '../types';

const db = getFirestore();
const vision = new ImageAnnotatorClient();

// Initialize Anthropic client
const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

// ============================================================
// VALIDATION SCHEMAS
// ============================================================

const RequestSchema = z.object({
  photoUrl: z.string().url(),
  userId: z.string().min(1),
});

const ExtractedWineSchema = z.object({
  name: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
  producer: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
  vintage: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
  type: z.object({
    value: z.enum(['red', 'white', 'rosé', 'sparkling', 'dessert', 'fortified']),
    confidence: z.number().min(0).max(1),
  }).optional(),
  region: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
  country: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
  alcoholContent: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
  grapes: z.object({
    value: z.string(),
    confidence: z.number().min(0).max(1),
  }).optional(),
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
    const startTime = Date.now();
    
    // Validate request
    const validation = RequestSchema.safeParse(request.data);
    if (!validation.success) {
      throw new HttpsError('invalid-argument', 'Invalid request: ' + validation.error.message);
    }
    
    const { photoUrl, userId } = validation.data;
    
    // Verify user is authenticated
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Cannot extract for another user');
    }
    
    logger.info('Starting wine extraction', { userId, photoUrl: photoUrl.substring(0, 50) });
    
    try {
      // Step 1: OCR with Google Vision
      const ocrResult = await performOcr(photoUrl);
      logger.info('OCR completed', { textLength: ocrResult.text.length });
      
      if (!ocrResult.text || ocrResult.text.length < 5) {
        return {
          success: false,
          error: 'Nessun testo rilevato nell\'immagine. Prova con una foto più nitida dell\'etichetta.'
        };
      }
      
      // Step 2: LLM interpretation
      const extractedFields = await interpretWithLlm(ocrResult.text);
      logger.info('LLM interpretation completed', { 
        fieldsExtracted: Object.keys(extractedFields).length 
      });
      
      // Calculate overall confidence
      const confidences = Object.values(extractedFields)
        .filter(f => f !== undefined)
        .map(f => (f as { confidence: number }).confidence);
      const overallConfidence = confidences.length > 0 
        ? confidences.reduce((a, b) => a + b, 0) / confidences.length 
        : 0;
      
      // Step 3: Save extraction result
      const extractionRef = db.collection('users').doc(userId).collection('extractions').doc();
      const extraction: Omit<ExtractionResult, 'id'> = {
        photoAssetId: photoUrl, // In realtà dovremmo avere un photoAssetId separato
        rawOcrText: ocrResult.text,
        extractedFields,
        overallConfidence,
        wasManuallyEdited: false,
        createdAt: Timestamp.now(),
      };
      
      await extractionRef.set(extraction);
      
      // Step 4: Find similar wines
      const suggestedMatches = await findSimilarWines(extractedFields, userId);
      
      const totalTime = Date.now() - startTime;
      logger.info('Extraction completed', { 
        extractionId: extractionRef.id, 
        overallConfidence,
        matchesFound: suggestedMatches.length,
        totalTimeMs: totalTime
      });
      
      return {
        success: true,
        extraction: {
          id: extractionRef.id,
          ...extraction,
        } as ExtractionResult,
        suggestedMatches,
      };
      
    } catch (error) {
      logger.error('Extraction failed', { userId, error });
      throw new HttpsError('internal', 'Estrazione fallita: ' + (error as Error).message);
    }
  }
);

// ============================================================
// OCR FUNCTION
// ============================================================

interface OcrResult {
  text: string;
  confidence: number;
  blocks: Array<{
    text: string;
    confidence: number;
    bounds: { x: number; y: number; width: number; height: number };
  }>;
}

async function performOcr(imageUrl: string): Promise<OcrResult> {
  const [result] = await vision.textDetection({
    image: { source: { imageUri: imageUrl } },
    imageContext: {
      languageHints: ['it', 'fr', 'en', 'de', 'es'], // Lingue comuni per etichette vino
    },
  });
  
  const annotations = result.textAnnotations || [];
  
  if (annotations.length === 0) {
    return { text: '', confidence: 0, blocks: [] };
  }
  
  // First annotation is the full text
  const fullText = annotations[0]?.description || '';
  
  // Subsequent annotations are individual words/blocks
  const blocks = annotations.slice(1).map(ann => ({
    text: ann.description || '',
    confidence: ann.confidence || 0.5,
    bounds: {
      x: ann.boundingPoly?.vertices?.[0]?.x || 0,
      y: ann.boundingPoly?.vertices?.[0]?.y || 0,
      width: (ann.boundingPoly?.vertices?.[2]?.x || 0) - (ann.boundingPoly?.vertices?.[0]?.x || 0),
      height: (ann.boundingPoly?.vertices?.[2]?.y || 0) - (ann.boundingPoly?.vertices?.[0]?.y || 0),
    },
  }));
  
  // Calculate average confidence
  const avgConfidence = blocks.length > 0
    ? blocks.reduce((sum, b) => sum + b.confidence, 0) / blocks.length
    : 0.5;
  
  return {
    text: fullText,
    confidence: avgConfidence,
    blocks,
  };
}

// ============================================================
// LLM INTERPRETATION
// ============================================================

const EXTRACTION_PROMPT = `Sei un esperto sommelier. Analizza il testo OCR di un'etichetta di vino ed estrai le informazioni strutturate.

TESTO OCR:
{ocr_text}

Estrai le seguenti informazioni se presenti. Per ogni campo, fornisci:
- value: il valore estratto
- confidence: un numero da 0 a 1 che indica quanto sei sicuro dell'estrazione

Campi da estrarre:
- name: Nome del vino (es. "Barolo Monfortino", "Chianti Classico Riserva")
- producer: Produttore/Cantina (es. "Giacomo Conterno", "Antinori")
- vintage: Anno di vendemmia (es. "2018")
- type: Tipo di vino (red, white, rosé, sparkling, dessert, fortified)
- region: Regione/Denominazione (es. "Piemonte", "Toscana", "Bordeaux")
- country: Paese (es. "Italia", "Francia")
- alcoholContent: Gradazione alcolica (es. "14.5")
- grapes: Vitigno/i (es. "Nebbiolo", "Sangiovese, Cabernet Sauvignon")

Regole:
1. Se un'informazione non è chiaramente presente, non includerla
2. Per il tipo, deducilo dal vitigno o dalla denominazione se non esplicito
3. Normalizza i nomi (maiuscole appropriate, no abbreviazioni strane)
4. La confidence dovrebbe essere alta (>0.8) solo se l'informazione è chiaramente leggibile
5. Rispondi SOLO con il JSON, senza testo aggiuntivo

Esempio di output:
{
  "name": { "value": "Barolo Monfortino", "confidence": 0.95 },
  "producer": { "value": "Giacomo Conterno", "confidence": 0.90 },
  "vintage": { "value": "2016", "confidence": 0.98 },
  "type": { "value": "red", "confidence": 0.95 },
  "region": { "value": "Piemonte", "confidence": 0.85 },
  "country": { "value": "Italia", "confidence": 0.90 }
}`;

async function interpretWithLlm(ocrText: string): Promise<ExtractionResult['extractedFields']> {
  const prompt = EXTRACTION_PROMPT.replace('{ocr_text}', ocrText);
  
  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 1024,
    messages: [
      { role: 'user', content: prompt }
    ],
  });
  
  // Extract text from response
  const responseText = response.content
    .filter(block => block.type === 'text')
    .map(block => (block as { type: 'text'; text: string }).text)
    .join('');
  
  // Parse JSON response
  try {
    // Remove potential markdown code blocks
    const jsonText = responseText
      .replace(/```json\n?/g, '')
      .replace(/```\n?/g, '')
      .trim();
    
    const parsed = JSON.parse(jsonText);
    
    // Validate with Zod
    const validated = ExtractedWineSchema.parse(parsed);
    return validated;
    
  } catch (error) {
    logger.warn('Failed to parse LLM response', { responseText, error });
    return {};
  }
}

// ============================================================
// FUZZY MATCHING
// ============================================================

async function findSimilarWines(
  extractedFields: ExtractionResult['extractedFields'],
  userId: string
): Promise<Wine[]> {
  const matches: Wine[] = [];
  
  // If we don't have a name, we can't match
  if (!extractedFields.name?.value) {
    return matches;
  }
  
  const extractedName = extractedFields.name.value.toLowerCase();
  const extractedProducer = extractedFields.producer?.value?.toLowerCase() || '';
  const extractedVintage = extractedFields.vintage?.value || '';
  
  // Query wines collection
  // Note: Firestore doesn't support full-text search, so we do a simple query
  // and filter in memory. For production, consider Algolia or Typesense.
  const winesSnapshot = await db.collection('wines')
    .where('createdBy', '==', userId) // Only user's wines for now
    .limit(100)
    .get();
  
  for (const doc of winesSnapshot.docs) {
    const wine = { id: doc.id, ...doc.data() } as Wine;
    
    // Calculate similarity score
    let score = 0;
    
    // Name similarity (simple contains check)
    const wineName = wine.name.toLowerCase();
    if (wineName === extractedName) {
      score += 3;
    } else if (wineName.includes(extractedName) || extractedName.includes(wineName)) {
      score += 2;
    } else if (levenshteinSimilarity(wineName, extractedName) > 0.7) {
      score += 1;
    }
    
    // Producer match
    if (wine.producer && extractedProducer) {
      const wineProducer = wine.producer.toLowerCase();
      if (wineProducer === extractedProducer) {
        score += 2;
      } else if (wineProducer.includes(extractedProducer) || extractedProducer.includes(wineProducer)) {
        score += 1;
      }
    }
    
    // Vintage match
    if (wine.vintage && extractedVintage) {
      if (wine.vintage.toString() === extractedVintage) {
        score += 1;
      }
    }
    
    if (score >= 2) {
      matches.push(wine);
    }
  }
  
  // Sort by relevance and return top 3
  return matches
    .sort((a, b) => {
      // Exact name match first
      const aExact = a.name.toLowerCase() === extractedName ? 1 : 0;
      const bExact = b.name.toLowerCase() === extractedName ? 1 : 0;
      return bExact - aExact;
    })
    .slice(0, 3);
}

/**
 * Simple Levenshtein-based similarity (0-1)
 */
function levenshteinSimilarity(a: string, b: string): number {
  if (a === b) return 1;
  if (a.length === 0 || b.length === 0) return 0;
  
  const matrix: number[][] = [];
  
  for (let i = 0; i <= a.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= b.length; j++) {
    matrix[0][j] = j;
  }
  
  for (let i = 1; i <= a.length; i++) {
    for (let j = 1; j <= b.length; j++) {
      const cost = a[i - 1] === b[j - 1] ? 0 : 1;
      matrix[i][j] = Math.min(
        matrix[i - 1][j] + 1,
        matrix[i][j - 1] + 1,
        matrix[i - 1][j - 1] + cost
      );
    }
  }
  
  const distance = matrix[a.length][b.length];
  const maxLength = Math.max(a.length, b.length);
  return 1 - distance / maxLength;
}

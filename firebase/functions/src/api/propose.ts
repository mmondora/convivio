/**
 * Propose Dinner Menu
 *
 * Genera una proposta completa per una cena:
 * 1. Carica contesto cena (ospiti, parametri, stagione)
 * 2. Carica preferenze alimentari ospiti
 * 3. Carica inventario vini disponibili
 * 4. LLM genera menu + abbinamenti vino per ogni portata
 * 5. Salva proposta e ritorna
 *
 * REQUISITI:
 * - Ogni piatto ha un vino abbinato
 * - Minimizza cambi vino (2-3 vini max per cena)
 * - Per ogni piatto: cellarWine (dalla cantina) + marketWine (da acquistare)
 * - Note utente hanno PRIORITÀ MASSIMA
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import Anthropic from '@anthropic-ai/sdk';
import { logger } from 'firebase-functions';
import { z } from 'zod';
import type {
  ProposeDinnerRequest,
  ProposeDinnerResponse,
  DinnerEvent,
  Friend,
  FoodPreference,
  Wine,
  MenuProposal,
  WineProposal,
  CourseType,
  Rating,
  TasteProfile
} from '../types';

const db = getFirestore();

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

// ============================================================
// VALIDATION
// ============================================================

const RequestSchema = z.object({
  dinnerId: z.string().min(1),
  userId: z.string().min(1),
});

// ============================================================
// MAIN FUNCTION
// ============================================================

export const proposeDinnerMenu = onCall<ProposeDinnerRequest>(
  {
    region: 'europe-west1',
    memory: '1GiB',
    timeoutSeconds: 120,
    secrets: ['ANTHROPIC_API_KEY'],
  },
  async (request): Promise<ProposeDinnerResponse> => {
    const startTime = Date.now();

    // Validate request
    const validation = RequestSchema.safeParse(request.data);
    if (!validation.success) {
      throw new HttpsError('invalid-argument', 'Invalid request: ' + validation.error.message);
    }

    const { dinnerId, userId } = validation.data;

    // Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Cannot propose for another user');
    }

    logger.info('Starting dinner proposal', { userId, dinnerId });

    try {
      // Step 1: Load dinner details
      const dinner = await loadDinner(userId, dinnerId);
      if (!dinner) {
        throw new HttpsError('not-found', 'Cena non trovata');
      }

      // Step 2: Load guests with preferences
      const guests = await loadGuestsWithPreferences(userId, dinnerId);
      logger.info('Loaded guests', { count: guests.length });

      // Step 3: Load wine inventory
      const inventory = await loadWineInventory(userId);
      logger.info('Loaded wine inventory', { count: inventory.length });

      // Step 4: Determine season
      const season = getSeason(dinner.date.toDate());

      // Step 5: Build context and call LLM
      const context = buildProposalContext(dinner, guests, inventory, season);
      const proposal = await generateProposal(context);

      // Step 6: Save proposal to dinner
      await saveDinnerProposal(userId, dinnerId, proposal.menu, proposal.wines);

      const totalTime = Date.now() - startTime;
      logger.info('Dinner proposal completed', {
        dinnerId,
        coursesGenerated: proposal.menu.courses.length,
        winesProposed: proposal.wines.available.length + proposal.wines.suggested.length,
        totalTimeMs: totalTime
      });

      return {
        success: true,
        menu: proposal.menu,
        wineProposals: proposal.wines,
      };

    } catch (error) {
      logger.error('Proposal generation failed', { userId, dinnerId, error });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Generazione proposta fallita: ' + (error as Error).message);
    }
  }
);

// ============================================================
// DATA LOADING
// ============================================================

async function loadDinner(userId: string, dinnerId: string): Promise<DinnerEvent | null> {
  // Dinners are in top-level collection
  const doc = await db.collection('dinners').doc(dinnerId).get();
  if (!doc.exists) return null;

  const data = doc.data();
  // Verify ownership
  if (data?.hostId !== userId) return null;

  return { id: doc.id, ...data } as DinnerEvent;
}

interface GuestWithPrefs {
  friend: Friend;
  preferences: FoodPreference[];
}

async function loadGuestsWithPreferences(userId: string, dinnerId: string): Promise<GuestWithPrefs[]> {
  const guestsSnapshot = await db.collection('users').doc(userId)
    .collection('dinners').doc(dinnerId)
    .collection('guests').get();

  const guestFriendIds = guestsSnapshot.docs.map(doc => doc.data().friendId);

  if (guestFriendIds.length === 0) {
    return [];
  }

  const guests: GuestWithPrefs[] = [];

  for (const friendId of guestFriendIds) {
    const friendDoc = await db.collection('users').doc(userId)
      .collection('friends').doc(friendId).get();

    if (!friendDoc.exists) continue;

    const friend = { id: friendDoc.id, ...friendDoc.data() } as Friend;

    const prefsSnapshot = await db.collection('users').doc(userId)
      .collection('friends').doc(friendId)
      .collection('foodPreferences').get();

    const preferences = prefsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    })) as FoodPreference[];

    guests.push({ friend, preferences });
  }

  return guests;
}

interface WineWithRating extends Wine {
  rating?: number;
  tasteProfile?: TasteProfile;
  availableBottles: number;
  locationDescription: string;
}

async function loadWineInventory(userId: string): Promise<WineWithRating[]> {
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();

  if (cellarsSnapshot.empty) {
    return [];
  }

  const inventory: WineWithRating[] = [];
  const wineBottleCounts = new Map<string, { count: number; location: string }>();

  for (const cellarDoc of cellarsSnapshot.docs) {
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles')
      .where('status', '==', 'available')
      .get();

    for (const bottleDoc of bottlesSnapshot.docs) {
      const bottle = bottleDoc.data();
      const wineId = bottle.wineId;

      const current = wineBottleCounts.get(wineId) || { count: 0, location: cellarDoc.data().name };
      current.count++;
      wineBottleCounts.set(wineId, current);
    }
  }

  for (const [wineId, { count, location }] of wineBottleCounts) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (!wineDoc.exists) continue;

    const wine = { id: wineDoc.id, ...wineDoc.data() } as Wine;

    const ratingSnapshot = await db.collection('users').doc(userId)
      .collection('ratings')
      .where('wineId', '==', wineId)
      .limit(1)
      .get();

    const rating = ratingSnapshot.empty ? undefined : (ratingSnapshot.docs[0].data() as Rating).rating;

    const profileSnapshot = await db.collection('users').doc(userId)
      .collection('tasteProfiles')
      .where('wineId', '==', wineId)
      .limit(1)
      .get();

    const tasteProfile = profileSnapshot.empty ? undefined :
      { id: profileSnapshot.docs[0].id, ...profileSnapshot.docs[0].data() } as TasteProfile;

    inventory.push({
      ...wine,
      rating,
      tasteProfile,
      availableBottles: count,
      locationDescription: location,
    });
  }

  return inventory;
}

// ============================================================
// CONTEXT BUILDING
// ============================================================

interface ProposalContext {
  dinner: DinnerEvent;
  guests: GuestWithPrefs[];
  inventory: WineWithRating[];
  season: string;
  dietarySummary: string[];
  inventorySummary: string;
}

function buildProposalContext(
  dinner: DinnerEvent,
  guests: GuestWithPrefs[],
  inventory: WineWithRating[],
  season: string
): ProposalContext {
  const dietarySummary: string[] = [];

  for (const { friend, preferences } of guests) {
    const restrictions = preferences
      .filter(p => p.type === 'allergy' || p.type === 'intolerance' || p.type === 'diet')
      .map(p => p.category);

    const dislikes = preferences
      .filter(p => p.type === 'dislike')
      .map(p => p.category);

    if (restrictions.length > 0 || dislikes.length > 0) {
      let summary = friend.name;
      if (restrictions.length > 0) {
        summary += ` (EVITARE: ${restrictions.join(', ')})`;
      }
      if (dislikes.length > 0) {
        summary += ` (non gradisce: ${dislikes.join(', ')})`;
      }
      summary += ` - Foodie: ${friend.foodieLevel}`;
      dietarySummary.push(summary);
    } else {
      dietarySummary.push(`${friend.name} - Nessuna restrizione - Foodie: ${friend.foodieLevel}`);
    }
  }

  const inventorySummary = inventory
    .sort((a, b) => (b.rating || 0) - (a.rating || 0))
    .slice(0, 20)
    .map(w => {
      let desc = `${w.name}`;
      if (w.producer) desc += ` (${w.producer})`;
      if (w.vintage) desc += ` ${w.vintage}`;
      desc += ` - ${w.type}`;
      if (w.region) desc += `, ${w.region}`;
      desc += ` - ${w.availableBottles} bottiglia/e`;
      if (w.rating) desc += ` - Rating: ${w.rating}/5`;
      return desc;
    })
    .join('\n');

  return {
    dinner,
    guests,
    inventory,
    season,
    dietarySummary,
    inventorySummary,
  };
}

function getSeason(date: Date): string {
  const month = date.getMonth() + 1;
  if (month >= 3 && month <= 5) return 'primavera';
  if (month >= 6 && month <= 8) return 'estate';
  if (month >= 9 && month <= 11) return 'autunno';
  return 'inverno';
}

// ============================================================
// LLM GENERATION
// ============================================================

const PROPOSAL_PROMPT = `Sei un esperto chef e sommelier italiano. Devi proporre un menu completo con abbinamenti vino per una cena.

CONTESTO CENA:
- Nome: {dinner_name}
- Data: {dinner_date}
- Stagione: {season}
- Stile: {dinner_style}
- Tempo di preparazione disponibile: {cooking_time}
- Budget vini: {budget_level}
{user_notes}

OSPITI ({guest_count} persone):
{dietary_summary}

VINI DISPONIBILI IN CANTINA:
{inventory_summary}

ISTRUZIONI PRIORITARIE:
⚠️ MASSIMA PRIORITÀ: Le "RICHIESTE SPECIFICHE DELL'UTENTE" DEVONO essere seguite ESATTAMENTE.
   - Se l'utente specifica il numero di piatti per portata (es. "10 antipasti, 1 primo"), genera ESATTAMENTE quel numero
   - Se l'utente specifica il tipo di cucina, tema, o ingredienti, seguili alla lettera
   - NON ignorare MAI le richieste dell'utente

ISTRUZIONI GENERALI (se non specificate dall'utente):
1. Se non ci sono richieste specifiche, proponi: 1 antipasto, 1 primo, 1 secondo, 1 dolce
2. Considera TUTTE le restrizioni alimentari - nessun piatto deve contenere ingredienti vietati
3. Adatta la complessità al tempo di preparazione disponibile
4. Per ogni piatto indica:
   - Nome e breve descrizione
   - Flag dietetici (GF=senza glutine, LF=senza lattosio, V=vegetariano, VG=vegano)
   - Tempo di preparazione stimato
5. ABBINAMENTI VINO:
   - Ogni piatto DEVE avere un vino abbinato
   - MINIMIZZA il numero di vini diversi (es. stesso vino per tutti gli antipasti)
   - Per ogni piatto proponi:
     a) "cellarWine": un vino dalla lista "DISPONIBILI IN CANTINA" (se disponibile)
     b) "marketWine": un vino da acquistare come alternativa
   - Se lo stesso vino va bene per più portate, usa lo stesso nome esatto
6. Lo stile del menu deve rispecchiare il tipo di cena (informale/conviviale/elegante)

TIPI DI PORTATA:
- "starter" = antipasto
- "first" = primo (pasta, risotto, zuppe)
- "main" = secondo (carne, pesce)
- "side" = contorno
- "dessert" = dolce

FORMATO OUTPUT (JSON):
{
  "menu": {
    "courses": [
      {
        "course": "starter|first|main|side|dessert",
        "name": "Nome piatto",
        "description": "Descrizione",
        "dietaryFlags": ["GF", "LF", "V"],
        "prepTime": 30,
        "cellarWine": {
          "name": "Nome esatto del vino dalla cantina",
          "reasoning": "Perché questo abbinamento"
        },
        "marketWine": {
          "name": "Nome vino da acquistare",
          "details": "Tipo, regione, produttore consigliato",
          "reasoning": "Perché questo abbinamento"
        }
      }
    ],
    "reasoning": "Spiegazione generale delle scelte di menu e vini",
    "wineStrategy": "Strategia abbinamenti (es. 'Due vini: un bianco per antipasto e primo, un rosso per il secondo')",
    "seasonContext": "Come la stagione ha influenzato le scelte",
    "guestConsiderations": ["Considerazione 1", "Considerazione 2"],
    "totalPrepTime": 120
  }
}

IMPORTANTE: Se l'utente chiede N piatti di un tipo, l'array "courses" DEVE contenere esattamente N elementi con quel course type.

Rispondi SOLO con il JSON, senza altro testo.`;

interface GeneratedProposal {
  menu: MenuProposal;
  wines: {
    available: WineProposal[];
    suggested: WineProposal[];
  };
}

async function generateProposal(context: ProposalContext): Promise<GeneratedProposal> {
  const userNotesSection = context.dinner.notes
    ? `\nRICHIESTE SPECIFICHE DELL'UTENTE:\n${context.dinner.notes}`
    : '';

  // Handle iOS model which uses 'title' instead of 'name' and may not have style/cookingTime/budgetLevel
  const dinnerName = (context.dinner as any).title || context.dinner.name || 'Cena';
  const dinnerStyle = context.dinner.style || 'conviviale';
  const cookingTime = context.dinner.cookingTime || 'twoHours';
  const budgetLevel = context.dinner.budgetLevel || 'standard';
  const guestCount = (context.dinner as any).guestCount || context.guests.length || 4;

  const prompt = PROPOSAL_PROMPT
    .replace('{dinner_name}', dinnerName)
    .replace('{dinner_date}', context.dinner.date.toDate().toLocaleDateString('it-IT'))
    .replace('{season}', context.season)
    .replace('{dinner_style}', dinnerStyle)
    .replace('{cooking_time}', cookingTime)
    .replace('{budget_level}', budgetLevel)
    .replace('{user_notes}', userNotesSection)
    .replace('{guest_count}', guestCount.toString())
    .replace('{dietary_summary}', context.dietarySummary.length > 0 ? context.dietarySummary.join('\n') : 'Nessun ospite registrato')
    .replace('{inventory_summary}', context.inventorySummary || 'Nessun vino in cantina');

  // Log AI input
  logger.info('=== AI REQUEST (proposeDinnerMenu) ===');
  logger.info('USER NOTES: ' + (context.dinner.notes || 'NESSUNA'));
  logger.info('FULL PROMPT:', { prompt });

  const response = await anthropic.messages.create({
    model: 'claude-sonnet-4-20250514',
    max_tokens: 4096,
    messages: [
      { role: 'user', content: prompt }
    ],
  });

  const responseText = response.content
    .filter(block => block.type === 'text')
    .map(block => (block as { type: 'text'; text: string }).text)
    .join('');

  // Log AI output
  logger.info('=== AI RESPONSE (proposeDinnerMenu) ===');
  logger.info('RESPONSE:', { responseText });

  // Parse JSON
  const jsonText = responseText
    .replace(/```json\n?/g, '')
    .replace(/```\n?/g, '')
    .trim();

  const parsed = JSON.parse(jsonText);

  // Transform to our types
  const menu: MenuProposal = {
    courses: parsed.menu.courses.map((c: any) => ({
      course: c.course as CourseType,
      name: c.name,
      description: c.description,
      dietaryFlags: c.dietaryFlags || [],
      prepTime: c.prepTime,
      notes: c.notes,
      cellarWine: c.cellarWine ? {
        name: c.cellarWine.name,
        reasoning: c.cellarWine.reasoning,
      } : undefined,
      marketWine: c.marketWine ? {
        name: c.marketWine.name,
        reasoning: c.marketWine.reasoning,
        details: c.marketWine.details,
      } : undefined,
    })),
    reasoning: parsed.menu.reasoning,
    wineStrategy: parsed.menu.wineStrategy,
    seasonContext: parsed.menu.seasonContext,
    guestConsiderations: parsed.menu.guestConsiderations || [],
    totalPrepTime: parsed.menu.totalPrepTime,
    generatedAt: Timestamp.now(),
  };

  // Extract wine proposals
  const availableWines: WineProposal[] = [];
  const suggestedWines: WineProposal[] = [];

  for (const c of parsed.menu.courses) {
    if (c.cellarWine) {
      const matchedWine = context.inventory.find(inv =>
        inv.name.toLowerCase().includes(c.cellarWine.name.toLowerCase()) ||
        c.cellarWine.name.toLowerCase().includes(inv.name.toLowerCase())
      );

      availableWines.push({
        id: '',
        dinnerId: context.dinner.id,
        type: 'available',
        wineId: matchedWine?.id,
        course: c.course as CourseType,
        reasoning: c.cellarWine.reasoning,
        isSelected: false,
        createdAt: Timestamp.now(),
      });
    }

    if (c.marketWine) {
      suggestedWines.push({
        id: '',
        dinnerId: context.dinner.id,
        type: 'suggested_purchase',
        suggestedWineName: c.marketWine.name,
        suggestedWineDetails: c.marketWine.details,
        course: c.course as CourseType,
        reasoning: c.marketWine.reasoning,
        isSelected: false,
        createdAt: Timestamp.now(),
      });
    }
  }

  return {
    menu,
    wines: {
      available: availableWines,
      suggested: suggestedWines,
    },
  };
}

// ============================================================
// PERSISTENCE
// ============================================================

async function saveDinnerProposal(
  userId: string,
  dinnerId: string,
  menu: MenuProposal,
  wines: { available: WineProposal[]; suggested: WineProposal[] }
): Promise<void> {
  // Dinners are in top-level collection
  const dinnerRef = db.collection('dinners').doc(dinnerId);

  // Update dinner with menu proposal (iOS uses 'menu' field)
  await dinnerRef.update({
    menu: menu,
    updatedAt: Timestamp.now(),
  });

  logger.info('Saved menu proposal to dinner', { dinnerId });
}

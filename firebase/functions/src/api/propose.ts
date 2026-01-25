/**
 * Propose Dinner Menu
 * 
 * Genera una proposta completa per una cena:
 * 1. Carica contesto cena (ospiti, parametri, stagione)
 * 2. Carica preferenze alimentari ospiti
 * 3. Carica inventario vini disponibili con rating
 * 4. LLM genera menu + abbinamenti
 * 5. Salva proposta e ritorna
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
  const doc = await db.collection('users').doc(userId).collection('dinners').doc(dinnerId).get();
  if (!doc.exists) return null;
  return { id: doc.id, ...doc.data() } as DinnerEvent;
}

interface GuestWithPrefs {
  friend: Friend;
  preferences: FoodPreference[];
}

async function loadGuestsWithPreferences(userId: string, dinnerId: string): Promise<GuestWithPrefs[]> {
  // Load dinner guests
  const guestsSnapshot = await db.collection('users').doc(userId)
    .collection('dinners').doc(dinnerId)
    .collection('guests').get();
  
  const guestFriendIds = guestsSnapshot.docs.map(doc => doc.data().friendId);
  
  if (guestFriendIds.length === 0) {
    return [];
  }
  
  // Load friends and their preferences
  const guests: GuestWithPrefs[] = [];
  
  for (const friendId of guestFriendIds) {
    const friendDoc = await db.collection('users').doc(userId)
      .collection('friends').doc(friendId).get();
    
    if (!friendDoc.exists) continue;
    
    const friend = { id: friendDoc.id, ...friendDoc.data() } as Friend;
    
    // Load preferences
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
  // Get user's cellars
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();
  
  if (cellarsSnapshot.empty) {
    return [];
  }
  
  const inventory: WineWithRating[] = [];
  const wineBottleCounts = new Map<string, { count: number; location: string }>();
  
  // For each cellar, get available bottles
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
  
  // Load wine details and ratings
  for (const [wineId, { count, location }] of wineBottleCounts) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (!wineDoc.exists) continue;
    
    const wine = { id: wineDoc.id, ...wineDoc.data() } as Wine;
    
    // Load user's rating for this wine
    const ratingSnapshot = await db.collection('users').doc(userId)
      .collection('ratings')
      .where('wineId', '==', wineId)
      .limit(1)
      .get();
    
    const rating = ratingSnapshot.empty ? undefined : (ratingSnapshot.docs[0].data() as Rating).rating;
    
    // Load taste profile
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
  // Build dietary summary
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
  
  // Build inventory summary
  const inventorySummary = inventory
    .sort((a, b) => (b.rating || 0) - (a.rating || 0))
    .slice(0, 20) // Top 20 wines
    .map(w => {
      let desc = `${w.name}`;
      if (w.producer) desc += ` (${w.producer})`;
      if (w.vintage) desc += ` ${w.vintage}`;
      desc += ` - ${w.type}`;
      if (w.region) desc += `, ${w.region}`;
      desc += ` - ${w.availableBottles} bottiglia/e`;
      if (w.rating) desc += ` - Rating: ${w.rating}/5`;
      desc += ` - Posizione: ${w.locationDescription}`;
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
  const month = date.getMonth() + 1; // 1-12
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

OSPITI ({guest_count} persone):
{dietary_summary}

VINI DISPONIBILI IN CANTINA:
{inventory_summary}

ISTRUZIONI:
1. Proponi un menu completo con: antipasto, primo, secondo, dolce
2. Considera TUTTE le restrizioni alimentari - nessun piatto deve contenere ingredienti vietati
3. Adatta la complessità al tempo di preparazione disponibile
4. Per ogni piatto indica:
   - Nome e breve descrizione
   - Flag dietetici (GF=senza glutine, LF=senza lattosio, V=vegetariano, VG=vegano)
   - Tempo di preparazione stimato
5. Per i vini:
   - Proponi SOLO vini dalla lista "DISPONIBILI IN CANTINA" come abbinamenti principali
   - Puoi suggerire 1-2 vini da acquistare come alternativa/complemento
   - Spiega brevemente perché ogni vino è adatto
6. Lo stile del menu deve rispecchiare il tipo di cena (informale/conviviale/elegante)

FORMATO OUTPUT (JSON):
{
  "menu": {
    "courses": [
      {
        "course": "starter|first|main|dessert",
        "name": "Nome piatto",
        "description": "Descrizione",
        "dietaryFlags": ["GF", "LF", "V"],
        "prepTime": 30,
        "notes": "Note opzionali"
      }
    ],
    "reasoning": "Spiegazione generale delle scelte",
    "seasonContext": "Come la stagione ha influenzato le scelte",
    "guestConsiderations": ["Considerazione 1", "Considerazione 2"],
    "totalPrepTime": 120
  },
  "wines": {
    "available": [
      {
        "wineName": "Nome del vino dalla lista",
        "course": "starter|first|main|dessert|pairing",
        "reasoning": "Perché questo vino"
      }
    ],
    "suggested": [
      {
        "wineName": "Nome vino da acquistare",
        "wineDetails": "Tipo, regione, caratteristiche",
        "course": "dessert",
        "reasoning": "Perché consigliato"
      }
    ]
  }
}

Rispondi SOLO con il JSON, senza altro testo.`;

interface GeneratedProposal {
  menu: MenuProposal;
  wines: {
    available: WineProposal[];
    suggested: WineProposal[];
  };
}

async function generateProposal(context: ProposalContext): Promise<GeneratedProposal> {
  const prompt = PROPOSAL_PROMPT
    .replace('{dinner_name}', context.dinner.name)
    .replace('{dinner_date}', context.dinner.date.toDate().toLocaleDateString('it-IT'))
    .replace('{season}', context.season)
    .replace('{dinner_style}', context.dinner.style)
    .replace('{cooking_time}', context.dinner.cookingTime)
    .replace('{budget_level}', context.dinner.budgetLevel)
    .replace('{guest_count}', context.guests.length.toString())
    .replace('{dietary_summary}', context.dietarySummary.join('\n'))
    .replace('{inventory_summary}', context.inventorySummary || 'Nessun vino in cantina');
  
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
    })),
    reasoning: parsed.menu.reasoning,
    seasonContext: parsed.menu.seasonContext,
    guestConsiderations: parsed.menu.guestConsiderations || [],
    totalPrepTime: parsed.menu.totalPrepTime,
    generatedAt: Timestamp.now(),
  };
  
  // Match available wines to inventory
  const availableWines: WineProposal[] = [];
  for (const w of parsed.wines.available || []) {
    // Find wine in inventory by name (fuzzy)
    const matchedWine = context.inventory.find(inv => 
      inv.name.toLowerCase().includes(w.wineName.toLowerCase()) ||
      w.wineName.toLowerCase().includes(inv.name.toLowerCase())
    );
    
    availableWines.push({
      id: '', // Will be set when saving
      dinnerId: context.dinner.id,
      type: 'available',
      wineId: matchedWine?.id,
      course: w.course as CourseType,
      reasoning: w.reasoning,
      isSelected: false,
      createdAt: Timestamp.now(),
    });
  }
  
  const suggestedWines: WineProposal[] = (parsed.wines.suggested || []).map((w: any) => ({
    id: '',
    dinnerId: context.dinner.id,
    type: 'suggested_purchase' as const,
    suggestedWineName: w.wineName,
    suggestedWineDetails: w.wineDetails,
    course: w.course as CourseType,
    reasoning: w.reasoning,
    isSelected: false,
    createdAt: Timestamp.now(),
  }));
  
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
  const dinnerRef = db.collection('users').doc(userId).collection('dinners').doc(dinnerId);
  const proposalsRef = dinnerRef.collection('proposals');
  
  // Update dinner with menu proposal
  await dinnerRef.update({
    menuProposal: menu,
    updatedAt: Timestamp.now(),
  });
  
  // Clear existing proposals
  const existingProposals = await proposalsRef.get();
  const batch = db.batch();
  existingProposals.docs.forEach(doc => batch.delete(doc.ref));
  
  // Add new wine proposals
  for (const proposal of [...wines.available, ...wines.suggested]) {
    const ref = proposalsRef.doc();
    batch.set(ref, { ...proposal, id: ref.id });
  }
  
  await batch.commit();
}

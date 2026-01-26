/**
 * Chat with Sommelier
 * 
 * Chat conversazionale con AI sommelier che può:
 * - Rispondere a domande sui vini
 * - Cercare vini in cantina (tool calling)
 * - Suggerire abbinamenti
 * - Trovare posizione bottiglie
 * - Consigliare basandosi su rating personali
 */

import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';
import Anthropic from '@anthropic-ai/sdk';
import { logger } from 'firebase-functions';
import { z } from 'zod';
import type {
  ChatRequest,
  ChatResponse,
  Wine,
  Rating,
  Friend,
  FoodPreference,
  Conversation,
  ChatMessage
} from '../types';

const db = getFirestore();

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

// ============================================================
// VALIDATION
// ============================================================

const RequestSchema = z.object({
  message: z.string().min(1).max(2000),
  conversationId: z.string().optional(),
  userId: z.string().min(1),
  context: z.object({
    cellarId: z.string().optional(),
    dinnerId: z.string().optional(),
  }).optional(),
});

// ============================================================
// TOOL DEFINITIONS
// ============================================================

const TOOLS: Anthropic.Tool[] = [
  {
    name: 'search_wines',
    description: 'Cerca vini nella cantina dell\'utente. Usa questo tool per trovare vini disponibili basandosi su tipo, regione, rating minimo, o query testuale.',
    input_schema: {
      type: 'object' as const,
      properties: {
        type: {
          type: 'string',
          enum: ['red', 'white', 'rosé', 'sparkling', 'dessert', 'fortified'],
          description: 'Tipo di vino da cercare',
        },
        region: {
          type: 'string',
          description: 'Regione o denominazione (es. "Piemonte", "Toscana", "Bordeaux")',
        },
        minRating: {
          type: 'number',
          description: 'Rating minimo (1-5)',
        },
        query: {
          type: 'string',
          description: 'Testo libero per cercare nel nome o produttore',
        },
        limit: {
          type: 'number',
          description: 'Numero massimo di risultati (default 5)',
        },
      },
      required: [],
    },
  },
  {
    name: 'get_wine_details',
    description: 'Ottieni dettagli completi di un vino specifico, inclusi rating personali e profilo sensoriale.',
    input_schema: {
      type: 'object' as const,
      properties: {
        wineId: {
          type: 'string',
          description: 'ID del vino',
        },
        wineName: {
          type: 'string',
          description: 'Nome del vino (alternativa a wineId)',
        },
      },
      required: [],
    },
  },
  {
    name: 'get_bottle_location',
    description: 'Trova la posizione fisica di una bottiglia specifica nella cantina.',
    input_schema: {
      type: 'object' as const,
      properties: {
        wineId: {
          type: 'string',
          description: 'ID del vino',
        },
        wineName: {
          type: 'string',
          description: 'Nome del vino (alternativa a wineId)',
        },
      },
      required: [],
    },
  },
  {
    name: 'get_cellar_stats',
    description: 'Ottieni statistiche generali sulla cantina: totale bottiglie, distribuzione per tipo, etc.',
    input_schema: {
      type: 'object' as const,
      properties: {},
      required: [],
    },
  },
  {
    name: 'get_friend_preferences',
    description: 'Ottieni le preferenze alimentari di un amico per considerarle negli abbinamenti.',
    input_schema: {
      type: 'object' as const,
      properties: {
        friendName: {
          type: 'string',
          description: 'Nome dell\'amico',
        },
      },
      required: ['friendName'],
    },
  },
];

// ============================================================
// SYSTEM PROMPT
// ============================================================

const SYSTEM_PROMPT = `Sei un sommelier esperto e amichevole che aiuta l'utente a gestire la sua cantina personale e scegliere i vini giusti.

PERSONALITÀ:
- Sei competente ma accessibile, mai snob
- Dai consigli pratici e concreti
- Usi un tono informale ma professionale
- Sei entusiasta del vino ma rispetti i gusti dell'utente

CAPACITÀ:
- Puoi cercare vini nella cantina dell'utente usando il tool "search_wines"
- Puoi trovare dove sono le bottiglie con "get_bottle_location"
- Puoi vedere i dettagli e rating personali con "get_wine_details"
- Puoi consultare statistiche cantina con "get_cellar_stats"
- Puoi considerare le preferenze degli amici con "get_friend_preferences"

REGOLE IMPORTANTI:
1. MAI inventare vini che non esistono nella cantina dell'utente
2. Se non trovi un vino, dillo chiaramente e suggerisci alternative
3. Quando suggerisci vini, cerca SEMPRE prima nella cantina
4. Per abbinamenti, considera sia il cibo che i gusti personali dell'utente (rating)
5. Se l'utente chiede qualcosa fuori dal tuo ambito (vino/cibo), rispondi cortesemente che sei specializzato in vini

FORMATO RISPOSTE:
- Sii conciso ma completo
- Quando elenchi vini, includi: nome, produttore (se noto), posizione in cantina
- Per abbinamenti, spiega brevemente il perché
- Se hai più opzioni, presentale in ordine di preferenza basandoti sui rating dell'utente`;

// ============================================================
// MAIN FUNCTION
// ============================================================

export const chatWithSommelier = onCall<ChatRequest>(
  {
    region: 'europe-west1',
    memory: '512MiB',
    timeoutSeconds: 60,
    secrets: ['ANTHROPIC_API_KEY'],
  },
  async (request): Promise<ChatResponse> => {
    const startTime = Date.now();
    
    // Validate request
    const validation = RequestSchema.safeParse(request.data);
    if (!validation.success) {
      throw new HttpsError('invalid-argument', 'Invalid request: ' + validation.error.message);
    }
    
    const { message, conversationId, userId, context: _context } = validation.data;
    
    // Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }
    
    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Cannot chat for another user');
    }
    
    logger.info('Processing chat message', { 
      userId, 
      conversationId, 
      messageLength: message.length 
    });
    
    try {
      // Get or create conversation
      const { conversation, messages } = await getOrCreateConversation(userId, conversationId);
      
      // Build messages array for Claude
      const claudeMessages: Anthropic.MessageParam[] = messages.map(m => ({
        role: m.role,
        content: m.content,
      }));
      
      // Add user's new message
      claudeMessages.push({ role: 'user', content: message });

      // Create tool executor bound to this user
      const toolExecutor = createToolExecutor(userId);

      // Log AI input
      logger.info('=== AI REQUEST (chatWithSommelier) ===');
      logger.info('SYSTEM PROMPT:', { systemPrompt: SYSTEM_PROMPT });
      logger.info('MESSAGES:', { messages: JSON.stringify(claudeMessages, null, 2) });
      logger.info('TOOLS:', { tools: TOOLS.map(t => t.name) });

      // Call Claude with tool use
      let response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        tools: TOOLS,
        messages: claudeMessages,
      });

      // Log initial AI response
      logger.info('=== AI INITIAL RESPONSE (chatWithSommelier) ===');
      logger.info('STOP REASON:', { stopReason: response.stop_reason });
      logger.info('CONTENT:', { content: JSON.stringify(response.content, null, 2) });
      
      // Handle tool use loop
      const toolCalls: any[] = [];
      const toolResults: any[] = [];
      
      while (response.stop_reason === 'tool_use') {
        const toolUseBlocks = response.content.filter(
          (block): block is Anthropic.ToolUseBlock => block.type === 'tool_use'
        );
        
        const toolResultContents: Anthropic.ToolResultBlockParam[] = [];
        
        for (const toolUse of toolUseBlocks) {
          logger.info('Executing tool', { tool: toolUse.name, input: toolUse.input });
          
          toolCalls.push({
            id: toolUse.id,
            name: toolUse.name,
            arguments: toolUse.input,
          });
          
          try {
            const result = await toolExecutor(toolUse.name, toolUse.input as Record<string, unknown>);
            
            toolResults.push({
              toolCallId: toolUse.id,
              result,
            });
            
            toolResultContents.push({
              type: 'tool_result',
              tool_use_id: toolUse.id,
              content: JSON.stringify(result),
            });
          } catch (error) {
            toolResultContents.push({
              type: 'tool_result',
              tool_use_id: toolUse.id,
              content: `Errore: ${(error as Error).message}`,
              is_error: true,
            });
          }
        }
        
        // Continue conversation with tool results
        claudeMessages.push({ role: 'assistant', content: response.content });
        claudeMessages.push({ role: 'user', content: toolResultContents });
        
        response = await anthropic.messages.create({
          model: 'claude-sonnet-4-20250514',
          max_tokens: 2048,
          system: SYSTEM_PROMPT,
          tools: TOOLS,
          messages: claudeMessages,
        });
      }
      
      // Extract final text response
      const responseText = response.content
        .filter((block): block is Anthropic.TextBlock => block.type === 'text')
        .map(block => block.text)
        .join('');

      // Log final AI response
      logger.info('=== AI FINAL RESPONSE (chatWithSommelier) ===');
      logger.info('RESPONSE TEXT:', { responseText });
      logger.info('TOOL CALLS:', { toolCalls: JSON.stringify(toolCalls, null, 2) });
      logger.info('TOOL RESULTS:', { toolResults: JSON.stringify(toolResults, null, 2) });
      
      // Save messages to conversation
      await saveMessages(userId, conversation.id, message, responseText, toolCalls, toolResults);
      
      // Extract wine references from tool results
      const wineIds = extractWineReferences(toolResults);
      const wineReferences = wineIds.length > 0 ? await loadWines(wineIds) : [];
      
      const totalTime = Date.now() - startTime;
      logger.info('Chat completed', { 
        conversationId: conversation.id,
        toolCallCount: toolCalls.length,
        responseLength: responseText.length,
        totalTimeMs: totalTime
      });
      
      return {
        success: true,
        response: responseText,
        conversationId: conversation.id,
        wineReferences,
      };
      
    } catch (error) {
      logger.error('Chat failed', { userId, error });
      if (error instanceof HttpsError) throw error;
      throw new HttpsError('internal', 'Chat fallita: ' + (error as Error).message);
    }
  }
);

// ============================================================
// CONVERSATION MANAGEMENT
// ============================================================

async function getOrCreateConversation(
  userId: string, 
  conversationId?: string
): Promise<{ conversation: Conversation; messages: ChatMessage[] }> {
  const conversationsRef = db.collection('users').doc(userId).collection('conversations');
  
  if (conversationId) {
    const doc = await conversationsRef.doc(conversationId).get();
    if (doc.exists) {
      const messagesSnapshot = await doc.ref.collection('messages')
        .orderBy('createdAt', 'asc')
        .limit(20) // Last 20 messages for context
        .get();
      
      const messages = messagesSnapshot.docs.map(d => ({
        id: d.id,
        ...d.data()
      })) as ChatMessage[];
      
      return {
        conversation: { id: doc.id, ...doc.data() } as Conversation,
        messages,
      };
    }
  }
  
  // Create new conversation
  const newConvRef = conversationsRef.doc();
  const newConv: Omit<Conversation, 'id'> = {
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  };
  await newConvRef.set(newConv);
  
  return {
    conversation: { id: newConvRef.id, ...newConv } as Conversation,
    messages: [],
  };
}

async function saveMessages(
  userId: string,
  conversationId: string,
  userMessage: string,
  assistantResponse: string,
  toolCalls: any[],
  toolResults: any[]
): Promise<void> {
  const messagesRef = db.collection('users').doc(userId)
    .collection('conversations').doc(conversationId)
    .collection('messages');
  
  const batch = db.batch();
  
  // Save user message
  const userMsgRef = messagesRef.doc();
  batch.set(userMsgRef, {
    role: 'user',
    content: userMessage,
    createdAt: Timestamp.now(),
  });
  
  // Save assistant message
  const assistantMsgRef = messagesRef.doc();
  batch.set(assistantMsgRef, {
    role: 'assistant',
    content: assistantResponse,
    toolCalls: toolCalls.length > 0 ? toolCalls : null,
    toolResults: toolResults.length > 0 ? toolResults : null,
    createdAt: Timestamp.now(),
  });
  
  // Update conversation timestamp
  batch.update(
    db.collection('users').doc(userId).collection('conversations').doc(conversationId),
    { updatedAt: Timestamp.now() }
  );
  
  await batch.commit();
}

// ============================================================
// TOOL EXECUTOR
// ============================================================

function createToolExecutor(userId: string) {
  return async (toolName: string, input: Record<string, unknown>): Promise<unknown> => {
    switch (toolName) {
      case 'search_wines':
        return searchWines(userId, input);
      case 'get_wine_details':
        return getWineDetails(userId, input);
      case 'get_bottle_location':
        return getBottleLocation(userId, input);
      case 'get_cellar_stats':
        return getCellarStats(userId);
      case 'get_friend_preferences':
        return getFriendPreferences(userId, input);
      default:
        throw new Error(`Unknown tool: ${toolName}`);
    }
  };
}

// ============================================================
// TOOL IMPLEMENTATIONS
// ============================================================

interface SearchResult {
  wines: Array<{
    id: string;
    name: string;
    producer?: string;
    vintage?: number;
    type: string;
    region?: string;
    rating?: number;
    availableBottles: number;
  }>;
  totalFound: number;
}

async function searchWines(
  userId: string, 
  input: Record<string, unknown>
): Promise<SearchResult> {
  const { type, region, minRating, query, limit = 5 } = input;
  
  // Get user's cellars
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();
  
  if (cellarsSnapshot.empty) {
    return { wines: [], totalFound: 0 };
  }
  
  // Collect all available wines
  const wineData = new Map<string, { wine: Wine; bottles: number; rating?: number }>();
  
  for (const cellarDoc of cellarsSnapshot.docs) {
    let bottlesQuery = cellarDoc.ref.collection('bottles')
      .where('status', '==', 'available');
    
    const bottlesSnapshot = await bottlesQuery.get();
    
    for (const bottleDoc of bottlesSnapshot.docs) {
      const bottle = bottleDoc.data();
      const wineId = bottle.wineId;
      
      if (!wineData.has(wineId)) {
        const wineDoc = await db.collection('wines').doc(wineId).get();
        if (wineDoc.exists) {
          const wine = { id: wineDoc.id, ...wineDoc.data() } as Wine;
          
          // Get user rating
          const ratingSnapshot = await db.collection('users').doc(userId)
            .collection('ratings')
            .where('wineId', '==', wineId)
            .limit(1)
            .get();
          
          const rating = ratingSnapshot.empty ? undefined : 
            (ratingSnapshot.docs[0].data() as Rating).rating;
          
          wineData.set(wineId, { wine, bottles: 1, rating });
        }
      } else {
        const existing = wineData.get(wineId)!;
        existing.bottles++;
      }
    }
  }
  
  // Filter results
  let results = Array.from(wineData.values());
  
  if (type) {
    results = results.filter(r => r.wine.type === type);
  }
  
  if (region) {
    const regionLower = (region as string).toLowerCase();
    results = results.filter(r => 
      r.wine.region?.toLowerCase().includes(regionLower) ||
      r.wine.country?.toLowerCase().includes(regionLower)
    );
  }
  
  if (minRating) {
    results = results.filter(r => r.rating && r.rating >= (minRating as number));
  }
  
  if (query) {
    const queryLower = (query as string).toLowerCase();
    results = results.filter(r =>
      r.wine.name.toLowerCase().includes(queryLower) ||
      r.wine.producer?.toLowerCase().includes(queryLower)
    );
  }
  
  // Sort by rating (desc) then name
  results.sort((a, b) => {
    if (a.rating && b.rating) return b.rating - a.rating;
    if (a.rating) return -1;
    if (b.rating) return 1;
    return a.wine.name.localeCompare(b.wine.name);
  });
  
  const totalFound = results.length;
  results = results.slice(0, limit as number);
  
  return {
    wines: results.map(r => ({
      id: r.wine.id,
      name: r.wine.name,
      producer: r.wine.producer,
      vintage: r.wine.vintage,
      type: r.wine.type,
      region: r.wine.region,
      rating: r.rating,
      availableBottles: r.bottles,
    })),
    totalFound,
  };
}

async function getWineDetails(
  userId: string,
  input: Record<string, unknown>
): Promise<unknown> {
  const { wineId, wineName } = input;
  
  let wine: Wine | null = null;
  
  if (wineId) {
    const doc = await db.collection('wines').doc(wineId as string).get();
    if (doc.exists) {
      wine = { id: doc.id, ...doc.data() } as Wine;
    }
  } else if (wineName) {
    // Search by name
    const snapshot = await db.collection('wines')
      .where('createdBy', '==', userId)
      .get();
    
    const nameLower = (wineName as string).toLowerCase();
    const match = snapshot.docs.find(d => 
      d.data().name.toLowerCase().includes(nameLower)
    );
    
    if (match) {
      wine = { id: match.id, ...match.data() } as Wine;
    }
  }
  
  if (!wine) {
    return { error: 'Vino non trovato' };
  }
  
  // Get rating and taste profile
  const [ratingSnapshot, profileSnapshot] = await Promise.all([
    db.collection('users').doc(userId).collection('ratings')
      .where('wineId', '==', wine.id).limit(1).get(),
    db.collection('users').doc(userId).collection('tasteProfiles')
      .where('wineId', '==', wine.id).limit(1).get(),
  ]);
  
  return {
    ...wine,
    rating: ratingSnapshot.empty ? null : ratingSnapshot.docs[0].data().rating,
    tasteProfile: profileSnapshot.empty ? null : profileSnapshot.docs[0].data(),
  };
}

async function getBottleLocation(
  userId: string,
  input: Record<string, unknown>
): Promise<unknown> {
  const { wineId, wineName } = input;
  
  // First find the wine if we have a name
  let targetWineId = wineId as string;
  
  if (!targetWineId && wineName) {
    const snapshot = await db.collection('wines')
      .where('createdBy', '==', userId)
      .get();
    
    const nameLower = (wineName as string).toLowerCase();
    const match = snapshot.docs.find(d => 
      d.data().name.toLowerCase().includes(nameLower)
    );
    
    if (match) {
      targetWineId = match.id;
    } else {
      return { error: `Vino "${wineName}" non trovato` };
    }
  }
  
  if (!targetWineId) {
    return { error: 'Specifica wineId o wineName' };
  }
  
  // Get user's cellars
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();
  
  const locations: Array<{
    cellarName: string;
    shelf: string;
    row?: number;
    slot?: number;
    bottleCount: number;
  }> = [];
  
  for (const cellarDoc of cellarsSnapshot.docs) {
    const cellarName = cellarDoc.data().name;
    
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles')
      .where('wineId', '==', targetWineId)
      .where('status', '==', 'available')
      .get();
    
    // Group by location
    const locationCounts = new Map<string, number>();
    const locationDetails = new Map<string, { shelf: string; row?: number; slot?: number }>();
    
    for (const bottleDoc of bottlesSnapshot.docs) {
      const locationId = bottleDoc.data().locationId;
      locationCounts.set(locationId, (locationCounts.get(locationId) || 0) + 1);
      
      if (!locationDetails.has(locationId)) {
        const locDoc = await cellarDoc.ref.collection('locations').doc(locationId).get();
        if (locDoc.exists) {
          const locData = locDoc.data()!;
          locationDetails.set(locationId, {
            shelf: locData.shelf,
            row: locData.row,
            slot: locData.slot,
          });
        }
      }
    }
    
    for (const [locationId, count] of locationCounts) {
      const details = locationDetails.get(locationId);
      if (details) {
        locations.push({
          cellarName,
          ...details,
          bottleCount: count,
        });
      }
    }
  }
  
  if (locations.length === 0) {
    return { error: 'Nessuna bottiglia disponibile di questo vino' };
  }
  
  // Get wine name for response
  const wineDoc = await db.collection('wines').doc(targetWineId).get();
  const wineNameResult = wineDoc.exists ? wineDoc.data()!.name : 'Sconosciuto';
  
  return {
    wineName: wineNameResult,
    totalBottles: locations.reduce((sum, l) => sum + l.bottleCount, 0),
    locations,
  };
}

async function getCellarStats(userId: string): Promise<unknown> {
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();
  
  const stats = {
    totalCellars: cellarsSnapshot.size,
    totalBottles: 0,
    byType: {} as Record<string, number>,
    byStatus: { available: 0, consumed: 0 },
    topRated: [] as Array<{ name: string; rating: number }>,
  };
  
  const wineRatings = new Map<string, { name: string; rating: number }>();
  
  for (const cellarDoc of cellarsSnapshot.docs) {
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles').get();
    
    for (const bottleDoc of bottlesSnapshot.docs) {
      const bottle = bottleDoc.data();
      stats.totalBottles++;
      
      if (bottle.status === 'available') {
        stats.byStatus.available++;
        
        // Get wine type
        const wineDoc = await db.collection('wines').doc(bottle.wineId).get();
        if (wineDoc.exists) {
          const wine = wineDoc.data()!;
          stats.byType[wine.type] = (stats.byType[wine.type] || 0) + 1;
          
          // Get rating
          if (!wineRatings.has(bottle.wineId)) {
            const ratingSnapshot = await db.collection('users').doc(userId)
              .collection('ratings')
              .where('wineId', '==', bottle.wineId)
              .limit(1)
              .get();
            
            if (!ratingSnapshot.empty) {
              wineRatings.set(bottle.wineId, {
                name: wine.name,
                rating: ratingSnapshot.docs[0].data().rating,
              });
            }
          }
        }
      } else {
        stats.byStatus.consumed++;
      }
    }
  }
  
  // Get top 5 rated wines
  stats.topRated = Array.from(wineRatings.values())
    .sort((a, b) => b.rating - a.rating)
    .slice(0, 5);
  
  return stats;
}

async function getFriendPreferences(
  userId: string,
  input: Record<string, unknown>
): Promise<unknown> {
  const { friendName } = input;
  
  if (!friendName) {
    return { error: 'Specifica il nome dell\'amico' };
  }
  
  const friendsSnapshot = await db.collection('users').doc(userId)
    .collection('friends')
    .get();
  
  const nameLower = (friendName as string).toLowerCase();
  const match = friendsSnapshot.docs.find(d =>
    d.data().name.toLowerCase().includes(nameLower)
  );
  
  if (!match) {
    return { error: `Amico "${friendName}" non trovato` };
  }
  
  const friend = match.data() as Friend;
  
  // Get preferences
  const prefsSnapshot = await db.collection('users').doc(userId)
    .collection('friends').doc(match.id)
    .collection('foodPreferences')
    .get();
  
  const preferences = prefsSnapshot.docs.map(d => d.data() as FoodPreference);
  
  return {
    name: friend.name,
    foodieLevel: friend.foodieLevel,
    allergies: preferences.filter(p => p.type === 'allergy').map(p => p.category),
    intolerances: preferences.filter(p => p.type === 'intolerance').map(p => p.category),
    dislikes: preferences.filter(p => p.type === 'dislike').map(p => p.category),
    diets: preferences.filter(p => p.type === 'diet').map(p => p.category),
    notes: friend.notes,
  };
}

// ============================================================
// HELPERS
// ============================================================

function extractWineReferences(toolResults: any[]): string[] {
  const wineIds: string[] = [];
  
  for (const result of toolResults) {
    if (result.result?.wines) {
      for (const wine of result.result.wines) {
        if (wine.id && !wineIds.includes(wine.id)) {
          wineIds.push(wine.id);
        }
      }
    }
    if (result.result?.id) {
      wineIds.push(result.result.id);
    }
  }
  
  return wineIds;
}

async function loadWines(wineIds: string[]): Promise<Wine[]> {
  const wines: Wine[] = [];
  
  for (const id of wineIds.slice(0, 10)) { // Max 10
    const doc = await db.collection('wines').doc(id).get();
    if (doc.exists) {
      wines.push({ id: doc.id, ...doc.data() } as Wine);
    }
  }
  
  return wines;
}

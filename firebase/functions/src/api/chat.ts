/**
 * Chat with Sommelier
 *
 * Conversational AI sommelier with tool calling capabilities:
 * - search_wines: Search wines in cellar
 * - get_wine_details: Get details of a specific wine
 * - get_bottle_location: Find where a bottle is stored
 * - get_cellar_stats: Get cellar statistics
 * - get_friend_preferences: Get dietary preferences of a friend
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
  Conversation,
  ChatMessage,
} from '../types';

const db = getFirestore();

const anthropic = new Anthropic({
  apiKey: process.env.ANTHROPIC_API_KEY,
});

// ============================================================
// VALIDATION
// ============================================================

const RequestSchema = z.object({
  message: z.string().min(1),
  conversationId: z.string().optional(),
  userId: z.string().min(1),
});

// ============================================================
// SYSTEM PROMPT
// ============================================================

const SYSTEM_PROMPT = `Sei un sommelier esperto e amichevole. Aiuti gli utenti a:
- Trovare vini nella loro cantina
- Scegliere il vino giusto per un'occasione
- Capire abbinamenti cibo-vino
- Gestire la loro collezione

Rispondi sempre in italiano in modo cordiale ma professionale.
Usa i tool disponibili per accedere ai dati della cantina dell'utente.
Quando suggerisci vini, spiega brevemente il perché della scelta.`;

// ============================================================
// TOOLS
// ============================================================

const TOOLS: Anthropic.Tool[] = [
  {
    name: 'search_wines',
    description: 'Cerca vini nella cantina dell\'utente per tipo, regione, o query testuale',
    input_schema: {
      type: 'object' as const,
      properties: {
        type: { type: 'string', description: 'Tipo di vino: red, white, rosé, sparkling, dessert, fortified' },
        region: { type: 'string', description: 'Regione di provenienza' },
        query: { type: 'string', description: 'Ricerca testuale per nome, produttore, ecc.' },
        limit: { type: 'number', description: 'Numero massimo di risultati (default 10)' },
      },
      required: [],
    },
  },
  {
    name: 'get_wine_details',
    description: 'Ottieni dettagli completi di un vino specifico incluse note di degustazione e rating',
    input_schema: {
      type: 'object' as const,
      properties: {
        wineId: { type: 'string', description: 'ID del vino' },
        wineName: { type: 'string', description: 'Nome del vino (alternativa a wineId)' },
      },
      required: [],
    },
  },
  {
    name: 'get_bottle_location',
    description: 'Trova dove è conservata una specifica bottiglia nella cantina',
    input_schema: {
      type: 'object' as const,
      properties: {
        wineId: { type: 'string', description: 'ID del vino da cercare' },
        wineName: { type: 'string', description: 'Nome del vino (alternativa)' },
      },
      required: [],
    },
  },
  {
    name: 'get_cellar_stats',
    description: 'Ottieni statistiche sulla cantina: totale bottiglie, distribuzione per tipo, vini più votati',
    input_schema: {
      type: 'object' as const,
      properties: {},
      required: [],
    },
  },
  {
    name: 'get_friend_preferences',
    description: 'Ottieni le preferenze alimentari e restrizioni di un amico',
    input_schema: {
      type: 'object' as const,
      properties: {
        friendName: { type: 'string', description: 'Nome dell\'amico' },
      },
      required: ['friendName'],
    },
  },
];

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

async function searchWines(userId: string, input: Record<string, unknown>) {
  const { type, region, query, limit = 10 } = input as {
    type?: string;
    region?: string;
    query?: string;
    limit?: number;
  };

  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();

  if (cellarsSnapshot.empty) {
    return { wines: [], message: 'Nessuna cantina trovata' };
  }

  const wineIds = new Set<string>();
  for (const cellarDoc of cellarsSnapshot.docs) {
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles')
      .where('status', '==', 'available')
      .get();
    bottlesSnapshot.docs.forEach(b => wineIds.add(b.data().wineId));
  }

  const wines: Wine[] = [];
  for (const wineId of wineIds) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (!wineDoc.exists) continue;

    const wine = { id: wineDoc.id, ...wineDoc.data() } as Wine;

    if (type && wine.type !== type) continue;
    if (region && !wine.region?.toLowerCase().includes(region.toLowerCase())) continue;
    if (query) {
      const searchText = `${wine.name} ${wine.producer || ''} ${wine.region || ''}`.toLowerCase();
      if (!searchText.includes(query.toLowerCase())) continue;
    }

    wines.push(wine);
    if (wines.length >= limit) break;
  }

  return {
    wines: wines.map(w => ({
      id: w.id,
      name: w.name,
      producer: w.producer,
      vintage: w.vintage,
      type: w.type,
      region: w.region,
    })),
    count: wines.length,
  };
}

async function getWineDetails(userId: string, input: Record<string, unknown>) {
  const { wineId, wineName } = input as { wineId?: string; wineName?: string };

  let wine: Wine | null = null;

  if (wineId) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (wineDoc.exists) {
      wine = { id: wineDoc.id, ...wineDoc.data() } as Wine;
    }
  } else if (wineName) {
    const winesSnapshot = await db.collection('wines')
      .where('name', '>=', wineName)
      .where('name', '<=', wineName + '\uf8ff')
      .limit(1)
      .get();
    if (!winesSnapshot.empty) {
      const doc = winesSnapshot.docs[0];
      wine = { id: doc.id, ...doc.data() } as Wine;
    }
  }

  if (!wine) {
    return { error: 'Vino non trovato' };
  }

  // Get user's rating
  const ratingSnapshot = await db.collection('users').doc(userId)
    .collection('ratings')
    .where('wineId', '==', wine.id)
    .limit(1)
    .get();

  const rating = ratingSnapshot.empty ? null : ratingSnapshot.docs[0].data();

  return {
    wine: {
      id: wine.id,
      name: wine.name,
      producer: wine.producer,
      vintage: wine.vintage,
      type: wine.type,
      region: wine.region,
      country: wine.country,
      grapes: wine.grapes,
      alcohol: wine.alcohol,
      description: wine.description,
    },
    rating: rating ? {
      score: rating.rating,
      isFavorite: rating.isFavorite,
      notes: rating.notes,
    } : null,
  };
}

async function getBottleLocation(userId: string, input: Record<string, unknown>) {
  const { wineId, wineName } = input as { wineId?: string; wineName?: string };

  let targetWineId = wineId;

  if (!targetWineId && wineName) {
    const winesSnapshot = await db.collection('wines')
      .where('name', '>=', wineName)
      .where('name', '<=', wineName + '\uf8ff')
      .limit(1)
      .get();
    if (!winesSnapshot.empty) {
      targetWineId = winesSnapshot.docs[0].id;
    }
  }

  if (!targetWineId) {
    return { error: 'Vino non trovato' };
  }

  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();

  const locations: Array<{ cellar: string; location: string; count: number }> = [];

  for (const cellarDoc of cellarsSnapshot.docs) {
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles')
      .where('wineId', '==', targetWineId)
      .where('status', '==', 'available')
      .get();

    if (!bottlesSnapshot.empty) {
      for (const bottleDoc of bottlesSnapshot.docs) {
        const bottle = bottleDoc.data();
        let locationStr = 'Posizione non specificata';

        if (bottle.locationId) {
          const locationDoc = await cellarDoc.ref.collection('locations').doc(bottle.locationId).get();
          if (locationDoc.exists) {
            const loc = locationDoc.data();
            locationStr = loc?.name || `Scaffale ${loc?.path?.shelf || '?'}, Riga ${loc?.path?.row || '?'}`;
          }
        }

        const existing = locations.find(l => l.cellar === cellarDoc.data().name && l.location === locationStr);
        if (existing) {
          existing.count++;
        } else {
          locations.push({
            cellar: cellarDoc.data().name,
            location: locationStr,
            count: 1,
          });
        }
      }
    }
  }

  if (locations.length === 0) {
    return { message: 'Nessuna bottiglia disponibile di questo vino' };
  }

  return { locations, totalBottles: locations.reduce((sum, l) => sum + l.count, 0) };
}

async function getCellarStats(userId: string) {
  const cellarsSnapshot = await db.collection('cellars')
    .where(`members.${userId}`, '!=', null)
    .get();

  let totalBottles = 0;
  const typeDistribution: Record<string, number> = {};
  const wineIds: string[] = [];

  for (const cellarDoc of cellarsSnapshot.docs) {
    const bottlesSnapshot = await cellarDoc.ref.collection('bottles')
      .where('status', '==', 'available')
      .get();

    totalBottles += bottlesSnapshot.size;

    for (const bottleDoc of bottlesSnapshot.docs) {
      wineIds.push(bottleDoc.data().wineId);
    }
  }

  // Get wine types
  for (const wineId of [...new Set(wineIds)]) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (wineDoc.exists) {
      const type = wineDoc.data()?.type || 'unknown';
      typeDistribution[type] = (typeDistribution[type] || 0) + wineIds.filter(id => id === wineId).length;
    }
  }

  // Get top rated wines
  const ratingsSnapshot = await db.collection('users').doc(userId)
    .collection('ratings')
    .orderBy('rating', 'desc')
    .limit(5)
    .get();

  const topRated: Array<{ name: string; rating: number }> = [];
  for (const ratingDoc of ratingsSnapshot.docs) {
    const wineDoc = await db.collection('wines').doc(ratingDoc.data().wineId).get();
    if (wineDoc.exists) {
      topRated.push({
        name: wineDoc.data()?.name || 'Unknown',
        rating: ratingDoc.data().rating,
      });
    }
  }

  return {
    totalBottles,
    typeDistribution,
    topRated,
    cellarCount: cellarsSnapshot.size,
  };
}

async function getFriendPreferences(userId: string, input: Record<string, unknown>) {
  const { friendName } = input as { friendName: string };

  const friendsSnapshot = await db.collection('users').doc(userId)
    .collection('friends')
    .where('name', '>=', friendName)
    .where('name', '<=', friendName + '\uf8ff')
    .limit(1)
    .get();

  if (friendsSnapshot.empty) {
    return { error: `Amico "${friendName}" non trovato` };
  }

  const friendDoc = friendsSnapshot.docs[0];
  const friend = friendDoc.data();

  const prefsSnapshot = await friendDoc.ref.collection('foodPreferences').get();
  const preferences = prefsSnapshot.docs.map(doc => doc.data());

  return {
    friend: {
      name: friend.name,
      foodieLevel: friend.foodieLevel,
      notes: friend.notes,
    },
    preferences: preferences.map(p => ({
      type: p.type,
      category: p.category,
      severity: p.severity,
      notes: p.notes,
    })),
  };
}

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
    // Validate request
    const validation = RequestSchema.safeParse(request.data);
    if (!validation.success) {
      throw new HttpsError('invalid-argument', 'Invalid request: ' + validation.error.message);
    }

    const { message, conversationId, userId } = validation.data;

    // Verify authentication
    if (!request.auth) {
      throw new HttpsError('unauthenticated', 'User must be authenticated');
    }

    if (request.auth.uid !== userId) {
      throw new HttpsError('permission-denied', 'Cannot chat as another user');
    }

    logger.info('Processing chat message', { userId, conversationId, messageLength: message.length });

    try {
      // Get or create conversation
      let conversation: Conversation;
      if (conversationId) {
        const convDoc = await db.collection('users').doc(userId)
          .collection('conversations').doc(conversationId).get();
        if (!convDoc.exists) {
          throw new HttpsError('not-found', 'Conversation not found');
        }
        conversation = { id: convDoc.id, ...convDoc.data() } as Conversation;
      } else {
        const convRef = await db.collection('users').doc(userId)
          .collection('conversations').add({
            userId,
            title: message.substring(0, 50),
            lastMessageAt: Timestamp.now(),
            createdAt: Timestamp.now(),
          });
        conversation = {
          id: convRef.id,
          userId,
          lastMessageAt: Timestamp.now(),
          createdAt: Timestamp.now(),
        };
      }

      // Load conversation history
      const messagesSnapshot = await db.collection('users').doc(userId)
        .collection('conversations').doc(conversation.id)
        .collection('messages')
        .orderBy('createdAt', 'asc')
        .limit(20)
        .get();

      const claudeMessages: Anthropic.MessageParam[] = messagesSnapshot.docs.map(doc => {
        const m = doc.data() as ChatMessage;
        return {
          role: m.role,
          content: m.content,
        };
      });

      claudeMessages.push({ role: 'user', content: message });

      const toolExecutor = createToolExecutor(userId);

      // Log AI input
      logger.info('=== AI REQUEST (chatWithSommelier) ===');
      logger.info('MESSAGE:', { message });
      logger.info('HISTORY LENGTH:', { count: claudeMessages.length - 1 });

      let response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2048,
        system: SYSTEM_PROMPT,
        tools: TOOLS,
        messages: claudeMessages,
      });

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

      // Log AI output
      logger.info('=== AI RESPONSE (chatWithSommelier) ===');
      logger.info('RESPONSE:', { responseText });
      logger.info('TOOL CALLS:', { count: toolCalls.length });

      // Save messages to conversation
      await saveMessages(userId, conversation.id, message, responseText, toolCalls, toolResults);

      // Extract wine references from tool results
      const wineIds = extractWineReferences(toolResults);
      const wineReferences = wineIds.length > 0 ? await loadWines(wineIds) : [];

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

async function saveMessages(
  userId: string,
  conversationId: string,
  userMessage: string,
  assistantMessage: string,
  toolCalls: any[],
  toolResults: any[]
): Promise<void> {
  const messagesRef = db.collection('users').doc(userId)
    .collection('conversations').doc(conversationId)
    .collection('messages');

  const batch = db.batch();

  // User message
  const userRef = messagesRef.doc();
  batch.set(userRef, {
    id: userRef.id,
    conversationId,
    role: 'user',
    content: userMessage,
    createdAt: Timestamp.now(),
  });

  // Assistant message
  const assistantRef = messagesRef.doc();
  batch.set(assistantRef, {
    id: assistantRef.id,
    conversationId,
    role: 'assistant',
    content: assistantMessage,
    toolCalls: toolCalls.length > 0 ? toolCalls : null,
    toolResults: toolResults.length > 0 ? toolResults : null,
    createdAt: Timestamp.now(),
  });

  // Update conversation
  batch.update(
    db.collection('users').doc(userId).collection('conversations').doc(conversationId),
    { lastMessageAt: Timestamp.now() }
  );

  await batch.commit();
}

function extractWineReferences(toolResults: any[]): string[] {
  const wineIds: string[] = [];

  for (const result of toolResults) {
    if (result.result?.wines) {
      for (const wine of result.result.wines) {
        if (wine.id) wineIds.push(wine.id);
      }
    }
    if (result.result?.wine?.id) {
      wineIds.push(result.result.wine.id);
    }
  }

  return [...new Set(wineIds)];
}

async function loadWines(wineIds: string[]): Promise<Wine[]> {
  const wines: Wine[] = [];

  for (const wineId of wineIds) {
    const wineDoc = await db.collection('wines').doc(wineId).get();
    if (wineDoc.exists) {
      wines.push({ id: wineDoc.id, ...wineDoc.data() } as Wine);
    }
  }

  return wines;
}

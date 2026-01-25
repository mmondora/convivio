/**
 * Sommelier Cloud Functions
 * 
 * Entry point per tutte le Cloud Functions dell'applicazione.
 * Architettura: Gen 2 functions con Firebase Admin SDK.
 */

import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

// Initialize Firebase Admin
initializeApp();

// Export Firestore instance for use in functions
export const db = getFirestore();

// ============================================================
// FUNCTION EXPORTS
// ============================================================

// Phase 1: Foundation
export { onUserCreate, onUserDelete } from './triggers/users';

// Phase 2: Intelligence
export { extractWineFromPhoto } from './api/extract';
export { proposeDinnerMenu } from './api/propose';
export { chatWithSommelier } from './api/chat';

// Utility exports
export { healthCheck } from './api/health';

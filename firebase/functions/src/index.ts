/**
 * Convivio Cloud Functions
 *
 * Entry point for all Cloud Functions.
 * Architecture: Gen 2 functions with Firebase Admin SDK.
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

// Triggers
export { onUserCreate, onUserDelete } from './triggers/users';

// API Endpoints
export { extractWineFromPhoto } from './api/extract';
export { proposeDinnerMenu } from './api/propose';
export { chatWithSommelier } from './api/chat';
export { healthCheck } from './api/health';

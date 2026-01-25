/**
 * User Triggers
 * 
 * Gestisce eventi di lifecycle degli utenti Firebase Auth.
 */

import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { getFirestore, FieldValue } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

/**
 * Trigger: quando un nuovo utente viene creato in Firestore.
 * - Crea una cantina di default "Casa"
 * - Inizializza le preferenze utente
 */
export const onUserCreate = onDocumentCreated(
  'users/{userId}',
  async (event) => {
    const userId = event.params.userId;
    const userData = event.data?.data();
    
    if (!userData) {
      logger.error('onUserCreate: No user data found', { userId });
      return;
    }
    
    logger.info('Creating default resources for new user', { 
      userId, 
      email: userData.email 
    });
    
    const batch = db.batch();
    
    // 1. Create default cellar "Casa"
    const cellarRef = db.collection('cellars').doc();
    batch.set(cellarRef, {
      name: 'Casa',
      description: 'La mia cantina principale',
      members: {
        [userId]: 'owner'
      },
      createdAt: FieldValue.serverTimestamp(),
      createdBy: userId
    });
    
    // 2. Create default location in cellar
    const locationRef = cellarRef.collection('locations').doc();
    batch.set(locationRef, {
      shelf: 'A',
      row: 1,
      slot: 1,
      description: 'Primo scaffale',
      capacity: 12
    });
    
    // 3. Initialize user preferences
    const prefsRef = db.collection('users').doc(userId).collection('preferences').doc('main');
    batch.set(prefsRef, {
      favoriteTypes: [],
      avoidTypes: [],
      favoriteRegions: [],
      notes: '',
      onboardingCompleted: false,
      createdAt: FieldValue.serverTimestamp()
    });
    
    try {
      await batch.commit();
      logger.info('Default resources created successfully', { userId, cellarId: cellarRef.id });
    } catch (error) {
      logger.error('Failed to create default resources', { userId, error });
      throw error;
    }
  }
);

/**
 * Trigger: quando un utente viene eliminato da Firestore.
 * - Rimuove tutti i dati associati (cascade delete)
 * - Rimuove l'utente dalle cantine condivise
 * 
 * NOTA: Questo è un soft-delete. Le cantine di cui l'utente era owner
 * vengono marcate come orfane, non eliminate.
 */
export const onUserDelete = onDocumentDeleted(
  'users/{userId}',
  async (event) => {
    const userId = event.params.userId;
    
    logger.info('Cleaning up data for deleted user', { userId });
    
    const batch = db.batch();
    
    // 1. Delete user's subcollections
    const subcollections = ['ratings', 'tasteProfiles', 'friends', 'dinners', 'photos', 'extractions', 'conversations', 'preferences'];
    
    for (const subcol of subcollections) {
      const snapshot = await db.collection('users').doc(userId).collection(subcol).get();
      snapshot.docs.forEach(doc => batch.delete(doc.ref));
    }
    
    // 2. Remove user from shared cellars (but don't delete cellars)
    const cellarsSnapshot = await db.collection('cellars')
      .where(`members.${userId}`, '!=', null)
      .get();
    
    for (const cellarDoc of cellarsSnapshot.docs) {
      const cellarData = cellarDoc.data();
      const memberRole = cellarData.members[userId];
      
      if (memberRole === 'owner') {
        // Mark cellar as orphaned (could transfer ownership or delete)
        batch.update(cellarDoc.ref, {
          [`members.${userId}`]: FieldValue.delete(),
          orphanedAt: FieldValue.serverTimestamp(),
          orphanedBy: userId
        });
        logger.warn('Cellar orphaned due to owner deletion', { 
          cellarId: cellarDoc.id, 
          userId 
        });
      } else {
        // Just remove from members
        batch.update(cellarDoc.ref, {
          [`members.${userId}`]: FieldValue.delete()
        });
      }
    }
    
    try {
      await batch.commit();
      logger.info('User data cleanup completed', { userId });
    } catch (error) {
      logger.error('Failed to cleanup user data', { userId, error });
      // Don't throw - we don't want to block user deletion
    }
  }
);

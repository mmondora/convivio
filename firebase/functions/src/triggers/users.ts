/**
 * User Lifecycle Triggers
 *
 * Handles user creation and deletion events.
 */

import { auth } from 'firebase-functions/v1';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';
import type { User, Cellar } from '../types';

const db = getFirestore();

// ============================================================
// USER CREATION
// ============================================================

export const onUserCreate = auth.user().onCreate(async (user) => {
  logger.info('New user created', { uid: user.uid, email: user.email });

  const now = Timestamp.now();

  // Create user document
  const userData: Omit<User, 'id'> = {
    email: user.email || '',
    displayName: user.displayName || user.email?.split('@')[0] || 'Utente',
    photoUrl: user.photoURL || undefined,
    createdAt: now,
    updatedAt: now,
    preferences: {
      language: 'it',
      notifications: true,
    },
  };

  // Create default cellar
  const cellarData: Omit<Cellar, 'id'> = {
    name: 'La mia cantina',
    description: 'Cantina personale',
    members: {
      [user.uid]: 'owner',
    },
    createdAt: now,
    updatedAt: now,
  };

  try {
    const batch = db.batch();

    // Create user document
    const userRef = db.collection('users').doc(user.uid);
    batch.set(userRef, userData);

    // Create default cellar
    const cellarRef = db.collection('cellars').doc();
    batch.set(cellarRef, cellarData);

    await batch.commit();

    logger.info('User setup completed', {
      uid: user.uid,
      cellarId: cellarRef.id,
    });
  } catch (error) {
    logger.error('Failed to setup user', { uid: user.uid, error });
    throw error;
  }
});

// ============================================================
// USER DELETION
// ============================================================

export const onUserDelete = auth.user().onDelete(async (user) => {
  logger.info('User deleted', { uid: user.uid });

  try {
    const batch = db.batch();

    // Delete user document
    const userRef = db.collection('users').doc(user.uid);
    batch.delete(userRef);

    // Find cellars where user is a member
    const cellarsSnapshot = await db.collection('cellars')
      .where(`members.${user.uid}`, 'in', ['owner', 'family', 'guest'])
      .get();

    for (const cellarDoc of cellarsSnapshot.docs) {
      const cellarData = cellarDoc.data();
      const userRole = cellarData.members?.[user.uid];

      if (userRole === 'owner') {
        // Delete all bottles in cellar
        const bottlesSnapshot = await cellarDoc.ref.collection('bottles').get();
        for (const bottleDoc of bottlesSnapshot.docs) {
          batch.delete(bottleDoc.ref);
        }
        // Delete the cellar itself
        batch.delete(cellarDoc.ref);
      } else {
        // Just remove user from members
        batch.update(cellarDoc.ref, {
          [`members.${user.uid}`]: FieldValue.delete(),
          updatedAt: Timestamp.now(),
        });
      }
    }

    // Delete user's dinner events
    const dinnersSnapshot = await db.collection('dinners')
      .where('hostId', '==', user.uid)
      .get();

    for (const dinnerDoc of dinnersSnapshot.docs) {
      batch.delete(dinnerDoc.ref);
    }

    // Delete user's conversations
    const conversationsSnapshot = await db.collection('conversations')
      .where('userId', '==', user.uid)
      .get();

    for (const convDoc of conversationsSnapshot.docs) {
      // Delete messages in conversation
      const messagesSnapshot = await convDoc.ref.collection('messages').get();
      for (const msgDoc of messagesSnapshot.docs) {
        batch.delete(msgDoc.ref);
      }
      batch.delete(convDoc.ref);
    }

    await batch.commit();

    logger.info('User cleanup completed', { uid: user.uid });
  } catch (error) {
    logger.error('Failed to cleanup user data', { uid: user.uid, error });
    throw error;
  }
});

/**
 * Health Check Endpoint
 *
 * Simple health check for monitoring and deployment verification.
 */

import { onCall } from 'firebase-functions/v2/https';
import { getFirestore, Timestamp } from 'firebase-admin/firestore';

const db = getFirestore();

export const healthCheck = onCall(
  {
    region: 'europe-west1',
  },
  async () => {
    const startTime = Date.now();

    // Test Firestore connectivity
    let firestoreStatus = 'ok';
    let firestoreLatency = 0;

    try {
      const firestoreStart = Date.now();
      await db.collection('_health').doc('ping').set({
        timestamp: Timestamp.now(),
      });
      firestoreLatency = Date.now() - firestoreStart;
    } catch (error) {
      firestoreStatus = 'error';
    }

    const totalLatency = Date.now() - startTime;

    return {
      status: 'ok',
      timestamp: new Date().toISOString(),
      version: '1.1',
      services: {
        firestore: firestoreStatus,
      },
      latency: {
        firestore: firestoreLatency,
      },
      totalLatency,
    };
  }
);

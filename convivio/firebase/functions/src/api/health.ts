/**
 * Health Check Endpoint
 * 
 * Endpoint semplice per verificare che le functions siano operative.
 */

import { onRequest } from 'firebase-functions/v2/https';
import { getFirestore } from 'firebase-admin/firestore';
import { logger } from 'firebase-functions';

const db = getFirestore();

export const healthCheck = onRequest(
  { 
    cors: true,
    region: 'europe-west1'
  },
  async (req, res) => {
    const startTime = Date.now();
    
    const checks = {
      status: 'ok' as 'ok' | 'degraded' | 'error',
      timestamp: new Date().toISOString(),
      version: process.env.K_REVISION || 'local',
      services: {
        firestore: 'unknown' as 'ok' | 'error',
      },
      latency: {
        firestore: 0,
      }
    };
    
    // Check Firestore connectivity
    try {
      const fsStart = Date.now();
      await db.collection('_health').doc('check').get();
      checks.services.firestore = 'ok';
      checks.latency.firestore = Date.now() - fsStart;
    } catch (error) {
      checks.services.firestore = 'error';
      checks.status = 'degraded';
      logger.error('Firestore health check failed', { error });
    }
    
    // Overall status
    const hasErrors = Object.values(checks.services).some(s => s === 'error');
    if (hasErrors) {
      checks.status = 'degraded';
    }
    
    const totalLatency = Date.now() - startTime;
    
    res.status(checks.status === 'ok' ? 200 : 503).json({
      ...checks,
      totalLatency
    });
  }
);

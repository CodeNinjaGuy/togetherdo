/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Push-Versand für den Kalender, gleiche Nachrichtenform wie in
// `notifications.ts` (Kanal, Ton, Priorität). Als eigene Funktion, damit die
// Kalender-Logik einen Fake-Sender bekommen kann; im Emulator wird nie echt
// gesendet.

import * as admin from 'firebase-admin';
import { messaging } from './common';

export interface PushInhalt {
  title: string;
  body: string;
  data: Record<string, string>;
}

export type PushSender = (tokens: string[], inhalt: PushInhalt) => Promise<void>;

/** Echter Versand über FCM (höchstens 500 Geräte je Aufruf). */
export const sendePush: PushSender = async (tokens, inhalt) => {
  if (!tokens.length) return;
  if (process.env.FUNCTIONS_EMULATOR === 'true') {
    console.log(`ℹ️ (Emulator) Push an ${tokens.length} Gerät(e) übersprungen`);
    return;
  }
  const notification = { title: inhalt.title, body: inhalt.body };
  for (let i = 0; i < tokens.length; i += 500) {
    const batch = tokens.slice(i, i + 500);
    const message: admin.messaging.MulticastMessage = {
      notification,
      data: inhalt.data,
      android: {
        notification: { ...notification, sound: 'notification_sound', channelId: 'togetherdo_channel', priority: 'high' },
      },
      apns: {
        headers: { 'apns-priority': '10' },
        payload: {
          aps: { alert: notification, sound: 'notification_sound.aiff', badge: 1, 'interruption-level': 'time-sensitive' },
        },
      },
      tokens: batch,
    };
    const response = await messaging.sendEachForMulticast(message);
    response.responses.forEach((r, j) => {
      if (!r.success) console.error('🚨 Push fehlgeschlagen bei', batch[j], r.error?.message);
    });
  }
};

/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Kontolöschung (App-Store-Richtlinie 5.1.1(v)).
//
// Ablauf: Die App meldet den Nutzer neu an (Passwort) und ruft `deleteAccount`
// auf. Der Server räumt alle Daten auf und löscht das Auth-Konto ZULETZT.
// Scheitert etwas, bleibt das Konto bestehen und der Aufruf kann wiederholt
// werden – jeder Schritt ist wiederholbar. Wird ein Konto auf anderem Weg
// gelöscht (Konsole, Client), räumt `onUserDeleted` dieselben Daten auf.
//
// Eigene Listen: Hat die Liste weitere Mitglieder, geht der Besitz an das am
// längsten beigetretene Mitglied über (die gemeinsame Liste bleibt für die
// anderen erhalten). Ohne weitere Mitglieder wird sie samt Inhalt gelöscht.

import * as admin from 'firebase-admin';
import * as functionsV1 from 'firebase-functions/v1';
import { onCall, HttpsError } from 'firebase-functions/v2/https';
import { FieldValue } from 'firebase-admin/firestore';
import {
  db,
  REGION,
  requireAuth,
  deleteQueryInBatches,
  deleteListContent,
  SILENT_DELETE_FIELD,
} from './common';

/** Wie frisch die Anmeldung für `deleteAccount` sein muss. */
const RECENT_LOGIN_SECONDS = 10 * 60;

export function avatarPath(uid: string): string {
  return `avatars/${uid}.jpg`;
}

/** Eigene Listen übergeben oder löschen, aus fremden Listen austreten. */
async function cleanupLists(uid: string): Promise<void> {
  const lists = await db.collection('lists').where('allUserIds', 'array-contains', uid).get();
  // Ältere Listen ohne allUserIds, in denen der Nutzer Besitzer ist.
  const owned = await db.collection('lists').where('ownerId', '==', uid).get();
  const docs = new Map<string, admin.firestore.QueryDocumentSnapshot>();
  [...lists.docs, ...owned.docs].forEach((d) => docs.set(d.id, d));

  for (const doc of docs.values()) {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(doc.ref);
      const d = snap.data();
      if (!snap.exists || !d) return;
      const memberIds: string[] = [...(d.memberIds ?? [])];
      const memberNames: string[] = [...(d.memberNames ?? [])];

      if (d.ownerId === uid) {
        if (memberIds.length === 0) {
          tx.delete(doc.ref);
          return;
        }
        const newOwnerId = memberIds.shift() as string;
        const newOwnerName = memberNames.shift() ?? 'Unbekannt';
        tx.update(doc.ref, {
          ownerId: newOwnerId,
          ownerName: newOwnerName,
          memberIds,
          memberNames,
          allUserIds: [newOwnerId, ...memberIds],
          updatedAt: new Date().toISOString(),
        });
        return;
      }

      const index = memberIds.indexOf(uid);
      if (index >= 0) {
        memberIds.splice(index, 1);
        if (index < memberNames.length) memberNames.splice(index, 1);
      }
      tx.update(doc.ref, {
        memberIds,
        memberNames,
        allUserIds: FieldValue.arrayRemove(uid),
        updatedAt: new Date().toISOString(),
      });
    });
  }

  // Inhalte gelöschter Listen sofort entfernen (onListDeleted macht dasselbe,
  // läuft aber verzögert; doppelt ist unschädlich).
  for (const doc of owned.docs) {
    const after = await doc.ref.get();
    if (!after.exists) await deleteListContent(doc.id);
  }
}

/** Eigene Todos (mit Chat) und Einkaufsartikel löschen – ohne Push-Flut. */
async function cleanupOwnContent(uid: string): Promise<void> {
  const markSilent = async (doc: admin.firestore.QueryDocumentSnapshot) => {
    await doc.ref.update({ [SILENT_DELETE_FIELD]: true });
  };
  await deleteQueryInBatches(db.collection('todos').where('userId', '==', uid), async (doc) => {
    await deleteQueryInBatches(doc.ref.collection('chatMessages'));
    await markSilent(doc);
  });
  await deleteQueryInBatches(db.collection('shopping_items').where('userId', '==', uid), markSilent);

  // Eigene Nachrichten in fremden Todos.
  await deleteQueryInBatches(db.collectionGroup('chatMessages').where('userId', '==', uid));

  // Zuweisungen und „erledigt von“ in fremden Todos entfernen (Name ist personenbezogen).
  const assigned = await db.collection('todos').where('assignedToUserId', '==', uid).get();
  const completed = await db.collection('todos').where('completedByUserId', '==', uid).get();
  const batch = db.batch();
  assigned.docs.forEach((d) => batch.update(d.ref, { assignedToUserId: null, assignedToUserName: null }));
  completed.docs.forEach((d) => batch.update(d.ref, { completedByUserId: null, completedByUserName: null }));
  if (!assigned.empty || !completed.empty) await batch.commit();
}

async function deleteAvatar(uid: string): Promise<void> {
  try {
    await admin.storage().bucket().file(avatarPath(uid)).delete({ ignoreNotFound: true });
  } catch (e) {
    // Fehlender Bucket (z. B. Emulator ohne Storage) darf die Löschung nicht blockieren.
    console.warn('Profilbild nicht gelöscht:', (e as Error).message);
  }
}

/** Entfernt alle Daten eines Nutzers. Mehrfach aufrufbar. */
export async function cleanupUserData(uid: string): Promise<void> {
  await cleanupLists(uid);
  await cleanupOwnContent(uid);
  await deleteAvatar(uid);
  await db.collection('rateLimits').doc(uid).delete();
  // Nutzer-Dokument (Profil, FCM-Token, Einstellungen) zuletzt.
  await db.collection('users').doc(uid).delete();
}

/** Löscht das eigene Konto vollständig. Verlangt eine frische Anmeldung. */
export const deleteAccount = onCall({ region: REGION, timeoutSeconds: 300 }, async (request) => {
  const uid = requireAuth(request);
  const authTime = Number(request.auth?.token.auth_time ?? 0);
  if (Date.now() / 1000 - authTime > RECENT_LOGIN_SECONDS) {
    throw new HttpsError('failed-precondition', 'requires-recent-login');
  }
  await cleanupUserData(uid);
  try {
    await admin.auth().deleteUser(uid);
  } catch (e) {
    if ((e as { code?: string }).code !== 'auth/user-not-found') throw e;
  }
  return { deleted: true };
});

/** Sicherheitsnetz: Konto wurde gelöscht (Konsole, Client) → Daten aufräumen. */
export const onUserDeleted = functionsV1
  .region(REGION)
  .auth.user()
  .onDelete(async (user) => {
    await cleanupUserData(user.uid);
  });

/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Gemeinsame Grundlagen aller Functions. Wird zuerst geladen, damit
// `initializeApp()` vor jedem Zugriff auf Firestore/Messaging läuft.

import * as admin from 'firebase-admin';
import { CallableRequest, HttpsError } from 'firebase-functions/v2/https';

admin.initializeApp();

export const REGION = 'europe-west3';

export const db = admin.firestore();
export const messaging = admin.messaging();

/** Feld, mit dem die Kontolöschung Dokumente vor dem Löschen markiert,
 *  damit die Push-Functions dafür keine „gelöscht“-Nachricht schicken. */
export const SILENT_DELETE_FIELD = 'silentDelete';

/** Liefert die UID des Aufrufers oder bricht mit `unauthenticated` ab. */
export function requireAuth(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError('unauthenticated', 'Anmeldung erforderlich');
  return uid;
}

/** Bucket der App (`<projekt>.firebasestorage.app`, wie in firebase_options). */
export function appBucket() {
  const projectId = process.env.GCLOUD_PROJECT ?? JSON.parse(process.env.FIREBASE_CONFIG ?? '{}').projectId;
  return admin.storage().bucket(`${projectId}.firebasestorage.app`);
}

/** Löscht alle Dokumente einer Abfrage in Paketen (max. 400 je Batch). */
export async function deleteQueryInBatches(
  query: admin.firestore.Query,
  beforeDelete?: (doc: admin.firestore.QueryDocumentSnapshot) => Promise<void>,
): Promise<number> {
  let deleted = 0;
  for (;;) {
    const snap = await query.limit(400).get();
    if (snap.empty) return deleted;
    for (const doc of snap.docs) {
      if (beforeDelete) await beforeDelete(doc);
    }
    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    deleted += snap.size;
    if (snap.size < 400) return deleted;
  }
}

/** Löscht ein Todo samt seinem Chat. */
export async function deleteTodoWithChat(
  todoRef: admin.firestore.DocumentReference,
): Promise<void> {
  await deleteQueryInBatches(todoRef.collection('chatMessages'));
  await todoRef.delete();
}

/** Löscht alle Todos (mit Chats) und Einkaufsartikel einer Liste. */
export async function deleteListContent(listId: string): Promise<void> {
  await deleteQueryInBatches(
    db.collection('todos').where('listId', '==', listId),
    (doc) => deleteQueryInBatches(doc.ref.collection('chatMessages')).then(() => undefined),
  );
  await deleteQueryInBatches(db.collection('shopping_items').where('listId', '==', listId));
}

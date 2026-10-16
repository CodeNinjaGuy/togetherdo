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

/** Löscht alle Dateien unter einem Storage-Pfad (Anhänge, Chat-Bilder).
 *  Ein fehlender Bucket (Emulator ohne Storage) blockiert nichts. */
export async function deleteStoragePrefix(prefix: string): Promise<void> {
  try {
    await appBucket().deleteFiles({ prefix, force: true });
  } catch (e) {
    console.warn(`Storage ${prefix} nicht aufgeräumt:`, (e as Error).message);
  }
}

/** Storage-Bereiche je Liste: Anhänge an Aufgaben, Bilder im Chat,
 *  Anhänge an Terminen. */
export const STORAGE_BEREICHE = ['todos', 'chats', 'termine'] as const;

/** Storage-Pfade einer Aufgabe: Anhänge und Chat-Bilder. */
export function todoStoragePrefixes(listId: string, todoId: string): string[] {
  return [`todos/${listId}/${todoId}/`, `chats/${listId}/${todoId}/`];
}

/** Storage-Pfad eines Termins (Anhänge). */
export function terminStoragePrefix(listId: string, terminId: string): string {
  return `termine/${listId}/${terminId}/`;
}

/** Löscht Chat und Anhang-Beschreibungen einer Aufgabe (Unter-Sammlungen). */
export async function deleteTodoSubcollections(
  todoRef: admin.firestore.DocumentReference,
): Promise<void> {
  await deleteQueryInBatches(todoRef.collection('chatMessages'));
  await deleteQueryInBatches(todoRef.collection('anhaenge'));
}

/** Löscht die Anhang-Beschreibungen eines Termins (Unter-Sammlung). */
export async function deleteTerminSubcollections(
  terminRef: admin.firestore.DocumentReference,
): Promise<void> {
  await deleteQueryInBatches(terminRef.collection('anhaenge'));
}

/** Löscht ein Todo samt Chat, Anhängen und Dateien. */
export async function deleteTodoWithChat(
  todoRef: admin.firestore.DocumentReference,
): Promise<void> {
  const snap = await todoRef.get();
  const listId = snap.data()?.listId as string | undefined;
  await deleteTodoSubcollections(todoRef);
  await todoRef.delete();
  if (listId) {
    for (const prefix of todoStoragePrefixes(listId, todoRef.id)) await deleteStoragePrefix(prefix);
  }
}

/** Alle Termine einer Liste löschen (mit Anhang-Beschreibungen). Sie
 *  werden vorher still markiert: `onTerminDeleted` räumt dann nichts mehr
 *  einzeln auf, weil die Liste ihre Storage-Bereiche als Ganzes löscht. */
export async function deleteTermineOfList(listId: string): Promise<number> {
  return deleteQueryInBatches(db.collection('termine').where('listId', '==', listId), async (doc) => {
    await deleteTerminSubcollections(doc.ref);
    await doc.ref.update({ [SILENT_DELETE_FIELD]: true });
  });
}

/** Löscht alle Inhalte einer Liste: Todos (mit Chats und Anhängen),
 *  Einkaufsartikel, Termine (mit Anhängen) und alle Dateien der Liste
 *  (todos/, chats/, termine/). Einziger Aufräumer beim Löschen einer Liste. */
export async function deleteListContent(listId: string): Promise<void> {
  await deleteQueryInBatches(
    db.collection('todos').where('listId', '==', listId),
    (doc) => deleteTodoSubcollections(doc.ref),
  );
  await deleteQueryInBatches(db.collection('shopping_items').where('listId', '==', listId));
  await deleteTermineOfList(listId);
  for (const bereich of STORAGE_BEREICHE) await deleteStoragePrefix(`${bereich}/${listId}/`);
}

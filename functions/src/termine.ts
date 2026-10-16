/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Firestore-Auslöser für `termine/{id}`:
// - neuer Termin → Push „Neuer Termin: …“ an betroffene Mitglieder (ohne Ersteller)
// - gelöschter Termin → Anhang-Beschreibungen (`termine/{id}/anhaenge`) und
//   Dateien (`termine/{listId}/{terminId}/`) entfernen
// Gelöschte Listen räumt `onListDeleted` (lists.ts → deleteListContent)
// vollständig auf, auch Termine und ihre Dateien.

import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import {
  REGION,
  SILENT_DELETE_FIELD,
  deleteListContent,
  deleteStoragePrefix,
  deleteTermineOfList,
  deleteTerminSubcollections,
  terminStoragePrefix,
} from './common';
import { terminAusDaten, betroffenePersonen } from './termine_logik';
import { ladeListe, ladeNutzer, standardDeps, KalenderDeps } from './empfaenger';
import { PushInhalt } from './push';

export const PUSH_TYP_NEU = 'termin_created';

/** Kern des „Neuer Termin“-Push, testbar mit Fake-Sender. */
export async function neuerTerminPush(
  terminId: string,
  daten: Record<string, unknown>,
  deps: KalenderDeps = standardDeps(),
): Promise<number> {
  const termin = terminAusDaten(terminId, daten);
  if (!termin) return 0;
  const liste = await ladeListe(deps, termin.listId);
  const empfaenger = betroffenePersonen(termin, liste?.allUserIds ?? []).filter((uid) => uid !== termin.erstelltVon);
  if (empfaenger.length === 0) return 0;
  const nutzer = await ladeNutzer(deps, empfaenger);
  const tokens: string[] = [];
  for (const uid of empfaenger) {
    const n = nutzer.get(uid);
    if (!n?.fcmToken) continue;
    const erlaubt = n.notificationSettings[PUSH_TYP_NEU];
    if (erlaubt === false) continue;
    tokens.push(n.fcmToken);
  }
  if (tokens.length === 0) return 0;
  const inhalt: PushInhalt = {
    title: 'Neuer Termin',
    body: `Neuer Termin: ${termin.titel}`,
    data: { type: PUSH_TYP_NEU, terminId, listId: termin.listId, createdBy: termin.erstelltVon },
  };
  await deps.pushSenden(tokens, inhalt);
  return tokens.length;
}

export const onTerminCreated = onDocumentCreated({ region: REGION, document: 'termine/{terminId}' }, async (event) => {
  const d = event.data?.data();
  if (!d) return;
  await neuerTerminPush(event.params.terminId, d as Record<string, unknown>);
});

export const onTerminDeleted = onDocumentDeleted({ region: REGION, document: 'termine/{terminId}' }, async (event) => {
  const d = event.data?.data();
  // Beim Löschen einer Liste räumt deleteListContent alles gesammelt auf.
  if (!d || d[SILENT_DELETE_FIELD] === true) return;
  if (event.data) await deleteTerminSubcollections(event.data.ref);
  if (typeof d.listId === 'string') {
    await deleteStoragePrefix(terminStoragePrefix(d.listId, event.params.terminId));
  }
});

/** Alle Termine einer Liste still löschen (Teil von deleteListContent;
 *  für Tests einzeln aufrufbar). */
export async function loescheTermineDerListe(listId: string): Promise<number> {
  return deleteTermineOfList(listId);
}

// Für Tests: vollständiges Aufräumen einer Liste.
export { deleteListContent };

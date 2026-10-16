/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Firestore-Auslöser für `termine/{id}`:
// - neuer Termin → Push „Neuer Termin: …“ an betroffene Mitglieder (ohne Ersteller)
// - gelöschter Termin → Anhänge in Storage (`termine/{listId}/{terminId}/`) entfernen
// - gelöschte Liste → alle Termine der Liste (still) und ihr Storage-Präfix entfernen
//   (eigener Export `onListDeletedTermine`, `lists.ts` bleibt unverändert)

import { onDocumentCreated, onDocumentDeleted } from 'firebase-functions/v2/firestore';
import { REGION, db, appBucket, deleteQueryInBatches, SILENT_DELETE_FIELD } from './common';
import { terminAusDaten, betroffenePersonen } from './termine_logik';
import { ladeListe, ladeNutzer, standardDeps, KalenderDeps } from './empfaenger';
import { PushInhalt } from './push';

export const PUSH_TYP_NEU = 'termin_created';

export function storagePraefix(listId: string, terminId?: string): string {
  return terminId ? `termine/${listId}/${terminId}/` : `termine/${listId}/`;
}

/** Löscht alle Dateien unter einem Präfix; Fehler werden nur gewarnt. */
export async function loescheStoragePraefix(praefix: string): Promise<void> {
  try {
    await appBucket().deleteFiles({ prefix: praefix, force: true });
  } catch (e) {
    console.warn('⚠️ Storage-Präfix nicht gelöscht:', praefix, (e as Error).message);
  }
}

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
  const listId = typeof d?.listId === 'string' ? d.listId : null;
  if (!listId) return;
  await loescheStoragePraefix(storagePraefix(listId, event.params.terminId));
});

/** Alle Termine einer Liste still löschen und ihr Storage-Präfix entfernen. */
export async function loescheTermineDerListe(listId: string): Promise<number> {
  const anzahl = await deleteQueryInBatches(db.collection('termine').where('listId', '==', listId), async (doc) => {
    await doc.ref.update({ [SILENT_DELETE_FIELD]: true });
  });
  await loescheStoragePraefix(storagePraefix(listId));
  return anzahl;
}

export const onListDeletedTermine = onDocumentDeleted({ region: REGION, document: 'lists/{listId}' }, async (event) => {
  await loescheTermineDerListe(event.params.listId);
});

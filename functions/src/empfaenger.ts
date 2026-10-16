/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Gemeinsames für Kalender-Mails und -Push: Abhängigkeiten (austauschbar für
// Tests), Listen und Nutzer laden, Namen auflösen, Mail-Einstellungen lesen,
// Abmelde-Token erzeugen und die Links der Fußzeile bauen.

import { randomBytes } from 'crypto';
import type { Firestore, DocumentReference } from 'firebase-admin/firestore';
import { FieldPath } from 'firebase-admin/firestore';
import { db, REGION } from './common';
import { PushSender, sendePush } from './push';
import { Mail, MailSender, sendeMail } from './mail/sesVersand';
import { Sprache, spracheVon } from './mail/texte';
import { FussLinks } from './mail/vorlagen';

export type MailAktion = 'abmelden' | 'wochenueberblick-aus' | 'monatsueberblick-aus';
export type ErinnerungsWeg = 'push' | 'mail' | 'beide' | 'keine';

export const ERINNERUNGS_WEGE: readonly ErinnerungsWeg[] = ['push', 'mail', 'beide', 'keine'];

export interface KalenderDeps {
  db: Firestore;
  pushSenden: PushSender;
  mailSenden: MailSender;
  einstellungenUrl: (uid: string, token: string, aktion: MailAktion) => string;
}

/** Öffentliche Adresse der `mailEinstellungen`-Function. */
export function standardEinstellungenUrl(uid: string, token: string, aktion: MailAktion): string {
  const basis =
    process.env.MAIL_EINSTELLUNGEN_URL ??
    `https://${REGION}-${process.env.GCLOUD_PROJECT ?? 'togetherdo-c9179'}.cloudfunctions.net/mailEinstellungen`;
  const p = new URLSearchParams({ uid, token, aktion });
  return `${basis}?${p.toString()}`;
}

export function standardDeps(): KalenderDeps {
  return { db, pushSenden: sendePush, mailSenden: sendeMail, einstellungenUrl: standardEinstellungenUrl };
}

export interface ListenInfo {
  id: string;
  name: string;
  ownerId: string;
  ownerName: string;
  shareCode: string;
  allUserIds: string[];
  /** uid → Anzeigename aus ownerName/memberNames */
  namen: Map<string, string>;
}

export function listenInfoAus(id: string, d: Record<string, unknown> | undefined): ListenInfo | null {
  if (!d) return null;
  const memberIds = Array.isArray(d.memberIds) ? (d.memberIds as string[]) : [];
  const memberNames = Array.isArray(d.memberNames) ? (d.memberNames as string[]) : [];
  const ownerId = typeof d.ownerId === 'string' ? d.ownerId : '';
  const ownerName = typeof d.ownerName === 'string' ? d.ownerName : '';
  const namen = new Map<string, string>();
  if (ownerId) namen.set(ownerId, ownerName);
  memberIds.forEach((uid, i) => {
    if (typeof uid === 'string' && typeof memberNames[i] === 'string') namen.set(uid, memberNames[i]);
  });
  const allUserIds = Array.isArray(d.allUserIds)
    ? (d.allUserIds as unknown[]).filter((u): u is string => typeof u === 'string')
    : [ownerId, ...memberIds].filter(Boolean);
  return {
    id,
    name: typeof d.name === 'string' ? d.name : '',
    ownerId,
    ownerName,
    shareCode: typeof d.shareCode === 'string' ? d.shareCode : '',
    allUserIds,
    namen,
  };
}

export async function ladeListe(deps: KalenderDeps, listId: string): Promise<ListenInfo | null> {
  const snap = await deps.db.collection('lists').doc(listId).get();
  return snap.exists ? listenInfoAus(snap.id, snap.data()) : null;
}

export interface Nutzer {
  uid: string;
  ref: DocumentReference;
  email: string | null;
  displayName: string;
  fcmToken: string | null;
  sprache: Sprache;
  erinnerungen: ErinnerungsWeg;
  wochenueberblick: boolean;
  /** Monatsüberblick am 1. des Monats; Standard aus (Feld fehlt bei Altkonten). */
  monatsueberblick: boolean;
  einladungen: boolean;
  mailAbmeldeToken: string | null;
  notificationSettings: Record<string, unknown>;
}

export function nutzerAus(uid: string, ref: DocumentReference, d: Record<string, unknown> | undefined): Nutzer {
  const daten = d ?? {};
  const mail = (typeof daten.mailEinstellungen === 'object' && daten.mailEinstellungen
    ? daten.mailEinstellungen
    : {}) as Record<string, unknown>;
  const weg = mail.erinnerungen;
  return {
    uid,
    ref,
    email: typeof daten.email === 'string' && daten.email.includes('@') ? daten.email : null,
    displayName: typeof daten.displayName === 'string' ? daten.displayName : '',
    fcmToken: typeof daten.fcmToken === 'string' && daten.fcmToken ? daten.fcmToken : null,
    sprache: spracheVon(daten.languageCode),
    erinnerungen: typeof weg === 'string' && ERINNERUNGS_WEGE.includes(weg as ErinnerungsWeg) ? (weg as ErinnerungsWeg) : 'push',
    wochenueberblick: mail.wochenueberblick === true,
    monatsueberblick: mail.monatsueberblick === true,
    einladungen: mail.einladungen !== false,
    mailAbmeldeToken: typeof daten.mailAbmeldeToken === 'string' && daten.mailAbmeldeToken.length >= 32 ? daten.mailAbmeldeToken : null,
    notificationSettings: (typeof daten.notificationSettings === 'object' && daten.notificationSettings
      ? daten.notificationSettings
      : {}) as Record<string, unknown>,
  };
}

/** Lädt Nutzer in 10er-Paketen (`in`-Abfrage). Fehlende Dokumente fehlen im Ergebnis. */
export async function ladeNutzer(deps: KalenderDeps, uids: string[]): Promise<Map<string, Nutzer>> {
  const ergebnis = new Map<string, Nutzer>();
  const eindeutig = [...new Set(uids)].filter(Boolean);
  for (let i = 0; i < eindeutig.length; i += 10) {
    const chunk = eindeutig.slice(i, i + 10);
    const snap = await deps.db.collection('users').where(FieldPath.documentId(), 'in', chunk).get();
    snap.forEach((doc) => ergebnis.set(doc.id, nutzerAus(doc.id, doc.ref, doc.data())));
  }
  return ergebnis;
}

/** Anzeigename: zuerst aus der Liste (ownerName/memberNames), sonst Profil. */
export function nameVon(uid: string, liste: ListenInfo | null, nutzer: Map<string, Nutzer>): string {
  const ausListe = liste?.namen.get(uid);
  if (ausListe && ausListe.trim()) return ausListe.trim();
  const profil = nutzer.get(uid)?.displayName;
  if (profil && profil.trim()) return profil.trim();
  return '';
}

export function erzeugeAbmeldeToken(): string {
  return randomBytes(32).toString('base64url'); // 43 Zeichen
}

/**
 * Liefert das Abmelde-Token des Nutzers und legt es beim ersten Versand an.
 * Nur die Function schreibt dieses Feld.
 */
export async function sichereAbmeldeToken(deps: KalenderDeps, nutzer: Nutzer): Promise<string> {
  if (nutzer.mailAbmeldeToken) return nutzer.mailAbmeldeToken;
  const token = erzeugeAbmeldeToken();
  await deps.db.runTransaction(async (tx) => {
    const snap = await tx.get(nutzer.ref);
    const vorhanden = snap.data()?.mailAbmeldeToken;
    if (typeof vorhanden === 'string' && vorhanden.length >= 32) {
      nutzer.mailAbmeldeToken = vorhanden;
      return;
    }
    tx.set(nutzer.ref, { mailAbmeldeToken: token }, { merge: true });
    nutzer.mailAbmeldeToken = token;
  });
  return nutzer.mailAbmeldeToken as string;
}

export async function fussLinks(deps: KalenderDeps, nutzer: Nutzer, abmelden: MailAktion | null): Promise<FussLinks> {
  const token = await sichereAbmeldeToken(deps, nutzer);
  const links: FussLinks = { einstellungen: deps.einstellungenUrl(nutzer.uid, token, 'abmelden') };
  if (abmelden === 'abmelden') links.abmelden = { url: deps.einstellungenUrl(nutzer.uid, token, 'abmelden'), schluessel: 'fuss.abmelden' };
  if (abmelden === 'wochenueberblick-aus') {
    links.abmelden = { url: deps.einstellungenUrl(nutzer.uid, token, 'wochenueberblick-aus'), schluessel: 'fuss.wochenueberblick.abmelden' };
  }
  if (abmelden === 'monatsueberblick-aus') {
    links.abmelden = { url: deps.einstellungenUrl(nutzer.uid, token, 'monatsueberblick-aus'), schluessel: 'fuss.monatsueberblick.abmelden' };
  }
  return links;
}

/** Schickt eine Mail und fängt Fehler ab (nur Art im Log, nie Adresse). */
export async function mailSicherSenden(deps: KalenderDeps, mail: Mail): Promise<boolean> {
  try {
    await deps.mailSenden(mail);
    return true;
  } catch (e) {
    console.warn(`⚠️ Mail (${mail.art}) nicht verschickt:`, (e as Error).message);
    return false;
  }
}

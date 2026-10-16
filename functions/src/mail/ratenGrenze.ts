/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Ratenbegrenzung für den Mailversand, gespeichert in `rateLimits` (nur
// Server; die Regeln geben die Sammlung keinem Client frei).
//
// Die Dokument-ID ist ein SHA-256 aus Art und Schlüssel, damit E-Mail-Adressen
// nie im Klartext in Firestore oder im Log stehen. `ablaufAm` erlaubt eine
// Firestore-TTL-Regel zum Aufräumen (optional, in der Konsole einzurichten).

import { createHash } from 'crypto';
import type { Firestore } from 'firebase-admin/firestore';
import { Timestamp } from 'firebase-admin/firestore';

export const SAMMLUNG = 'rateLimits';

export interface Grenze {
  /** Zeitfenster in Millisekunden */
  fensterMs: number;
  /** höchstens so viele Ereignisse im Fenster */
  max: number;
}

export const MINUTE = 60 * 1000;
export const STUNDE = 60 * MINUTE;
export const TAG = 24 * STUNDE;

/** Reine Logik: darf bei diesen bisherigen Zeitpunkten jetzt noch einmal? */
export function erlaubt(zeiten: number[], jetzt: number, grenzen: Grenze[]): boolean {
  return grenzen.every((g) => zeiten.filter((z) => z > jetzt - g.fensterMs).length < g.max);
}

export function dokumentId(art: string, schluessel: string): string {
  return createHash('sha256').update(`${art}:${schluessel.trim().toLowerCase()}`).digest('hex');
}

/**
 * Prüft die Grenzen und zählt bei Erfolg das Ereignis mit (atomar per
 * Transaktion). false = Grenze erreicht (dann wird nichts gezählt).
 */
export async function pruefeUndZaehle(
  db: Firestore,
  art: string,
  schluessel: string,
  grenzen: Grenze[],
  jetzt: number = Date.now(),
): Promise<boolean> {
  const ref = db.collection(SAMMLUNG).doc(dokumentId(art, schluessel));
  const laengstes = Math.max(...grenzen.map((g) => g.fensterMs));
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    const roh = snap.exists ? snap.data()?.zeiten : [];
    const zeiten = (Array.isArray(roh) ? roh : []).filter(
      (z): z is number => typeof z === 'number' && z > jetzt - laengstes,
    );
    if (!erlaubt(zeiten, jetzt, grenzen)) return false;
    zeiten.push(jetzt);
    tx.set(ref, {
      art,
      zeiten: zeiten.slice(-50),
      ablaufAm: Timestamp.fromMillis(jetzt + laengstes),
    });
    return true;
  });
}

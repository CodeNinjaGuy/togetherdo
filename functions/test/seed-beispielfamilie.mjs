/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Füllt den Firestore-Emulator (Kalender-Port 8090) mit der Beispielfamilie
// aus `lib/calendar/demo/beispiel_familie.dart` (Kurzfassung), damit die App
// mit --dart-define=USE_FIREBASE_EMULATOR=true echte Firestore-Daten zeigt.
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8090 node functions/test/seed-beispielfamilie.mjs [JJJJ-MM-TT]
// Nie gegen Produktion: bricht ohne FIRESTORE_EMULATOR_HOST ab.

import admin from 'firebase-admin';

if (!process.env.FIRESTORE_EMULATOR_HOST) {
  console.error('FIRESTORE_EMULATOR_HOST fehlt – nur gegen den Emulator ausführen.');
  process.exit(1);
}
admin.initializeApp({ projectId: process.env.GCLOUD_PROJECT ?? 'demo-togetherdo-kal' });
const db = admin.firestore();
const Ts = admin.firestore.Timestamp;

const heute = process.argv[2] ? new Date(`${process.argv[2]}T00:00:00Z`) : new Date(new Date().toISOString().slice(0, 10) + 'T00:00:00Z');
const montag = new Date(heute);
montag.setUTCDate(heute.getUTCDate() - ((heute.getUTCDay() + 6) % 7));
const tag = (versatz) => { const d = new Date(montag); d.setUTCDate(montag.getUTCDate() + versatz); return d; };
/** Wanduhrzeit Europe/Vienna → UTC (Sommerzeit über Intl). */
function wien(d, h, m = 0) {
  const probe = new Date(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate(), h, m));
  const teile = new Intl.DateTimeFormat('en-US', { timeZone: 'Europe/Vienna', timeZoneName: 'longOffset' }).formatToParts(probe);
  const off = teile.find((p) => p.type === 'timeZoneName')?.value ?? 'GMT+01:00';
  const [, vz, hh, mm] = off.match(/GMT([+-])(\d\d):(\d\d)/) ?? [null, '+', '01', '00'];
  const minuten = (Number(hh) * 60 + Number(mm)) * (vz === '-' ? -1 : 1);
  return new Date(probe.getTime() - minuten * 60_000);
}

const ich = 'u-markus', anna = 'u-anna', lisa = 'u-lisa', tom = 'u-tom', mia = 'u-mia';
const iso = new Date().toISOString();
const nutzer = [[ich, 'Markus'], [anna, 'Anna'], [lisa, 'Lisa'], [tom, 'Tom'], [mia, 'Mia']];
const listen = [
  { id: 'L-familie', name: 'Familie', ownerId: ich, ownerName: 'Markus', type: 'todo', memberIds: [anna, lisa, tom], memberNames: ['Anna', 'Lisa', 'Tom'], allUserIds: [ich, anna, lisa, tom] },
  { id: 'L-wg', name: 'WG Lisa', ownerId: lisa, ownerName: 'Lisa', type: 'shopping', memberIds: [ich, mia], memberNames: ['Markus', 'Mia'], allUserIds: [lisa, ich, mia] },
];
const unendlich = new Date('2200-01-01T00:00:00Z');
function termin(id, titel, art, start, ende, extra = {}) {
  return {
    id, listId: 'L-familie', titel, art, personen: [], start: Ts.fromDate(start), ende: Ts.fromDate(ende), ganztaegig: false,
    ort: null, notiz: null, zeitzone: 'Europe/Vienna', wiederholung: null, erinnerungen: [30], erstelltVon: ich,
    erstelltAm: Ts.fromDate(new Date()), aktualisiertAm: Ts.fromDate(new Date()),
    sichtbarBis: Ts.fromDate(extra.wiederholung ? unendlich : ende), naechsteErinnerungAm: null, letzteErinnerungSchluessel: null,
    ...extra,
  };
}
const woche = (tage) => ({ typ: 'woechentlich', intervall: 1, wochentage: tage, bisDatum: null, anzahl: null, ausnahmen: [] });
const termine = [
  termin('T-lisa-schicht', 'Frühschicht', 'arbeit', wien(tag(-56), 6), wien(tag(-56), 14), { personen: [lisa], ort: 'Klinikum', wiederholung: woche([1, 2, 3, 4, 5]), erinnerungen: [] }),
  termin('T-anna-schicht', 'Spätschicht', 'arbeit', wien(tag(-55), 14), wien(tag(-55), 22), { personen: [anna], wiederholung: woche([2, 4]), erinnerungen: [] }),
  termin('T-ich-buero', 'Büro', 'arbeit', wien(tag(-56), 9), wien(tag(-56), 17), { personen: [ich], ort: 'SeeBubble', wiederholung: woche([1, 2, 3, 4]), erinnerungen: [] }),
  termin('T-tom-schule', 'Schule', 'schule', wien(tag(-56), 8), wien(tag(-56), 13, 15), { personen: [tom], wiederholung: woche([1, 2, 3, 4, 5]), erinnerungen: [] }),
  termin('T-zahnarzt', 'Zahnarzt', 'arzt', wien(heute, 15), wien(heute, 16), { personen: [anna], ort: 'Dr. Huber, Hauptstraße 12', notiz: 'Versicherungskarte mitnehmen', erinnerungen: [60, 10] }),
  termin('T-essen', 'Familienessen bei Oma', 'termin', wien(heute, 18, 30), wien(heute, 21), { ort: 'Oma' }),
  termin('T-kinderarzt', 'Kinderarzt – Impfung', 'arzt', wien(tag(5), 10, 30), wien(tag(5), 11, 15), { personen: [tom, ich], ort: 'Dr. Lang', erstelltVon: anna }),
  termin('T-elternabend', 'Elternabend', 'schule', wien(tag(3), 19, 30), wien(tag(3), 21), { personen: [anna, ich], ort: 'Volksschule, Klasse 3b' }),
  termin('T-urlaub-ich', 'Urlaub', 'urlaub', wien(tag(7), 0), wien(tag(12), 0), { personen: [ich], ganztaegig: true, erinnerungen: [1440] }),
  termin('T-urlaub-alle', 'Sommerurlaub Italien', 'urlaub', wien(new Date(Date.UTC(heute.getUTCFullYear() + (heute.getUTCMonth() > 6 ? 1 : 0), 7, 3)), 0), wien(new Date(Date.UTC(heute.getUTCFullYear() + (heute.getUTCMonth() > 6 ? 1 : 0), 7, 15)), 0), { ganztaegig: true, ort: 'Gardasee', erinnerungen: [10080] }),
  termin('T-geb-anna', 'Annas Geburtstag', 'geburtstag', wien(tag((heute.getUTCDay() + 6) % 7 + 2), 0), wien(tag((heute.getUTCDay() + 6) % 7 + 3), 0), { ganztaegig: true, wiederholung: { typ: 'jaehrlich', intervall: 1, wochentage: [], bisDatum: null, anzahl: null, ausnahmen: [] }, erinnerungen: [1440] }),
  termin('T-wg-putzen', 'Putzdienst Küche', 'sonstiges', wien(tag(6), 10), wien(tag(6), 11), { listId: 'L-wg', personen: [mia, lisa], erstelltVon: lisa, wiederholung: { typ: 'woechentlich', intervall: 2, wochentage: [7], bisDatum: null, anzahl: null, ausnahmen: [] } }),
];

const batch = db.batch();
for (const [uid, name] of nutzer) {
  batch.set(db.doc(`users/${uid}`), { id: uid, email: `${name.toLowerCase()}@example.test`, displayName: name, createdAt: iso, lastLoginAt: iso, languageCode: 'de' }, { merge: true });
}
for (const l of listen) {
  batch.set(db.doc(`lists/${l.id}`), { ...l, createdAt: iso, updatedAt: iso, isShared: true, shareCode: l.id === 'L-familie' ? '111111' : '222222', allowEdit: true });
}
for (const t of termine) batch.set(db.doc(`termine/${t.id}`), t);
batch.set(db.doc('todos/A1'), { id: 'A1', title: 'Geschenk für Anna besorgen', description: '', isCompleted: false, createdAt: iso, dueDate: wien(tag(5), 18).toISOString(), priority: 'medium', userId: ich, listId: 'L-familie', assignedToUserId: ich });
await batch.commit();
console.log(`Beispielfamilie eingespielt: ${listen.length} Listen, ${termine.length} Termine (heute = ${heute.toISOString().slice(0, 10)}).`);

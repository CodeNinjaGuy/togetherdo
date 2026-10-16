/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Texte der Kalender-Mails in Deutsch und Englisch. Die Sprache kommt aus
// `users/{uid}.languageCode`; alles außer Englisch fällt auf Deutsch zurück.
// Platzhalter in geschweiften Klammern: {titel}, {liste}, {code}, …

export type Sprache = 'de' | 'en';

export const SPRACHEN: readonly Sprache[] = ['de', 'en'];

export function spracheVon(languageCode: unknown): Sprache {
  if (typeof languageCode === 'string' && languageCode.toLowerCase().startsWith('en')) return 'en';
  return 'de';
}

type Uebersetzungen = Record<Sprache, string>;

export const TEXTE = {
  'app.name': { de: 'ToGetherDo', en: 'ToGetherDo' },
  'anrede.name': { de: 'Hallo {name},', en: 'Hi {name},' },
  'anrede.ohne': { de: 'Hallo,', en: 'Hi there,' },
  gruss: { de: 'Dein ToGetherDo-Team', en: 'Your ToGetherDo team' },
  'fuss.automatisch': {
    de: 'Diese E-Mail wurde automatisch verschickt. Bitte antworte nicht darauf.',
    en: 'This email was sent automatically. Please do not reply.',
  },
  'fuss.einstellungen': { de: 'E-Mail-Einstellungen', en: 'Email settings' },
  'fuss.abmelden': { de: 'Keine Erinnerungs-Mails mehr', en: 'Stop reminder emails' },
  'fuss.wochenueberblick.abmelden': { de: 'Wochenüberblick abbestellen', en: 'Unsubscribe from weekly overview' },
  'fuss.monatsueberblick.abmelden': { de: 'Monatsüberblick abbestellen', en: 'Unsubscribe from monthly overview' },
  'fuss.hinweis.app': {
    de: 'Push-Benachrichtigungen und weitere Einstellungen findest du in der App unter Einstellungen.',
    en: 'You can manage push notifications and more in the app under Settings.',
  },

  // -------------------------------------------------------------- Erinnerung
  'erinnerung.betreff': { de: 'Erinnerung: {titel} – {zeit}', en: 'Reminder: {titel} – {zeit}' },
  'erinnerung.titel': { de: 'Gleich geht’s los', en: 'Coming up' },
  'erinnerung.jetzt': { de: 'Dein Termin beginnt jetzt.', en: 'Your event starts now.' },
  'erinnerung.in': { de: 'Dein Termin beginnt in {dauer}.', en: 'Your event starts in {dauer}.' },
  'erinnerung.ics': { de: 'In meinen Kalender übernehmen', en: 'Add to my calendar' },
  'erinnerung.ics.hinweis': {
    de: 'Die Kalenderdatei (.ics) hängt an dieser E-Mail an.',
    en: 'The calendar file (.ics) is attached to this email.',
  },
  'feld.wann': { de: 'Wann', en: 'When' },
  'feld.wo': { de: 'Wo', en: 'Where' },
  'feld.wer': { de: 'Wer', en: 'Who' },
  'feld.liste': { de: 'Liste', en: 'List' },
  'feld.notiz': { de: 'Notiz', en: 'Note' },
  'feld.alle': { de: 'Alle in der Liste', en: 'Everyone in the list' },
  'ganztaegig': { de: 'ganztägig', en: 'all day' },
  'dauer.minuten': { de: '{n} Minuten', en: '{n} minutes' },
  'dauer.minute': { de: '1 Minute', en: '1 minute' },
  'dauer.stunden': { de: '{n} Stunden', en: '{n} hours' },
  'dauer.stunde': { de: '1 Stunde', en: '1 hour' },
  'dauer.tage': { de: '{n} Tagen', en: '{n} days' },
  'dauer.tag': { de: '1 Tag', en: '1 day' },
  'dauer.wochen': { de: '{n} Wochen', en: '{n} weeks' },
  'dauer.woche': { de: '1 Woche', en: '1 week' },

  // --------------------------------------------------------- Wochenüberblick
  'woche.betreff': { de: 'Eure Woche: {von} – {bis}', en: 'Your week: {von} – {bis}' },
  'woche.titel': { de: 'Eure Woche auf einen Blick', en: 'Your week at a glance' },
  'woche.einleitung': {
    de: 'Das steht nächste Woche in euren Listen an:',
    en: 'Here is what is coming up in your lists next week:',
  },
  'woche.anzahl': { de: '{n} Termine', en: '{n} events' },
  'woche.einer': { de: '1 Termin', en: '1 event' },
  'woche.keine': { de: 'Keine Termine – eine freie Woche!', en: 'No events – a free week!' },

  // --------------------------------------------------------- Monatsüberblick
  'monat.betreff': { de: 'Euer Monat: {monat}', en: 'Your month: {monat}' },
  'monat.titel': { de: 'Was kommt im Monat', en: 'What’s coming this month' },
  'monat.einleitung': {
    de: 'Ein Blick auf den {monat} in euren Listen:',
    en: 'A look at {monat} across your lists:',
  },
  'monat.keine': { de: 'Keine Termine in diesem Monat.', en: 'No events this month.' },
  'monat.highlights': { de: 'Highlights', en: 'Highlights' },
  'monat.highlights.keine': {
    de: 'Keine Urlaube, Geburtstage, Arzttermine oder mehrtägigen Termine.',
    en: 'No vacations, birthdays, doctor’s appointments or multi-day events.',
  },
  'monat.wochenenden': { de: 'Freie Wochenenden', en: 'Free weekends' },
  'monat.wochenenden.hinweis': {
    de: 'Samstag und Sonntag ohne Termin, Urlaub oder Arbeit – für alle.',
    en: 'Saturday and Sunday with no event, vacation or work – for everyone.',
  },
  'monat.wochenenden.keine': { de: 'Kein Wochenende ist für alle frei.', en: 'No weekend is free for everyone.' },
  'monat.allefrei': { de: 'Alle frei', en: 'Everyone off' },
  'monat.allefrei.hinweis': {
    de: 'Zeiträume, in denen alle Mitglieder einer Liste Urlaub haben.',
    en: 'Periods when every member of a list is on vacation.',
  },
  'monat.allefrei.keine': { de: 'Kein gemeinsamer Urlaub in diesem Monat.', en: 'No shared vacation this month.' },
  'monat.unterwegs': { de: 'Wer ist wie viel unterwegs', en: 'Who is out and about' },
  'monat.unterwegs.urlaubstag': { de: '1 Urlaubstag', en: '1 vacation day' },
  'monat.unterwegs.urlaubstage': { de: '{n} Urlaubstage', en: '{n} vacation days' },
  'monat.unterwegs.arbeitstag': { de: '1 Arbeitstag', en: '1 work day' },
  'monat.unterwegs.arbeitstage': { de: '{n} Arbeitstage', en: '{n} work days' },
  'monat.unterwegs.stunden': { de: '{n} Std.', en: '{n} h' },
  'monat.unterwegs.termin': { de: '1 Termin', en: '1 event' },
  'monat.unterwegs.termine': { de: '{n} Termine', en: '{n} events' },
  'monat.unterwegs.nichts': { de: 'nichts eingetragen', en: 'nothing scheduled' },
  'art.urlaub': { de: 'Urlaub', en: 'Vacation' },
  'art.geburtstag': { de: 'Geburtstag', en: 'Birthday' },
  'art.arzt': { de: 'Arzt', en: 'Doctor' },
  'art.mehrtaegig': { de: 'Mehrtägig', en: 'Multi-day' },

  // --------------------------------------------------------------- Einladung
  'einladung.betreff': { de: '{name} lädt dich zur Liste „{liste}“ ein', en: '{name} invited you to the list “{liste}”' },
  'einladung.titel': { de: 'Du bist eingeladen', en: 'You are invited' },
  'einladung.text': {
    de: '{name} möchte die Liste „{liste}“ in ToGetherDo mit dir teilen – für Aufgaben, Einkäufe und gemeinsame Termine.',
    en: '{name} would like to share the list “{liste}” in ToGetherDo with you – for tasks, shopping and shared events.',
  },
  'einladung.code': { de: 'Dein Beitritts-Code', en: 'Your join code' },
  'einladung.schritte': {
    de: 'So trittst du bei: ToGetherDo öffnen → „Liste beitreten“ → Code eingeben.',
    en: 'How to join: open ToGetherDo → “Join list” → enter the code.',
  },
  'einladung.app': {
    de: 'Noch kein ToGetherDo? Die App gibt es kostenlos im App Store und bei Google Play.',
    en: 'Don’t have ToGetherDo yet? The app is free on the App Store and Google Play.',
  },
  'einladung.unerwartet': {
    de: 'Du kennst {name} nicht? Dann ignoriere diese E-Mail einfach.',
    en: 'Don’t know {name}? Just ignore this email.',
  },

  // ------------------------------------------------- Einstellungsseite (Web)
  'seite.titel': { de: 'E-Mail-Einstellungen', en: 'Email settings' },
  'seite.abgemeldet': {
    de: 'Erledigt. Du bekommst keine Erinnerungen mehr per E-Mail – nur noch als Push in der App.',
    en: 'Done. You will no longer receive reminders by email – only as push notifications in the app.',
  },
  'seite.wochenueberblick.aus': {
    de: 'Erledigt. Der Wochenüberblick ist abbestellt.',
    en: 'Done. The weekly overview is unsubscribed.',
  },
  'seite.monatsueberblick.aus': {
    de: 'Erledigt. Der Monatsüberblick ist abbestellt.',
    en: 'Done. The monthly overview is unsubscribed.',
  },
  'seite.ungueltig': {
    de: 'Dieser Link ist ungültig oder abgelaufen. Du kannst die E-Mail-Einstellungen jederzeit in der App ändern.',
    en: 'This link is invalid or has expired. You can change your email settings in the app at any time.',
  },
  'seite.zurueck': { de: 'Alles Weitere stellst du in der App ein.', en: 'Everything else can be set in the app.' },
} satisfies Record<string, Uebersetzungen>;

export type TextSchluessel = keyof typeof TEXTE;

/** Text in `sprache` mit eingesetzten Platzhaltern. */
export function t(sprache: Sprache, schluessel: TextSchluessel, werte: Record<string, string | number> = {}): string {
  const vorlage: string = TEXTE[schluessel][sprache] ?? TEXTE[schluessel].de;
  return vorlage.replace(/\{([a-zA-Z_]+)\}/g, (ganz, name: string) =>
    name in werte ? String(werte[name]) : ganz,
  );
}

/** Menschliche Dauer („in 15 Minuten“, „in 2 Tagen“) für Minuten vor Start. */
export function dauerText(sprache: Sprache, minuten: number): string {
  if (minuten <= 0) return '';
  if (minuten % (7 * 24 * 60) === 0) {
    const n = minuten / (7 * 24 * 60);
    return n === 1 ? t(sprache, 'dauer.woche') : t(sprache, 'dauer.wochen', { n });
  }
  if (minuten % (24 * 60) === 0) {
    const n = minuten / (24 * 60);
    return n === 1 ? t(sprache, 'dauer.tag') : t(sprache, 'dauer.tage', { n });
  }
  if (minuten % 60 === 0) {
    const n = minuten / 60;
    return n === 1 ? t(sprache, 'dauer.stunde') : t(sprache, 'dauer.stunden', { n });
  }
  return minuten === 1 ? t(sprache, 'dauer.minute') : t(sprache, 'dauer.minuten', { n: minuten });
}

const LOCALE: Record<Sprache, string> = { de: 'de-AT', en: 'en-GB' };

/** Datum mit Wochentag in der Zeitzone, z. B. „Mo., 16. März 2026“. */
export function datumText(sprache: Sprache, zeitpunkt: Date, zeitzone: string): string {
  return new Intl.DateTimeFormat(LOCALE[sprache], {
    timeZone: zeitzone,
    weekday: 'short',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(zeitpunkt);
}

/** Kurzes Datum ohne Jahr, z. B. „16. März“. */
export function datumKurz(sprache: Sprache, zeitpunkt: Date, zeitzone: string): string {
  return new Intl.DateTimeFormat(LOCALE[sprache], { timeZone: zeitzone, day: 'numeric', month: 'long' }).format(zeitpunkt);
}

/** Monat mit Jahr, z. B. „Juni 2026“. */
export function monatText(sprache: Sprache, zeitpunkt: Date, zeitzone: string): string {
  return new Intl.DateTimeFormat(LOCALE[sprache], { timeZone: zeitzone, month: 'long', year: 'numeric' }).format(zeitpunkt);
}

/** Lokaler Tag 'JJJJ-MM-TT' kurz mit Wochentag, z. B. „Sa., 6. Juni“. */
export function tagText(sprache: Sprache, tag: string): string {
  const [j, m, t] = tag.split('-').map(Number);
  return new Intl.DateTimeFormat(LOCALE[sprache], { timeZone: 'UTC', weekday: 'short', day: 'numeric', month: 'long' }).format(
    new Date(Date.UTC(j, m - 1, t, 12)),
  );
}

/** Uhrzeit „06:00“. */
export function uhrzeitText(sprache: Sprache, zeitpunkt: Date, zeitzone: string): string {
  return new Intl.DateTimeFormat(LOCALE[sprache], {
    timeZone: zeitzone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).format(zeitpunkt);
}

/** Zeitspanne eines Vorkommens: „Mo., 16. März 2026, 06:00–07:30“ oder „…, ganztägig“. */
export function zeitspanneText(
  sprache: Sprache,
  start: Date,
  ende: Date,
  ganztaegig: boolean,
  zeitzone: string,
): string {
  const tag = datumText(sprache, start, zeitzone);
  if (ganztaegig) {
    // Ende ist exklusiv: letzter Tag = Ende minus 1 Tag.
    const letzter = new Date(ende.getTime() - 24 * 60 * 60 * 1000);
    const letzterTag = datumText(sprache, letzter, zeitzone);
    return letzterTag === tag || letzter.getTime() <= start.getTime()
      ? `${tag}, ${t(sprache, 'ganztaegig')}`
      : `${tag} – ${letzterTag}, ${t(sprache, 'ganztaegig')}`;
  }
  const von = uhrzeitText(sprache, start, zeitzone);
  const bis = uhrzeitText(sprache, ende, zeitzone);
  const gleicherTag = datumText(sprache, ende, zeitzone) === tag;
  if (ende.getTime() <= start.getTime()) return `${tag}, ${von}`;
  if (gleicherTag) return `${tag}, ${von}–${bis}`;
  return `${tag}, ${von} – ${datumText(sprache, ende, zeitzone)}, ${bis}`;
}

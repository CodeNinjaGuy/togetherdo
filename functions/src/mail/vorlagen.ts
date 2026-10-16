/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Gestaltete HTML-Mails (Markenfarbe #5B4BD6, warm, mobilfreundlich) mit
// Plaintext-Alternative. Alle Nutzerwerte werden im HTML maskiert. Die
// Fußzeile trägt Einstellungs- und Abmelde-Link; E-Mail-Adressen kommen in
// keiner Vorlage vor (der Empfänger steht nur im Umschlag).

import { Termin, Vorkommen } from '../termine_logik';
import { Monatsueberblick, Unterwegs } from '../monatsueberblick_logik';
import { Sprache, t, dauerText, zeitspanneText, datumText, datumKurz, uhrzeitText, monatText, tagText } from './texte';

export const MARKE = '#5B4BD6';
const MARKE_DUNKEL = '#4838B8';
const HINTERGRUND = '#F6F3EE';
const KARTE = '#FFFFFF';
const TEXT = '#2A2633';
const TEXT_LEISE = '#6E6880';
const LINIE = '#ECE7F5';
const AKZENT_HELL = '#EFEBFF';

export interface Vorlage {
  betreff: string;
  html: string;
  text: string;
}

export interface FussLinks {
  einstellungen: string;
  /** Abmeldelink (Erinnerungen bzw. Wochenüberblick), optional. */
  abmelden?: { url: string; schluessel: 'fuss.abmelden' | 'fuss.wochenueberblick.abmelden' | 'fuss.monatsueberblick.abmelden' };
}

export function escapeHtml(wert: unknown): string {
  return String(wert ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

/** Anzeigename für die Anrede: kurz, ohne Steuerzeichen; leer = Anrede ohne Namen. */
export function anredeName(name: unknown): string {
  if (typeof name !== 'string') return '';
  // eslint-disable-next-line no-control-regex
  return name.replace(/[\u0000-\u001f\u007f<>]/g, '').trim().slice(0, 40);
}

function anrede(sprache: Sprache, name: string): string {
  return name ? t(sprache, 'anrede.name', { name }) : t(sprache, 'anrede.ohne');
}

interface Rahmen {
  sprache: Sprache;
  betreff: string;
  titel: string;
  /** kurzer Vorschautext (Posteingang) */
  vorschau: string;
  anredeName: string;
  /** Inhalt (bereits maskiertes HTML) */
  inhaltHtml: string;
  /** Inhalt als Klartext */
  inhaltText: string;
  fuss: FussLinks;
}

function fussHtml(sprache: Sprache, fuss: FussLinks): string {
  const links = [
    `<a href="${escapeHtml(fuss.einstellungen)}" style="color:${MARKE};text-decoration:none;">${escapeHtml(t(sprache, 'fuss.einstellungen'))}</a>`,
  ];
  if (fuss.abmelden) {
    links.push(
      `<a href="${escapeHtml(fuss.abmelden.url)}" style="color:${MARKE};text-decoration:none;">${escapeHtml(t(sprache, fuss.abmelden.schluessel))}</a>`,
    );
  }
  return `${escapeHtml(t(sprache, 'fuss.automatisch'))}<br>
${escapeHtml(t(sprache, 'fuss.hinweis.app'))}<br><br>
${links.join(' &middot; ')}<br><br>
&copy; ${new Date().getUTCFullYear()} SeeBubble Media FlexCo`;
}

function fussText(sprache: Sprache, fuss: FussLinks): string {
  const zeilen = [t(sprache, 'fuss.automatisch'), t(sprache, 'fuss.hinweis.app'), '', `${t(sprache, 'fuss.einstellungen')}: ${fuss.einstellungen}`];
  if (fuss.abmelden) zeilen.push(`${t(sprache, fuss.abmelden.schluessel)}: ${fuss.abmelden.url}`);
  zeilen.push('', `© ${new Date().getUTCFullYear()} SeeBubble Media FlexCo`);
  return zeilen.join('\n');
}

/** Gemeinsamer Rahmen aller Mails. */
export function rahmen(r: Rahmen): Vorlage {
  const e = escapeHtml;
  const html = `<!DOCTYPE html>
<html lang="${r.sprache}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="color-scheme" content="light">
<title>${e(r.betreff)}</title>
</head>
<body style="margin:0;padding:0;background-color:${HINTERGRUND};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:${TEXT};">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">${e(r.vorschau)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${HINTERGRUND};padding:28px 12px;">
<tr><td align="center">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;background-color:${KARTE};border-radius:20px;overflow:hidden;box-shadow:0 6px 24px rgba(91,75,214,0.12);">
<tr><td align="center" style="background-color:${MARKE};background-image:linear-gradient(135deg,${MARKE} 0%,${MARKE_DUNKEL} 100%);padding:30px 24px 26px;">
<div style="font-size:13px;letter-spacing:2px;text-transform:uppercase;font-weight:700;color:rgba(255,255,255,0.8);margin-bottom:8px;">ToGetherDo</div>
<div style="font-size:24px;line-height:1.3;font-weight:800;color:#ffffff;">${e(r.titel)}</div>
</td></tr>
<tr><td style="padding:28px 28px 8px;font-size:16px;line-height:1.6;color:${TEXT};">
<p style="margin:0 0 16px;">${e(anrede(r.sprache, r.anredeName))}</p>
${r.inhaltHtml}
<p style="margin:24px 0 20px;font-weight:600;">${e(t(r.sprache, 'gruss'))}</p>
</td></tr>
<tr><td style="padding:18px 28px 24px;background-color:#FBFAF7;border-top:1px solid ${LINIE};font-size:12px;line-height:1.6;color:${TEXT_LEISE};text-align:center;">
${fussHtml(r.sprache, r.fuss)}
</td></tr>
</table>
</td></tr>
</table>
</body>
</html>`;
  const text = [r.titel, '', anrede(r.sprache, r.anredeName), '', r.inhaltText, '', t(r.sprache, 'gruss'), '', '--', fussText(r.sprache, r.fuss)].join('\n');
  return { betreff: r.betreff, html, text };
}

// ---------------------------------------------------------------- Bausteine

function zeile(bezeichnung: string, wert: string): string {
  return `<tr>
<td style="padding:6px 12px 6px 0;font-size:13px;font-weight:700;color:${TEXT_LEISE};white-space:nowrap;vertical-align:top;">${escapeHtml(bezeichnung)}</td>
<td style="padding:6px 0;font-size:15px;color:${TEXT};vertical-align:top;">${escapeHtml(wert)}</td>
</tr>`;
}

function karte(inhalt: string): string {
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${AKZENT_HELL};border-radius:14px;margin:0 0 20px;">
<tr><td style="padding:16px 18px;">
<table role="presentation" cellpadding="0" cellspacing="0" border="0">${inhalt}</table>
</td></tr></table>`;
}

function hinweis(text: string): string {
  return `<p style="margin:0 0 12px;font-size:14px;color:${TEXT_LEISE};">${escapeHtml(text)}</p>`;
}

// --------------------------------------------------------------- Erinnerung

export interface ErinnerungsMailDaten {
  sprache: Sprache;
  empfaengerName: string;
  termin: Termin;
  vorkommen: Vorkommen;
  minuten: number;
  listenName: string;
  personenNamen: string[];
  fuss: FussLinks;
}

export function erinnerungsMail(d: ErinnerungsMailDaten): Vorlage {
  const { sprache, termin } = d;
  const zeit = zeitspanneText(sprache, d.vorkommen.start, d.vorkommen.ende, termin.ganztaegig, termin.zeitzone);
  const kurzzeit = termin.ganztaegig
    ? datumKurz(sprache, d.vorkommen.start, termin.zeitzone)
    : `${datumKurz(sprache, d.vorkommen.start, termin.zeitzone)}, ${uhrzeitText(sprache, d.vorkommen.start, termin.zeitzone)}`;
  const betreff = t(sprache, 'erinnerung.betreff', { titel: termin.titel, zeit: kurzzeit });
  const einleitung = d.minuten <= 0 ? t(sprache, 'erinnerung.jetzt') : t(sprache, 'erinnerung.in', { dauer: dauerText(sprache, d.minuten) });
  const wer = d.personenNamen.length > 0 ? d.personenNamen.join(', ') : t(sprache, 'feld.alle');

  const felder: [string, string][] = [
    [t(sprache, 'feld.wann'), zeit],
    ...(termin.ort ? [[t(sprache, 'feld.wo'), termin.ort] as [string, string]] : []),
    [t(sprache, 'feld.wer'), wer],
    [t(sprache, 'feld.liste'), d.listenName],
    ...(termin.notiz ? [[t(sprache, 'feld.notiz'), termin.notiz] as [string, string]] : []),
  ];

  const inhaltHtml = `<p style="margin:0 0 18px;">${escapeHtml(einleitung)}</p>
<div style="font-size:20px;font-weight:800;color:${MARKE};margin:0 0 12px;">${escapeHtml(termin.titel)}</div>
${karte(felder.map(([b, w]) => zeile(b, w)).join('\n'))}
<div style="font-size:15px;font-weight:700;color:${TEXT};margin:0 0 4px;">&#128197; ${escapeHtml(t(sprache, 'erinnerung.ics'))}</div>
${hinweis(t(sprache, 'erinnerung.ics.hinweis'))}`;

  const inhaltText = [einleitung, '', termin.titel, ...felder.map(([b, w]) => `${b}: ${w}`), '', `${t(sprache, 'erinnerung.ics')}: ${t(sprache, 'erinnerung.ics.hinweis')}`].join('\n');

  return rahmen({
    sprache,
    betreff,
    titel: t(sprache, 'erinnerung.titel'),
    vorschau: `${termin.titel} – ${zeit}`,
    anredeName: d.empfaengerName,
    inhaltHtml,
    inhaltText,
    fuss: d.fuss,
  });
}

// ---------------------------------------------------------- Wochenüberblick

export interface WochenEintrag {
  termin: Termin;
  vorkommen: Vorkommen;
  listenName: string;
  personenNamen: string[];
}

export interface WochenMailDaten {
  sprache: Sprache;
  empfaengerName: string;
  zeitzone: string;
  wochenStart: Date;
  /** exklusiv */
  wochenEnde: Date;
  eintraege: WochenEintrag[];
  fuss: FussLinks;
}

export function wochenueberblickMail(d: WochenMailDaten): Vorlage {
  const { sprache, zeitzone } = d;
  const letzterTag = new Date(d.wochenEnde.getTime() - 24 * 60 * 60 * 1000);
  const betreff = t(sprache, 'woche.betreff', {
    von: datumKurz(sprache, d.wochenStart, zeitzone),
    bis: datumKurz(sprache, letzterTag, zeitzone),
  });
  const sortiert = [...d.eintraege].sort((a, b) => a.vorkommen.start.getTime() - b.vorkommen.start.getTime());

  // Nach lokalem Tag gruppieren.
  const tage = new Map<string, WochenEintrag[]>();
  for (const e of sortiert) {
    const schluessel = datumText(sprache, e.vorkommen.start, zeitzone);
    const liste = tage.get(schluessel) ?? [];
    liste.push(e);
    tage.set(schluessel, liste);
  }

  const anzahlText = sortiert.length === 1 ? t(sprache, 'woche.einer') : t(sprache, 'woche.anzahl', { n: sortiert.length });
  const htmlTage: string[] = [];
  const textTage: string[] = [];
  for (const [tag, eintraege] of tage) {
    const zeilen = eintraege.map((e) => {
      const zeit = e.termin.ganztaegig ? t(sprache, 'ganztaegig') : uhrzeitText(sprache, e.vorkommen.start, zeitzone);
      const wer = e.personenNamen.length > 0 ? e.personenNamen.join(', ') : t(sprache, 'feld.alle');
      const zusatz = [wer, e.termin.ort ?? '', e.listenName].filter(Boolean).join(' · ');
      return {
        html: `<tr>
<td style="padding:8px 12px 8px 0;font-size:13px;font-weight:700;color:${MARKE};white-space:nowrap;vertical-align:top;">${escapeHtml(zeit)}</td>
<td style="padding:8px 0;vertical-align:top;"><div style="font-size:15px;font-weight:600;color:${TEXT};">${escapeHtml(e.termin.titel)}</div><div style="font-size:13px;color:${TEXT_LEISE};">${escapeHtml(zusatz)}</div></td>
</tr>`,
        text: `  ${zeit.padEnd(9)} ${e.termin.titel} (${zusatz})`,
      };
    });
    htmlTage.push(`<div style="font-size:14px;font-weight:800;text-transform:uppercase;letter-spacing:1px;color:${TEXT_LEISE};margin:18px 0 4px;">${escapeHtml(tag)}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top:1px solid ${LINIE};">${zeilen.map((z) => z.html).join('\n')}</table>`);
    textTage.push(tag, ...zeilen.map((z) => z.text), '');
  }

  const leer = sortiert.length === 0;
  const inhaltHtml = leer
    ? `<p style="margin:0 0 16px;">${escapeHtml(t(sprache, 'woche.keine'))}</p>`
    : `<p style="margin:0 0 6px;">${escapeHtml(t(sprache, 'woche.einleitung'))}</p>
<p style="margin:0 0 8px;font-size:13px;color:${TEXT_LEISE};">${escapeHtml(anzahlText)}</p>
${htmlTage.join('\n')}`;
  const inhaltText = leer ? t(sprache, 'woche.keine') : [t(sprache, 'woche.einleitung'), anzahlText, '', ...textTage].join('\n');

  return rahmen({
    sprache,
    betreff,
    titel: t(sprache, 'woche.titel'),
    vorschau: leer ? t(sprache, 'woche.keine') : anzahlText,
    anredeName: d.empfaengerName,
    inhaltHtml,
    inhaltText,
    fuss: d.fuss,
  });
}

// ---------------------------------------------------------- Monatsüberblick

export interface MonatsMailDaten {
  sprache: Sprache;
  empfaengerName: string;
  zeitzone: string;
  monatsStart: Date;
  ueberblick: Monatsueberblick;
  fuss: FussLinks;
}

function abschnitt(titel: string, hinweisText: string | null, inhaltHtml: string): string {
  return `<div style="font-size:14px;font-weight:800;text-transform:uppercase;letter-spacing:1px;color:${TEXT_LEISE};margin:22px 0 4px;">${escapeHtml(titel)}</div>
${hinweisText ? hinweis(hinweisText) : ''}
${inhaltHtml}`;
}

function listeHtml(eintraege: { kopf: string; haupt: string; zusatz: string }[]): string {
  const zeilen = eintraege.map(
    (z) => `<tr>
<td style="padding:8px 12px 8px 0;font-size:13px;font-weight:700;color:${MARKE};white-space:nowrap;vertical-align:top;">${escapeHtml(z.kopf)}</td>
<td style="padding:8px 0;vertical-align:top;"><div style="font-size:15px;font-weight:600;color:${TEXT};">${escapeHtml(z.haupt)}</div>${
      z.zusatz ? `<div style="font-size:13px;color:${TEXT_LEISE};">${escapeHtml(z.zusatz)}</div>` : ''
    }</td>
</tr>`,
  );
  return `<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="border-top:1px solid ${LINIE};">${zeilen.join('\n')}</table>`;
}

function unterwegsText(sprache: Sprache, u: Unterwegs): string {
  const teile: string[] = [];
  if (u.urlaubstage > 0) teile.push(u.urlaubstage === 1 ? t(sprache, 'monat.unterwegs.urlaubstag') : t(sprache, 'monat.unterwegs.urlaubstage', { n: u.urlaubstage }));
  if (u.arbeitstage > 0) {
    const tage = u.arbeitstage === 1 ? t(sprache, 'monat.unterwegs.arbeitstag') : t(sprache, 'monat.unterwegs.arbeitstage', { n: u.arbeitstage });
    teile.push(u.arbeitsstunden > 0 ? `${tage} (${t(sprache, 'monat.unterwegs.stunden', { n: u.arbeitsstunden })})` : tage);
  }
  if (u.termine > 0) teile.push(u.termine === 1 ? t(sprache, 'monat.unterwegs.termin') : t(sprache, 'monat.unterwegs.termine', { n: u.termine }));
  return teile.length > 0 ? teile.join(' · ') : t(sprache, 'monat.unterwegs.nichts');
}

function zeitraumText(sprache: Sprache, vonTag: string, bisTag: string): string {
  return vonTag === bisTag ? tagText(sprache, vonTag) : `${tagText(sprache, vonTag)} – ${tagText(sprache, bisTag)}`;
}

export function monatsueberblickMail(d: MonatsMailDaten): Vorlage {
  const { sprache, ueberblick: u } = d;
  const monat = monatText(sprache, d.monatsStart, d.zeitzone);
  const betreff = t(sprache, 'monat.betreff', { monat });
  const leer = u.anzahlVorkommen === 0;

  const highlights = u.highlights.map((h) => {
    const wer = h.personenNamen.length > 0 ? h.personenNamen.join(', ') : t(sprache, 'feld.alle');
    const artText = t(sprache, `art.${h.art}` as 'art.urlaub' | 'art.geburtstag' | 'art.arzt' | 'art.mehrtaegig');
    return {
      kopf: zeitraumText(sprache, h.vonTag, h.bisTag),
      haupt: h.termin.titel,
      zusatz: [artText, wer, h.listenName].filter(Boolean).join(' · '),
    };
  });
  const wochenenden = u.freieWochenenden.map((w) => ({ kopf: zeitraumText(sprache, w.samstag, w.sonntag), haupt: '', zusatz: '' }));
  const alleFrei = u.alleFrei.map((a) => ({ kopf: zeitraumText(sprache, a.vonTag, a.bisTag), haupt: a.listenName, zusatz: '' }));
  const unterwegs = u.unterwegs.map((p) => ({ kopf: p.name || '–', haupt: unterwegsText(sprache, p), zusatz: '' }));

  const leerHtml = (schluessel: 'monat.highlights.keine' | 'monat.wochenenden.keine' | 'monat.allefrei.keine') =>
    `<p style="margin:0;font-size:14px;color:${TEXT_LEISE};">${escapeHtml(t(sprache, schluessel))}</p>`;

  const inhaltHtml = leer
    ? `<p style="margin:0 0 16px;">${escapeHtml(t(sprache, 'monat.keine'))}</p>`
    : `<p style="margin:0 0 6px;">${escapeHtml(t(sprache, 'monat.einleitung', { monat }))}</p>
${abschnitt(t(sprache, 'monat.highlights'), null, highlights.length > 0 ? listeHtml(highlights) : leerHtml('monat.highlights.keine'))}
${abschnitt(t(sprache, 'monat.wochenenden'), t(sprache, 'monat.wochenenden.hinweis'), wochenenden.length > 0 ? listeHtml(wochenenden) : leerHtml('monat.wochenenden.keine'))}
${abschnitt(t(sprache, 'monat.allefrei'), t(sprache, 'monat.allefrei.hinweis'), alleFrei.length > 0 ? listeHtml(alleFrei) : leerHtml('monat.allefrei.keine'))}
${abschnitt(t(sprache, 'monat.unterwegs'), null, listeHtml(unterwegs))}`;

  const textListe = (eintraege: { kopf: string; haupt: string; zusatz: string }[], leerText: string) =>
    eintraege.length > 0 ? eintraege.map((z) => `  ${[z.kopf, z.haupt, z.zusatz ? `(${z.zusatz})` : ''].filter(Boolean).join('  ')}`) : [`  ${leerText}`];
  const inhaltText = leer
    ? t(sprache, 'monat.keine')
    : [
        t(sprache, 'monat.einleitung', { monat }),
        '',
        t(sprache, 'monat.highlights').toUpperCase(),
        ...textListe(highlights, t(sprache, 'monat.highlights.keine')),
        '',
        t(sprache, 'monat.wochenenden').toUpperCase(),
        t(sprache, 'monat.wochenenden.hinweis'),
        ...textListe(wochenenden, t(sprache, 'monat.wochenenden.keine')),
        '',
        t(sprache, 'monat.allefrei').toUpperCase(),
        t(sprache, 'monat.allefrei.hinweis'),
        ...textListe(alleFrei, t(sprache, 'monat.allefrei.keine')),
        '',
        t(sprache, 'monat.unterwegs').toUpperCase(),
        ...textListe(unterwegs, ''),
      ].join('\n');

  return rahmen({
    sprache,
    betreff,
    titel: t(sprache, 'monat.titel'),
    vorschau: leer ? t(sprache, 'monat.keine') : t(sprache, 'monat.einleitung', { monat }),
    anredeName: d.empfaengerName,
    inhaltHtml,
    inhaltText,
    fuss: d.fuss,
  });
}

// ---------------------------------------------------------------- Einladung

export interface EinladungsMailDaten {
  sprache: Sprache;
  einladerName: string;
  listenName: string;
  shareCode: string;
  fuss: FussLinks;
}

export function einladungsMail(d: EinladungsMailDaten): Vorlage {
  const { sprache } = d;
  const werte = { name: d.einladerName, liste: d.listenName };
  const betreff = t(sprache, 'einladung.betreff', werte);
  const inhaltHtml = `<p style="margin:0 0 20px;">${escapeHtml(t(sprache, 'einladung.text', werte))}</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background-color:${AKZENT_HELL};border-radius:14px;margin:0 0 20px;">
<tr><td align="center" style="padding:18px;">
<div style="font-size:13px;font-weight:700;letter-spacing:1px;text-transform:uppercase;color:${TEXT_LEISE};margin-bottom:6px;">${escapeHtml(t(sprache, 'einladung.code'))}</div>
<div style="font-size:34px;font-weight:800;letter-spacing:6px;color:${MARKE};font-family:'SF Mono',Menlo,Consolas,monospace;">${escapeHtml(d.shareCode)}</div>
</td></tr></table>
<p style="margin:0 0 12px;">${escapeHtml(t(sprache, 'einladung.schritte'))}</p>
${hinweis(t(sprache, 'einladung.app'))}
${hinweis(t(sprache, 'einladung.unerwartet', werte))}`;
  const inhaltText = [
    t(sprache, 'einladung.text', werte),
    '',
    `${t(sprache, 'einladung.code')}: ${d.shareCode}`,
    '',
    t(sprache, 'einladung.schritte'),
    t(sprache, 'einladung.app'),
    t(sprache, 'einladung.unerwartet', werte),
  ].join('\n');
  return rahmen({
    sprache,
    betreff,
    titel: t(sprache, 'einladung.titel'),
    vorschau: t(sprache, 'einladung.text', werte),
    anredeName: '',
    inhaltHtml,
    inhaltText,
    fuss: d.fuss,
  });
}

// ------------------------------------------------------- Einstellungsseite

/** Kleine Bestätigungsseite (de/en) für den Abmelde-Link. */
export function einstellungsSeite(sprache: Sprache, nachricht: string, erfolg: boolean): string {
  const e = escapeHtml;
  return `<!DOCTYPE html>
<html lang="${sprache}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<meta name="robots" content="noindex">
<title>${e(t(sprache, 'seite.titel'))} – ToGetherDo</title>
<style>
body{margin:0;background:${HINTERGRUND};font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;color:${TEXT};}
main{max-width:480px;margin:48px auto;padding:0 16px;}
.karte{background:${KARTE};border-radius:20px;box-shadow:0 6px 24px rgba(91,75,214,0.12);overflow:hidden;}
.kopf{background:linear-gradient(135deg,${MARKE},${MARKE_DUNKEL});color:#fff;padding:28px 24px;}
.kopf small{display:block;letter-spacing:2px;text-transform:uppercase;font-weight:700;opacity:.8;font-size:12px;margin-bottom:6px;}
.kopf h1{margin:0;font-size:22px;}
.inhalt{padding:24px;font-size:16px;line-height:1.6;}
.symbol{font-size:40px;line-height:1;margin-bottom:12px;}
.leise{color:${TEXT_LEISE};font-size:14px;}
</style>
</head>
<body>
<main>
<div class="karte">
<div class="kopf"><small>ToGetherDo</small><h1>${e(t(sprache, 'seite.titel'))}</h1></div>
<div class="inhalt">
<div class="symbol">${erfolg ? '&#10003;' : '&#9888;'}</div>
<p>${e(nachricht)}</p>
<p class="leise">${e(t(sprache, 'seite.zurueck'))}</p>
</div>
</div>
</main>
</body>
</html>`;
}

/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Zeitzonen-Hilfen des Kalenders. Alle Zeitpunkte liegen intern als UTC
/// vor; Wanduhrzeiten (6:00 Frühschicht) werden über `timezone` in der
/// Zeitzone des Termins berechnet, damit die Sommerzeit stimmt.
library;

import 'package:timezone/data/latest_10y.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

bool _initialisiert = false;

/// Lädt die Zeitzonen-Datenbank (einmalig, ohne Netz).
void kalenderZeitInit() {
  if (_initialisiert) return;
  tzdata.initializeTimeZones();
  _initialisiert = true;
}

/// Zeitzone des Geräts als IANA-Name, soweit bekannt; sonst Europe/Vienna.
String standardZeitzone() {
  kalenderZeitInit();
  final name = DateTime.now().timeZoneName;
  // Dart liefert Kürzel (CET/CEST), keine IANA-Namen. Bekannte Kürzel des
  // Zielmarkts abbilden, sonst Europe/Vienna.
  const bekannt = {
    'CET': 'Europe/Vienna',
    'CEST': 'Europe/Vienna',
    'GMT': 'Europe/London',
    'BST': 'Europe/London',
    'EET': 'Europe/Athens',
    'EEST': 'Europe/Athens',
    'WET': 'Europe/Lisbon',
    'WEST': 'Europe/Lisbon',
  };
  if (bekannt.containsKey(name)) return bekannt[name]!;
  if (tz.timeZoneDatabase.locations.containsKey(name)) return name;
  return 'Europe/Vienna';
}

tz.Location ort(String zeitzone) {
  kalenderZeitInit();
  try {
    return tz.getLocation(zeitzone);
  } catch (_) {
    return tz.getLocation('Europe/Vienna');
  }
}

/// UTC-Zeitpunkt → Wanduhrzeit in `zeitzone`.
tz.TZDateTime lokal(DateTime utc, String zeitzone) =>
    tz.TZDateTime.from(utc.toUtc(), ort(zeitzone));

/// Wanduhrzeit in `zeitzone` → UTC-Zeitpunkt.
DateTime utcVon(
  String zeitzone,
  int jahr,
  int monat,
  int tag, [
  int stunde = 0,
  int minute = 0,
]) => reinUtc(tz.TZDateTime(ort(zeitzone), jahr, monat, tag, stunde, minute));

/// `TZDateTime` → gewöhnliche UTC-`DateTime` (gleiche Vergleichbarkeit überall).
DateTime reinUtc(DateTime d) =>
    DateTime.fromMicrosecondsSinceEpoch(d.microsecondsSinceEpoch, isUtc: true);

/// Mitternacht (lokal) des Tages, in dem `utc` liegt, als UTC.
DateTime tagesanfang(DateTime utc, String zeitzone) {
  final l = lokal(utc, zeitzone);
  return utcVon(zeitzone, l.year, l.month, l.day);
}

/// Mitternacht des Folgetags (lokal) als UTC.
DateTime tagesende(DateTime utc, String zeitzone) {
  final l = lokal(utc, zeitzone);
  return utcVon(zeitzone, l.year, l.month, l.day + 1);
}

/// Kalendertag `JJJJ-MM-TT` eines Zeitpunkts in `zeitzone`.
String tagSchluessel(DateTime utc, String zeitzone) {
  final l = lokal(utc, zeitzone);
  return tagSchluesselVon(l.year, l.month, l.day);
}

String tagSchluesselVon(int jahr, int monat, int tag) =>
    '${jahr.toString().padLeft(4, '0')}-'
    '${monat.toString().padLeft(2, '0')}-'
    '${tag.toString().padLeft(2, '0')}';

/// Reiner Kalendertag ohne Zeitzone (für Vergleiche von Tagen).
DateTime nurTag(DateTime d) => DateTime.utc(d.year, d.month, d.day);

int tageZwischen(DateTime a, DateTime b) =>
    nurTag(b).difference(nurTag(a)).inDays;

/// Montag der Woche, in der `tag` liegt (reiner Tag).
DateTime wochenanfang(DateTime tag) =>
    nurTag(tag).subtract(Duration(days: tag.weekday - 1));

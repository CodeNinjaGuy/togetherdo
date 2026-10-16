/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// iCalendar-Export (RFC 5545) eines Termins, z. B. zum Teilen als .ics.
/// Zeiten in UTC, Wiederholungen als RRULE, Ausnahmen als EXDATE.
library;

import '../models/termin.dart';
import 'zeit.dart';

String _utc(DateTime d) {
  final u = d.toUtc();
  String p(int n) => n.toString().padLeft(2, '0');
  return '${u.year}${p(u.month)}${p(u.day)}T${p(u.hour)}${p(u.minute)}${p(u.second)}Z';
}

String _tag(DateTime d, String zeitzone) =>
    tagSchluessel(d, zeitzone).replaceAll('-', '');

String _escape(String s) => s
    .replaceAll('\\', '\\\\')
    .replaceAll(';', '\\;')
    .replaceAll(',', '\\,')
    .replaceAll('\r\n', '\\n')
    .replaceAll('\n', '\\n');

/// Zeilen länger als 75 Oktette falten (RFC 5545 3.1).
String _falten(String zeile) {
  final bytes = zeile.codeUnits;
  if (bytes.length <= 75) return zeile;
  final buf = StringBuffer();
  var i = 0;
  var erste = true;
  while (i < zeile.length) {
    final max = erste ? 75 : 74;
    final ende = (i + max).clamp(0, zeile.length);
    if (!erste) buf.write('\r\n ');
    buf.write(zeile.substring(i, ende));
    i = ende;
    erste = false;
  }
  return buf.toString();
}

const _wochentage = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];

String? _rrule(Termin t) {
  final w = t.wiederholung;
  if (w == null) return null;
  final teile = <String>[];
  switch (w.typ) {
    case WiederholungTyp.taeglich:
      teile.add('FREQ=DAILY');
    case WiederholungTyp.woechentlich:
      teile.add('FREQ=WEEKLY');
      if (w.wochentage.isNotEmpty) {
        final tage = (w.wochentage.toSet().toList()..sort())
            .map((d) => _wochentage[d - 1])
            .join(',');
        teile.add('BYDAY=$tage');
      }
    case WiederholungTyp.monatlich:
      teile.add('FREQ=MONTHLY');
    case WiederholungTyp.jaehrlich:
      teile.add('FREQ=YEARLY');
  }
  if (w.intervall > 1) teile.add('INTERVAL=${w.intervall}');
  if (w.anzahl != null) {
    teile.add('COUNT=${w.anzahl}');
  } else if (w.bisDatum != null) {
    // UNTIL einschließlich: Ende des Tages in der Zeitzone.
    teile.add('UNTIL=${_utc(tagesende(w.bisDatum!, t.zeitzone).subtract(const Duration(seconds: 1)))}');
  }
  return teile.join(';');
}

/// Vollständiger VCALENDAR-Text für einen Termin (Serie inklusive).
String terminAlsIcs(Termin t, {String produkt = '-//SeeBubble Media//ToGetherDo//DE'}) {
  final zeilen = <String>[
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:$produkt',
    'CALSCALE:GREGORIAN',
    'METHOD:PUBLISH',
    'BEGIN:VEVENT',
    'UID:${t.id}@togetherdo.app',
    'DTSTAMP:${_utc(t.aktualisiertAm ?? t.erstelltAm ?? DateTime.now())}',
    'SUMMARY:${_escape(t.titel)}',
  ];
  if (t.ganztaegig) {
    zeilen.add('DTSTART;VALUE=DATE:${_tag(t.start, t.zeitzone)}');
    zeilen.add('DTEND;VALUE=DATE:${_tag(t.ende, t.zeitzone)}');
  } else {
    zeilen.add('DTSTART:${_utc(t.start)}');
    zeilen.add('DTEND:${_utc(t.ende)}');
  }
  final rrule = _rrule(t);
  if (rrule != null) zeilen.add('RRULE:$rrule');
  final ausnahmen = t.wiederholung?.ausnahmen ?? const [];
  if (ausnahmen.isNotEmpty) {
    if (t.ganztaegig) {
      zeilen.add(
        'EXDATE;VALUE=DATE:${ausnahmen.map((a) => a.replaceAll('-', '')).join(',')}',
      );
    } else {
      final l = lokal(t.start, t.zeitzone);
      final liste = ausnahmen.map((a) {
        final p = a.split('-').map(int.parse).toList();
        return _utc(utcVon(t.zeitzone, p[0], p[1], p[2], l.hour, l.minute));
      }).join(',');
      zeilen.add('EXDATE:$liste');
    }
  }
  if ((t.ort ?? '').isNotEmpty) zeilen.add('LOCATION:${_escape(t.ort!)}');
  if ((t.notiz ?? '').isNotEmpty) zeilen.add('DESCRIPTION:${_escape(t.notiz!)}');
  zeilen.add('CATEGORIES:${t.art.wert.toUpperCase()}');
  for (final m in t.erinnerungen) {
    zeilen.addAll([
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'DESCRIPTION:${_escape(t.titel)}',
      'TRIGGER:-PT${m}M',
      'END:VALARM',
    ]);
  }
  zeilen.addAll(['END:VEVENT', 'END:VCALENDAR']);
  return '${zeilen.map(_falten).join('\r\n')}\r\n';
}

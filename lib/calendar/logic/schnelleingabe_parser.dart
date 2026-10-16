/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Zerlegt eine Schnelleingabe wie „Zahnarzt Anna Dienstag 15 Uhr“ in Titel,
/// Art, Personen, Zeitraum und Wiederholung. Reine Dart-Logik ohne Flutter,
/// damit sie sich gut testen lässt.
///
/// Deutsch und Englisch kennen Wochentage, Monate, Uhrzeiten, Dauern und
/// Wiederholungen; andere Sprachen fallen auf die englischen Regeln zurück.
/// Die Erkennung läuft in fester Reihenfolge über den Text (Datumsbereiche,
/// Einzeldaten, Wochentagsbereiche, Wiederholungen, relative Tage, Uhrzeiten,
/// Dauer, Personen) und streicht erkannte Teile aus dem Titel.
library;

import '../models/termin.dart';

/// Ergebnis der Schnelleingabe. Alle Zeiten sind lokale Zeiten
/// (kein UTC), der Aufrufer rechnet sie in die Zeitzone des Termins um.
class SchnelleingabeErgebnis {
  const SchnelleingabeErgebnis({
    required this.titel,
    this.art,
    this.personenNamen = const [],
    this.start,
    this.ende,
    this.ganztaegig = true,
    this.wiederholung,
    this.unbekannt = const [],
    this.alle = false,
  });

  /// Rest-Text ohne erkannte Teile; leer → Aufrufer nimmt einen Standard.
  final String titel;

  /// Aus Stichwörtern erkannte Art, sonst null.
  final TerminArt? art;

  /// Erkannte Anzeigenamen aus der Mitgliederliste (so geschrieben wie dort).
  final List<String> personenNamen;

  /// Beginn (lokal), null wenn weder Datum noch Uhrzeit erkannt wurde.
  final DateTime? start;

  /// Ende (lokal, exklusiv). Ganztägig: 0:00 des Folgetags.
  final DateTime? ende;

  /// true, wenn keine Uhrzeit erkannt wurde.
  final bool ganztaegig;

  final Wiederholung? wiederholung;

  /// Wörter, die wie Namen aussehen, aber nicht in der Mitgliederliste stehen.
  final List<String> unbekannt;

  /// „alle“ / „everyone“ erkannt: Termin für alle Mitglieder.
  final bool alle;

  @override
  String toString() =>
      'SchnelleingabeErgebnis(titel: $titel, art: $art, personen: '
      '$personenNamen, start: $start, ende: $ende, ganztaegig: $ganztaegig, '
      'wiederholung: $wiederholung, unbekannt: $unbekannt, alle: $alle)';
}

/// Zerlegt [text] mit Bezugszeit [jetzt] (lokal). [mitglieder] sind die
/// Anzeigenamen der Listenmitglieder, [sprache] 'de' oder 'en'.
SchnelleingabeErgebnis zerlegeSchnelleingabe(
  String text, {
  required DateTime jetzt,
  required List<String> mitglieder,
  String sprache = 'de',
}) {
  final de = sprache.toLowerCase().startsWith('de');
  return _Zerleger(text, jetzt, mitglieder, de).zerlege();
}

// ---------------------------------------------------------------------------
// Wörterbücher
// ---------------------------------------------------------------------------

/// Wortgrenzen auch vor/nach Umlauten (das eingebaute `\b` kennt nur ASCII).
const String _wa = r'(?<![\p{L}\p{N}])';
const String _we = r'(?![\p{L}\p{N}])';

RegExp _re(String muster) =>
    RegExp(muster, caseSensitive: false, unicode: true);

/// Monatsname → Monat (deutsch und englisch gemischt, Kurzformen inklusive).
const Map<String, int> _monate = {
  'januar': 1,
  'jänner': 1,
  'jaenner': 1,
  'january': 1,
  'jan': 1,
  'februar': 2,
  'february': 2,
  'feb': 2,
  'märz': 3,
  'maerz': 3,
  'march': 3,
  'mär': 3,
  'mar': 3,
  'april': 4,
  'apr': 4,
  'mai': 5,
  'may': 5,
  'juni': 6,
  'june': 6,
  'jun': 6,
  'juli': 7,
  'july': 7,
  'jul': 7,
  'august': 8,
  'aug': 8,
  'september': 9,
  'sept': 9,
  'sep': 9,
  'oktober': 10,
  'october': 10,
  'okt': 10,
  'oct': 10,
  'november': 11,
  'nov': 11,
  'dezember': 12,
  'december': 12,
  'dez': 12,
  'dec': 12,
};

/// Volle Wochentagsnamen (de + en) → 1 = Montag … 7 = Sonntag.
const Map<String, int> _wochentageVoll = {
  'montag': 1,
  'monday': 1,
  'dienstag': 2,
  'tuesday': 2,
  'mittwoch': 3,
  'wednesday': 3,
  'donnerstag': 4,
  'thursday': 4,
  'freitag': 5,
  'friday': 5,
  'samstag': 6,
  'sonnabend': 6,
  'saturday': 6,
  'sonntag': 7,
  'sunday': 7,
};

/// Kurzformen je Sprache (getrennt, weil „so“/„do“ im Englischen Wörter sind).
const Map<String, int> _wochentageKurzDe = {
  'mo': 1,
  'di': 2,
  'mi': 3,
  'do': 4,
  'fr': 5,
  'sa': 6,
  'so': 7,
};
const Map<String, int> _wochentageKurzEn = {
  'mon': 1,
  'tue': 2,
  'tues': 2,
  'wed': 3,
  'thu': 4,
  'thur': 4,
  'thurs': 4,
  'fri': 5,
  'sat': 6,
  'sun': 7,
};

/// Kleine Zahlwörter für „in drei Tagen“, „alle zwei Wochen“, „for two hours“.
const Map<String, int> _zahlwoerter = {
  'ein': 1,
  'eine': 1,
  'einer': 1,
  'einen': 1,
  'einem': 1,
  'eins': 1,
  'a': 1,
  'an': 1,
  'one': 1,
  'zwei': 2,
  'two': 2,
  'other': 2,
  'second': 2,
  'zweiten': 2,
  'drei': 3,
  'three': 3,
  'third': 3,
  'dritten': 3,
  'vier': 4,
  'four': 4,
  'vierten': 4,
  'fünf': 5,
  'fuenf': 5,
  'five': 5,
  'sechs': 6,
  'six': 6,
  'sieben': 7,
  'seven': 7,
  'acht': 8,
  'eight': 8,
  'neun': 9,
  'nine': 9,
  'zehn': 10,
  'ten': 10,
  'vierzehn': 14,
  'fourteen': 14,
};

/// Füllwörter, die aus dem Titel fallen.
const Set<String> _fuellwoerterDe = {
  'am',
  'um',
  'bei',
  'mit',
  'für',
  'fuer',
  'der',
  'die',
  'das',
  'den',
  'dem',
  'im',
  'in',
  'an',
  'zu',
  'zum',
  'zur',
  'von',
  'vom',
  'bis',
  'ab',
  'uhr',
};
const Set<String> _fuellwoerterEn = {
  'at',
  'on',
  'the',
  'with',
  'for',
  'in',
  'to',
  'from',
  'a',
  'an',
  'of',
  'until',
  'till',
  'o\'clock',
};

/// Verbinder zwischen Namen („Anna und Lisa“), fallen nur dann weg, wenn
/// beide Nachbarn erkannt wurden oder fehlen.
const Set<String> _verbinder = {'und', 'and', '&', '+'};

/// Spitznamen, die auf eine Person deuten. Stehen sie nicht in der
/// Mitgliederliste, landen sie in `unbekannt`.
const Set<String> _spitznamen = {
  'oma',
  'omi',
  'opa',
  'opi',
  'papa',
  'papi',
  'mama',
  'mami',
  'mutti',
  'vati',
  'mutter',
  'vater',
  'tante',
  'onkel',
  'mom',
  'mum',
  'mommy',
  'mummy',
  'dad',
  'daddy',
  'grandma',
  'grandpa',
  'granny',
  'nana',
  'aunt',
  'uncle',
};

/// Art-Stichwörter in Prüfreihenfolge (Teilwort-Treffer, damit „Zahnarzt“,
/// „Frühschicht“ und „Kinderärztin“ gefunden werden).
final List<(TerminArt, RegExp)> _artMuster = [
  (TerminArt.arzt, _re(r'arzt|ärzt|aerzt|doctor|dentist|physio|therap|impf')),
  (TerminArt.geburtstag, _re(r'geburtstag|birthday|bday')),
  (TerminArt.urlaub, _re(r'urlaub|ferien|vacation|holiday')),
  (
    TerminArt.schule,
    _re(
      r'schule|kita|kindergarten|hort|elternabend|school|daycare|preschool'
      r'|nursery',
    ),
  ),
  (TerminArt.arbeit, _re(r'schicht|arbeit|^dienst(?!ag)|dienst$|^work|shift')),
];

// ---------------------------------------------------------------------------
// Zerleger
// ---------------------------------------------------------------------------

class _Zerleger {
  _Zerleger(String text, this.jetzt, this.mitglieder, this.de)
    : original = _normalisiere(text) {
    klein = _kleinGleichLang(original);
    verbraucht = List<bool>.filled(original.length, false);
  }

  final DateTime jetzt;
  final List<String> mitglieder;
  final bool de;
  final String original;
  late final String klein;
  late final List<bool> verbraucht;

  // Erkannte Teile
  DateTime? datum; // nur Tag
  DateTime? endDatum; // nur Tag (einschließlich)
  bool datumMitJahr = false;
  int? startMinuten; // Minuten seit 0:00
  int? endMinuten;
  Duration? dauer;
  int? tagesOffset; // heute = 0, morgen = 1 …
  bool naechsteWoche = false;
  bool wochenende = false;
  final List<int> wochentage = []; // Reihenfolge wie im Text
  WiederholungTyp? wiederholungTyp;
  int wiederholungIntervall = 1;
  List<int> wiederholungTage = [];
  bool vormittagsHinweis = false;
  bool nachmittagsHinweis = false;
  bool alle = false;
  final List<String> personen = [];

  static String _normalisiere(String t) => t
      .replaceAll(' ', ' ')
      .replaceAll(RegExp(r'[–—]'), '-')
      .replaceAll('’', '\'')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Kleinschreibung Zeichen für Zeichen, damit die Indizes gleich bleiben.
  static String _kleinGleichLang(String s) {
    final sb = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      final c = s[i];
      final k = c.toLowerCase();
      sb.write(k.length == 1 ? k : c);
    }
    return sb.toString();
  }

  String get _monatAlt => _alternation(_monate.keys);

  String get _zahlAlt => _alternation([
    ..._zahlwoerter.keys,
    'eineinhalb',
    'anderthalb',
    'halbe',
    'half',
  ]);

  String get _wochentagAlt => _alternation([
    ..._wochentageVoll.keys,
    ...(de ? _wochentageKurzDe : _wochentageKurzEn).keys,
  ]);

  static String _alternation(Iterable<String> woerter) {
    final sortiert = woerter.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    return '(?:${sortiert.join('|')})';
  }

  bool _frei(Match m) {
    for (var i = m.start; i < m.end; i++) {
      if (verbraucht[i]) return false;
    }
    return true;
  }

  void _verbrauche(Match m) {
    for (var i = m.start; i < m.end; i++) {
      verbraucht[i] = true;
    }
  }

  /// Alle freien Treffer von [muster]; [auswerten] gibt true zurück, wenn
  /// der Treffer gültig ist und verbraucht werden soll.
  void _suche(String muster, bool Function(RegExpMatch m) auswerten) {
    for (final m in _re(muster).allMatches(klein)) {
      if (!_frei(m)) continue;
      if (auswerten(m)) _verbrauche(m);
    }
  }

  int? _wochentag(String? wort) {
    if (wort == null) return null;
    final w = wort.toLowerCase().replaceAll('.', '');
    return _wochentageVoll[w] ??
        (de ? _wochentageKurzDe[w] : _wochentageKurzEn[w]);
  }

  int? _monat(String? wort) =>
      wort == null ? null : _monate[wort.toLowerCase()];

  int? _zahl(String? wort) {
    if (wort == null) return null;
    final w = wort.toLowerCase();
    return int.tryParse(w) ?? _zahlwoerter[w];
  }

  static int? _jahr(String? s) {
    if (s == null) return null;
    final j = int.tryParse(s);
    if (j == null) return null;
    return j < 100 ? 2000 + j : j;
  }

  static bool _gueltigerTag(int? tag, int? monat) =>
      tag != null &&
      monat != null &&
      tag >= 1 &&
      tag <= 31 &&
      monat >= 1 &&
      monat <= 12;

  // --- Ablauf ---------------------------------------------------------------

  SchnelleingabeErgebnis zerlege() {
    _erkenneDatumsbereich();
    _erkenneDatum();
    _erkenneWochentagsbereich();
    _erkenneWiederholung();
    _erkenneRelativeTage();
    _erkenneZeitbereich();
    _erkenneZeit();
    _erkenneDauer();
    _erkenneTageszeit();
    _erkenneAlle();
    _erkennePersonen();

    final art = _erkenneArt();
    final tokens = _restTokens();
    final titel = _baueTitel(tokens);
    final unbekannt = _findeUnbekannt(tokens);
    final zeiten = _berechneZeiten();
    final wiederholung = _baueWiederholung(zeiten.$1);

    return SchnelleingabeErgebnis(
      titel: titel,
      art: art,
      personenNamen: alle ? const [] : List.unmodifiable(personen),
      start: zeiten.$1,
      ende: zeiten.$2,
      ganztaegig: startMinuten == null,
      wiederholung: wiederholung,
      unbekannt: unbekannt,
      alle: alle,
    );
  }

  // --- Datum ----------------------------------------------------------------

  void _erkenneDatumsbereich() {
    final mon = _monatAlt;
    // Deutsch: „3. bis 10. August“, „3.-10.8.“, „vom 3. August bis 10. September“,
    // „03.08. - 10.08.2026“
    _suche(
      '(?:$_wa(?:vom|von)\\s+)?$_wa(\\d{1,2})\\.(?:\\s*($mon)$_we|(\\d{1,2})\\.)?\\s*'
      '(?:bis|-)\\s*(\\d{1,2})\\.\\s*(?:($mon)$_we|(\\d{1,2})\\.?)'
      '(?:\\s*(\\d{4}|\\d{2}))?$_we',
      (m) {
        final t1 = int.parse(m[1]!);
        final t2 = int.parse(m[4]!);
        final m2 = _monat(m[5]) ?? int.tryParse(m[6] ?? '');
        final m1 = _monat(m[2]) ?? int.tryParse(m[3] ?? '') ?? m2;
        if (!_gueltigerTag(t1, m1) || !_gueltigerTag(t2, m2)) return false;
        _setzeBereich(t1, m1!, t2, m2!, _jahr(m[7]));
        return true;
      },
    );
    // Englisch: „Aug 3 to Aug 10“, „from 3 to 10 August“, „3rd to 10th of August“,
    // „August 3 - 5“
    _suche(
      '(?:${_wa}from\\s+)?$_wa(?:($mon)\\s+)?(\\d{1,2})(?:st|nd|rd|th)?(?:\\s+of\\s+($mon))?'
      '\\s*(?:to|-|until|till|through)\\s*(?:($mon)\\s+)?(\\d{1,2})(?:st|nd|rd|th)?'
      '(?:\\s+of)?(?:\\s+($mon))?(?:,?\\s+(\\d{4}))?$_we',
      (m) {
        final m2 = _monat(m[4]) ?? _monat(m[6]);
        final m1 = _monat(m[1]) ?? _monat(m[3]) ?? m2;
        final endMonat = m2 ?? m1;
        if (m1 == null || endMonat == null) return false;
        final t1 = int.parse(m[2]!);
        final t2 = int.parse(m[5]!);
        if (!_gueltigerTag(t1, m1) || !_gueltigerTag(t2, endMonat)) {
          return false;
        }
        _setzeBereich(t1, m1, t2, endMonat, _jahr(m[7]));
        return true;
      },
    );
  }

  void _setzeBereich(int t1, int m1, int t2, int m2, int? jahr) {
    final j = jahr ?? jetzt.year;
    datumMitJahr = jahr != null;
    datum = DateTime(j, m1, t1);
    var ende = DateTime(j, m2, t2);
    if (ende.isBefore(datum!)) ende = DateTime(j + 1, m2, t2);
    endDatum = ende;
  }

  void _erkenneDatum() {
    if (datum != null) return;
    final mon = _monatAlt;
    // ISO „2026-08-03“
    _suche('$_wa(\\d{4})-(\\d{2})-(\\d{2})$_we', (m) {
      final t = int.parse(m[3]!), mo = int.parse(m[2]!);
      if (!_gueltigerTag(t, mo)) return false;
      _setzeDatum(t, mo, int.parse(m[1]!));
      return true;
    });
    if (datum != null) return;
    // „3. August“, „3. Aug 2026“
    _suche('$_wa(\\d{1,2})\\.\\s*($mon)$_we(?:\\s+(\\d{4}))?', (m) {
      final t = int.parse(m[1]!), mo = _monat(m[2]);
      if (!_gueltigerTag(t, mo)) return false;
      _setzeDatum(t, mo!, _jahr(m[3]));
      return true;
    });
    if (datum != null) return;
    // „August 3“, „Aug 3rd, 2026“
    _suche('$_wa($mon)\\s+(\\d{1,2})(?:st|nd|rd|th)?(?:,?\\s+(\\d{4}))?$_we', (
      m,
    ) {
      final t = int.parse(m[2]!), mo = _monat(m[1]);
      if (!_gueltigerTag(t, mo)) return false;
      _setzeDatum(t, mo!, _jahr(m[3]));
      return true;
    });
    if (datum != null) return;
    // „3rd of August“, „3 August 2026“
    _suche(
      '$_wa(\\d{1,2})(?:st|nd|rd|th)?\\s+(?:of\\s+)?($mon)$_we(?:,?\\s+(\\d{4}))?',
      (m) {
        final t = int.parse(m[1]!), mo = _monat(m[2]);
        if (!_gueltigerTag(t, mo)) return false;
        _setzeDatum(t, mo!, _jahr(m[3]));
        return true;
      },
    );
    if (datum != null) return;
    // „3.8.“, „03.08.2026“, „12.3“ (nicht „9.30 Uhr“)
    _suche(
      '$_wa(\\d{1,2})\\.(\\d{1,2})(?:\\.(\\d{4}|\\d{2}))?\\.?(?!\\s*uhr)$_we',
      (m) {
        final t = int.parse(m[1]!), mo = int.parse(m[2]!);
        if (!_gueltigerTag(t, mo)) return false;
        _setzeDatum(t, mo, _jahr(m[3]));
        return true;
      },
    );
  }

  void _setzeDatum(int tag, int monat, int? jahr) {
    datumMitJahr = jahr != null;
    datum = DateTime(jahr ?? jetzt.year, monat, tag);
  }

  // --- Wochentage und Wiederholung -----------------------------------------

  void _erkenneWochentagsbereich() {
    final wd = _wochentagAlt;
    _suche('$_wa($wd)\\.?\\s*(?:-|bis|to|through|until)\\s*($wd)\\.?$_we', (m) {
      final a = _wochentagMitSchreibung(m, 1);
      final b = _wochentagMitSchreibung(m, 2);
      if (a == null || b == null) return false;
      wiederholungTyp ??= WiederholungTyp.woechentlich;
      // Bereich a..b, bei b < a über das Wochenende hinweg.
      final tage = <int>[];
      var d = a;
      while (true) {
        tage.add(d);
        if (d == b) break;
        d = d % 7 + 1;
        if (tage.length > 7) break;
      }
      wiederholungTage = tage;
      return true;
    });
  }

  /// Wochentag aus Gruppe [g]; Zwei-Buchstaben-Kurzformen („So“, „Do“) nur,
  /// wenn sie im Original groß beginnen, sonst sind es normale Wörter.
  int? _wochentagMitSchreibung(RegExpMatch m, int g) {
    final wort = m[g];
    final tag = _wochentag(wort);
    if (tag == null) return null;
    if (wort!.length <= 2) {
      final start = m.start + m[0]!.indexOf(wort);
      final erstes = original[start];
      if (erstes.toUpperCase() != erstes) return null;
    }
    return tag;
  }

  void _erkenneWiederholung() {
    final wd = _wochentagAlt;
    // „jeden Montag“, „jeden 2. Dienstag“, „every other Monday“, „on Mondays“,
    // „jeden Montag und Mittwoch“
    _suche('$_wa(?:(?:jeden|jede|jedes|immer am|immer|every|each|on|an)\\s+'
        '(?:(\\d+)\\.?(?:st|nd|rd|th)?\\s+|(zweiten|dritten|other|second|third)\\s+)?'
        '($wd)s?|($wd)s)$_we'
        '((?:\\s*(?:,|und|and|&)\\s*(?:$wd)s?$_we)*)', (m) {
      final erster = _wochentag(m[3] ?? m[4]);
      if (erster == null) return false;
      if (m[4] != null && !de && m[4]!.length <= 3) return false; // „suns“
      final tage = [erster];
      for (final w in _re('$_wa($wd)s?$_we').allMatches(m[5] ?? '')) {
        final t = _wochentag(w[1]);
        if (t != null && !tage.contains(t)) tage.add(t);
      }
      wiederholungTyp = WiederholungTyp.woechentlich;
      wiederholungIntervall = _zahl(m[1] ?? m[2]) ?? 1;
      wiederholungTage = tage;
      return true;
    });
    // „jeden Werktag“, „werktags“, „every weekday“, „weekdays“
    _suche(
      '$_wa(?:jeden werktag|an werktagen|werktags|wochentags|every weekday|'
      'each weekday|on weekdays|weekdays)$_we',
      (m) {
        wiederholungTyp = WiederholungTyp.woechentlich;
        wiederholungTage = [1, 2, 3, 4, 5];
        return true;
      },
    );
    // „alle 2 Wochen“, „every other week“, „every 3 days“
    _suche(
      '$_wa(?:alle|every|each)\\s+(\\d+|$_zahlAlt)\\s+'
      '(tage?n?|wochen?|monate?n?|jahre?n?|days?|weeks?|months?|years?)$_we',
      (m) {
        final n = _zahl(m[1]);
        if (n == null) return false;
        final e = m[2]!;
        wiederholungTyp = e.startsWith('tag') || e.startsWith('day')
            ? WiederholungTyp.taeglich
            : e.startsWith('woche') || e.startsWith('week')
            ? WiederholungTyp.woechentlich
            : e.startsWith('monat') || e.startsWith('month')
            ? WiederholungTyp.monatlich
            : WiederholungTyp.jaehrlich;
        wiederholungIntervall = n;
        return true;
      },
    );
    // Einfache Wörter
    final einfach = <WiederholungTyp, String>{
      WiederholungTyp.taeglich:
          'täglich|taeglich|tgl\\.?|jeden tag|alle tage|daily|every day|each day',
      WiederholungTyp.woechentlich:
          'wöchentlich|woechentlich|jede woche|weekly|every week|each week',
      WiederholungTyp.monatlich:
          'monatlich|jeden monat|jedes monat|monthly|every month|each month',
      WiederholungTyp.jaehrlich:
          'jährlich|jaehrlich|alljährlich|jedes jahr|yearly|annually|'
          'every year|each year',
    };
    for (final e in einfach.entries) {
      _suche('$_wa(?:${e.value})$_we', (m) {
        wiederholungTyp ??= e.key;
        return true;
      });
    }
  }

  void _erkenneRelativeTage() {
    _suche('$_wa(?:übermorgen|uebermorgen|day after tomorrow)$_we', (m) {
      tagesOffset = 2;
      return true;
    });
    _suche('$_wa(?:morgen|tomorrow)$_we', (m) {
      tagesOffset ??= 1;
      return true;
    });
    _suche('$_wa(?:heute|today|tonight)$_we', (m) {
      tagesOffset ??= 0;
      if (m[0] == 'tonight') nachmittagsHinweis = true;
      return true;
    });
    _suche(
      '$_wa(?:in)\\s+(\\d+|$_zahlAlt)\\s+(tagen?|days?|wochen?|weeks?)$_we',
      (m) {
        final n = _zahl(m[1]);
        if (n == null) return false;
        final wochen = m[2]!.startsWith('w');
        tagesOffset = wochen ? n * 7 : n;
        return true;
      },
    );
    _suche('$_wa(?:nächste|naechste|kommende|next)\\s+(?:woche|week)$_we', (m) {
      naechsteWoche = true;
      return true;
    });
    _suche('$_wa(?:(?:am|this|at the|next|nächstes|naechstes|kommendes)\\s+)?'
        '(?:wochenende|weekend)$_we', (m) {
      wochenende = true;
      return true;
    });
    // Einzelne Wochentage: „Dienstag“, „nächsten Dienstag“, „Di“ („am“ ist
    // Füllwort und bleibt frei, sonst blockiert es „um 9 am Dienstag“).
    final wd = _wochentagAlt;
    _suche('$_wa(?:(?:nächsten|naechsten|nächste|naechste|nächster|kommenden|'
        'next|this|on)\\s+)?($wd)\\.?$_we', (m) {
      final t = _wochentagMitSchreibung(m, 1);
      if (t == null) return false;
      if (!wochentage.contains(t)) wochentage.add(t);
      return true;
    });
    // Mehrere Wochentage ohne „jeden“ („Di und Do 18 Uhr“) gelten als wöchentlich.
    if (wochentage.length >= 2 && wiederholungTyp == null) {
      wiederholungTyp = WiederholungTyp.woechentlich;
      wiederholungTage = List.of(wochentage);
    }
  }

  // --- Uhrzeit --------------------------------------------------------------

  static const String _einheit =
      r'(uhr|h|a\.m\.|p\.m\.|am|pm|o'
      "'"
      r'clock)';

  /// Hat die Einheit „am“ im Deutschen eine Chance? Nur wenn sie direkt an
  /// der Zahl klebt („9am“); „um 9 am Dienstag“ ist das Füllwort.
  bool _einheitErlaubt(String? einheit, String zwischen) {
    if (einheit == null) return true;
    if (de && einheit == 'am' && zwischen.contains(' ')) return false;
    return true;
  }

  static int? _minuten(String? h, String? min) {
    if (h == null) return null;
    final std = int.parse(h);
    final mi = min == null ? 0 : int.parse(min);
    if (std > 24 || mi > 59) return null;
    return std * 60 + mi;
  }

  static int _mitEinheit(int minuten, String? einheit) {
    final e = einheit?.replaceAll('.', '');
    final std = minuten ~/ 60;
    if (e == 'pm' && std < 12) return minuten + 12 * 60;
    if (e == 'am' && std == 12) return minuten - 12 * 60;
    return minuten;
  }

  void _erkenneZeitbereich() {
    _suche('(?:$_wa(?:von|from|zwischen|between)\\s+)?$_wa'
        '(\\d{1,2})(?:[:.](\\d{2}))?(\\s*)$_einheit?\\s*(?:-|bis|to|until|till)\\s*'
        '(\\d{1,2})(?:[:.](\\d{2}))?(\\s*)$_einheit?$_we', (m) {
      var a = _minuten(m[1], m[2]);
      var b = _minuten(m[5], m[6]);
      if (a == null || b == null) return false;
      // Ein nicht erlaubtes „am“ (deutsches Füllwort) zählt nicht als Einheit.
      final ea = _einheitErlaubt(m[4], m[3]!)
          ? m[4]?.replaceAll('.', '')
          : null;
      final eb = _einheitErlaubt(m[8], m[7]!)
          ? m[8]?.replaceAll('.', '')
          : null;
      a = _mitEinheit(a, ea);
      b = _mitEinheit(b, eb);
      // „3 to 5 pm“: pm gilt auch für den Anfang.
      if (eb == 'pm' && ea == null && a ~/ 60 <= (b ~/ 60) - 12) {
        a += 12 * 60;
      }
      // „10-2“ → Ende nachmittags.
      if (b <= a && eb == null && b ~/ 60 < 12) b += 12 * 60;
      // „3-5“ ohne Einheit → nachmittags.
      if (ea == null && eb == null && a ~/ 60 >= 1 && b ~/ 60 <= 6) {
        a += 12 * 60;
        b += 12 * 60;
      }
      if (a > 24 * 60 || b > 24 * 60) return false;
      startMinuten = a;
      endMinuten = b;
      return true;
    });
  }

  void _erkenneZeit() {
    if (startMinuten != null) return;
    // „halb 3“, „viertel nach 3“, „half past 3“, „quarter to 4“
    _suche('(?:$_wa(?:um|at|ab)\\s+)?$_wa(halb|half past|half|viertel nach|'
        'quarter past|viertel vor|quarter to)\\s+(\\d{1,2})$_we', (m) {
      final std = int.parse(m[2]!);
      if (std < 1 || std > 24) return false;
      final art = m[1]!;
      int min;
      if (art == 'halb') {
        min = (std - 1) * 60 + 30; // „halb 3“ = 2:30
      } else if (art.startsWith('half')) {
        min = std * 60 + 30; // „half past 3“ = 3:30
      } else if (art.contains('nach') || art.contains('past')) {
        min = std * 60 + 15;
      } else {
        min = (std - 1) * 60 + 45;
      }
      startMinuten = _nachmittagsWennPlausibel(min);
      return true;
    });
    if (startMinuten != null) return;
    // „15 Uhr“, „15:30“, „15.30 Uhr“, „15h“, „um 9“, „at 9“, „3 pm“, „3:15pm“
    var gefunden = false;
    _suche('($_wa(?:um|at|ab|from)\\s+)?$_wa(\\d{1,2})(?:[:.](\\d{2}))?(\\s*)'
        '$_einheit?$_we', (m) {
      if (gefunden) return false;
      final hatPraefix = m[1] != null;
      final hatMinuten = m[3] != null;
      // „um 9 am Dienstag“: das „am“ ist ein Füllwort, keine Einheit.
      final einheit = _einheitErlaubt(m[5], m[4]!) ? m[5] : null;
      if (!hatPraefix && !hatMinuten && einheit == null) return false;
      var min = _minuten(m[2], m[3]);
      if (min == null) return false;
      if (einheit == null) {
        min = _nachmittagsWennPlausibel(min);
      } else {
        min = _mitEinheit(min, einheit);
      }
      startMinuten = min;
      gefunden = true;
      return true;
    });
  }

  /// 1–6 Uhr ohne weitere Angabe ist meistens nachmittags gemeint.
  int _nachmittagsWennPlausibel(int minuten) {
    final std = minuten ~/ 60;
    if (std >= 1 && std <= 6 && !vormittagsHinweis) return minuten + 12 * 60;
    return minuten;
  }

  void _erkenneDauer() {
    _suche(
      '(?:$_wa(?:für|fuer|for)\\s+)?$_wa(\\d+(?:[.,]\\d+)?|$_zahlAlt)\\s*'
      '(stunden?|std\\.?|hours?|hrs?|h|minuten?|min\\.?|mins?|minutes?)$_we',
      (m) {
        final roh = m[1]!;
        double? n = double.tryParse(roh.replaceAll(',', '.'));
        n ??= switch (roh) {
          'eineinhalb' || 'anderthalb' => 1.5,
          'halbe' || 'half' => 0.5,
          _ => _zahlwoerter[roh]?.toDouble(),
        };
        if (n == null) return false;
        final e = m[2]!;
        final minuten = e.startsWith('min') ? n : n * 60;
        dauer = Duration(minutes: minuten.round());
        return true;
      },
    );
    _suche('$_wa(?:eine halbe stunde|half an hour)$_we', (m) {
      dauer ??= const Duration(minutes: 30);
      return true;
    });
    _suche('$_wa(?:eine stunde|an hour|one hour)$_we', (m) {
      dauer ??= const Duration(hours: 1);
      return true;
    });
  }

  void _erkenneTageszeit() {
    _suche(
      '$_wa(?:morgens|früh|frueh|vormittags?|in the morning|morning)$_we',
      (m) {
        vormittagsHinweis = true;
        return true;
      },
    );
    _suche('$_wa(?:nachmittags?|abends?|nachts?|in the afternoon|afternoon|'
        'in the evening|evening|at night|night)$_we', (m) {
      nachmittagsHinweis = true;
      return true;
    });
    // Hinweise nachträglich anwenden (die Uhrzeit wurde vorher erkannt).
    if (startMinuten != null && endMinuten == null) {
      final std = startMinuten! ~/ 60;
      if (vormittagsHinweis && std >= 13 && std <= 18) {
        // „halb 3 morgens“: die Nachmittagsregel zurücknehmen.
        startMinuten = startMinuten! - 12 * 60;
      } else if (nachmittagsHinweis && std < 12) {
        startMinuten = startMinuten! + 12 * 60;
      }
    }
  }

  // --- Personen -------------------------------------------------------------

  void _erkenneAlle() {
    _suche(
      '$_wa(?:für alle|fuer alle|wir alle|alle|everyone|everybody|all of us|'
      'all)$_we',
      (m) {
        alle = true;
        return true;
      },
    );
  }

  static final RegExp _tokenMuster = RegExp(
    r"[\p{L}\p{N}]+(?:['\-][\p{L}\p{N}]+)*",
    unicode: true,
  );

  static String _ohneGenitiv(String w) {
    var k = w.toLowerCase();
    if (k.endsWith("'s")) return k.substring(0, k.length - 2);
    if (k.endsWith('s') && k.length > 3) k = k.substring(0, k.length - 1);
    return k;
  }

  void _erkennePersonen() {
    for (final m in _tokenMuster.allMatches(klein)) {
      if (!_frei(m)) continue;
      final token = m[0]!;
      final stamm = _ohneGenitiv(token);
      for (final name in mitglieder) {
        final k = name.trim().toLowerCase();
        if (k.isEmpty) continue;
        final vorname = k.split(' ').first;
        if (token == k || token == vorname || stamm == k || stamm == vorname) {
          if (!personen.contains(name)) personen.add(name);
          _verbrauche(m);
          break;
        }
      }
    }
  }

  // --- Art, Titel, Unbekannt -----------------------------------------------

  /// Nur aus nicht erkannten Wörtern, damit „Dienstag“ nicht als Dienst gilt.
  TerminArt? _erkenneArt() {
    for (final m in _tokenMuster.allMatches(klein)) {
      if (!_frei(m)) continue;
      final wort = m[0]!;
      for (final (art, muster) in _artMuster) {
        if (muster.hasMatch(wort)) return art;
      }
    }
    return null;
  }

  /// Übrig gebliebene Wörter in Originalschreibung (null = erkannter Teil).
  List<String?> _restTokens() => [
    for (final m in _tokenMuster.allMatches(original)) _frei(m) ? m[0] : null,
  ];

  String _baueTitel(List<String?> tokens) {
    final fuell = de ? _fuellwoerterDe : _fuellwoerterEn;
    final woerter = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      if (t == null) continue;
      final k = t.toLowerCase();
      if (fuell.contains(k)) continue;
      if (_verbinder.contains(k)) {
        final vorher = i == 0 || tokens[i - 1] == null;
        final nachher = i == tokens.length - 1 || tokens[i + 1] == null;
        if (vorher || nachher) continue;
      }
      woerter.add(t);
    }
    final titel = woerter.join(' ');
    if (titel.isEmpty) return '';
    return titel[0].toUpperCase() + titel.substring(1);
  }

  List<String> _findeUnbekannt(List<String?> tokens) {
    final ergebnis = <String>[];
    var ersterSichtbar = true;
    for (final t in tokens) {
      if (t == null) continue;
      final k = t.toLowerCase();
      final istSpitzname =
          _spitznamen.contains(k) || _spitznamen.contains(_ohneGenitiv(t));
      final grossgeschrieben =
          t[0].toUpperCase() == t[0] && t[0].toLowerCase() != t[0];
      final fuell = de ? _fuellwoerterDe : _fuellwoerterEn;
      final istWort = !fuell.contains(k) && !_verbinder.contains(k);
      if (istSpitzname) {
        ergebnis.add(t);
      } else if (!de &&
          grossgeschrieben &&
          istWort &&
          !ersterSichtbar &&
          !_monate.containsKey(k)) {
        ergebnis.add(t);
      }
      if (istWort) ersterSichtbar = false;
    }
    return ergebnis;
  }

  // --- Zeiten ---------------------------------------------------------------

  DateTime get _heute => DateTime(jetzt.year, jetzt.month, jetzt.day);

  /// Tage addieren über den Kalender (nicht über Dauer), damit die
  /// Sommerzeit-Umstellung keine 23-Uhr-Termine erzeugt.
  static DateTime _tagPlus(DateTime t, int tage) =>
      DateTime(t.year, t.month, t.day + tage);

  /// Tag plus Uhrzeit in Minuten als lokale Wanduhrzeit.
  static DateTime _tagMitMinuten(DateTime t, int minuten) =>
      DateTime(t.year, t.month, t.day, minuten ~/ 60, minuten % 60);

  static int _tageZwischen(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;

  int get _jetztMinuten => jetzt.hour * 60 + jetzt.minute;

  /// Startdatum und Enddatum (Tag) bestimmen, dann Uhrzeiten anlegen.
  (DateTime?, DateTime?) _berechneZeiten() {
    var tag = _bestimmeStarttag();
    if (tag == null) return (null, null);
    var endTag = endDatum ?? tag;
    if (datum != null && !datumMitJahr) {
      // Ohne Jahr: liegt der Tag schon zurück, ist das nächste Jahr gemeint.
      if (tag.isBefore(_heute)) {
        final abstand = _tageZwischen(tag, endTag);
        tag = DateTime(tag.year + 1, tag.month, tag.day);
        endTag = _tagPlus(tag, abstand);
      }
    }
    if (startMinuten == null) {
      return (tag, _tagPlus(endTag, 1));
    }
    final start = _tagMitMinuten(tag, startMinuten!);
    DateTime ende;
    if (endMinuten != null) {
      ende = _tagMitMinuten(endTag, endMinuten!);
      if (!ende.isAfter(start)) {
        ende = _tagMitMinuten(_tagPlus(endTag, 1), endMinuten!);
      }
    } else if (endDatum != null) {
      ende = _tagMitMinuten(
        endTag,
        startMinuten!,
      ).add(dauer ?? const Duration(hours: 1));
    } else {
      ende = start.add(dauer ?? const Duration(hours: 1));
    }
    return (start, ende);
  }

  /// Zählt heute noch, wenn ganztägig oder die Uhrzeit noch vor uns liegt.
  bool get _heuteZaehlt =>
      startMinuten == null || startMinuten! > _jetztMinuten;

  DateTime? _bestimmeStarttag() {
    if (datum != null) return datum;
    if (tagesOffset != null) {
      return _tagPlus(_heute, tagesOffset!);
    }
    if (naechsteWoche) {
      final montag = _tagPlus(_heute, 8 - _heute.weekday);
      final ziel = wochentage.isNotEmpty
          ? wochentage.first
          : (wiederholungTage.isNotEmpty ? wiederholungTage.first : 1);
      return _tagPlus(montag, ziel - 1);
    }
    if (wochenende) return _naechsterTag([6]);
    if (wochentage.isNotEmpty) return _naechsterTag([wochentage.first]);
    if (wiederholungTage.isNotEmpty) return _naechsterTag(wiederholungTage);
    if (startMinuten != null || wiederholungTyp != null) {
      return _heuteZaehlt ? _heute : _tagPlus(_heute, 1);
    }
    return null;
  }

  DateTime _naechsterTag(List<int> tage) {
    for (var i = 0; i < 8; i++) {
      final t = _tagPlus(_heute, i);
      if (!tage.contains(t.weekday)) continue;
      if (i == 0 && !_heuteZaehlt) continue;
      return t;
    }
    return _heute;
  }

  Wiederholung? _baueWiederholung(DateTime? start) {
    final typ = wiederholungTyp;
    if (typ == null) return null;
    var tage = wiederholungTage;
    if (typ == WiederholungTyp.woechentlich && tage.isEmpty) {
      if (wochentage.isNotEmpty) {
        tage = List.of(wochentage);
      } else if (start != null) {
        tage = [start.weekday];
      }
    }
    return Wiederholung(
      typ: typ,
      intervall: wiederholungIntervall.clamp(1, 365),
      wochentage: typ == WiederholungTyp.woechentlich
          ? (tage.toList()..sort())
          : const [],
    );
  }
}

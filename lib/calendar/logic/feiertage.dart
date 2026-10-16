/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Gesetzliche Feiertage für Österreich und Deutschland, bundesweit und je
/// Bundesland. Reine Dart-Tabelle ohne Netz; bewegliche Feiertage werden
/// über das Osterdatum (Gauß'sche Osterformel in der Form des anonymen
/// gregorianischen Algorithmus) berechnet.
///
/// Quellen (Stand 2026):
/// - Österreich: Feiertagsruhegesetz (BGBl. Nr. 153/1957 i. d. g. F.);
///   Landesfeiertage laut Landesgesetzen (Landespatrone), vgl.
///   https://de.wikipedia.org/wiki/Feiertage_in_%C3%96sterreich
/// - Deutschland: Feiertagsgesetze der Länder, Übersicht
///   https://de.wikipedia.org/wiki/Gesetzliche_Feiertage_in_Deutschland
///
/// Bewusst nicht enthalten: Karfreitag in Österreich (seit 2019 kein
/// gesetzlicher Feiertag mehr, „persönlicher Feiertag“), Mariä Himmelfahrt in
/// Bayern und Fronleichnam in Sachsen/Thüringen (nur in einzelnen Gemeinden),
/// Augsburger Friedensfest (nur Stadt Augsburg).
///
/// Schulferien sind noch nicht hinterlegt (jährlich wechselnd). Die
/// Datenstruktur ist dafür vorbereitet: `Feiertag.art` und `Feiertag.bis`
/// erlauben mehrtägige Einträge der Art `ferien`; `ferienIm` liefert heute
/// eine leere Liste.
library;

/// Art eines Eintrags: gesetzlicher Feiertag oder (später) Schulferien.
enum FeiertagArt { gesetzlich, ferien }

/// Ein Feiertag an einem reinen Tag (UTC-Mitternacht, wie `nurTag`).
/// Bei Ferien reicht der Zeitraum von `tag` bis `bis` (einschließlich).
class Feiertag {
  const Feiertag({
    required this.tag,
    required this.nameDe,
    required this.nameEn,
    this.art = FeiertagArt.gesetzlich,
    DateTime? bis,
  }) : _bis = bis;

  final DateTime tag;
  final String nameDe;
  final String nameEn;
  final FeiertagArt art;
  final DateTime? _bis;

  /// Letzter Tag (einschließlich); bei eintägigen Feiertagen gleich `tag`.
  DateTime get bis => _bis ?? tag;

  String name(String sprache) => sprache.startsWith('de') ? nameDe : nameEn;

  @override
  String toString() => '$nameDe ${tag.toIso8601String().substring(0, 10)}';
}

/// Region, für die Feiertage berechnet werden können (Bundesland).
class FeiertagsRegion {
  const FeiertagsRegion({
    required this.code,
    required this.land,
    required this.nameDe,
    required this.nameEn,
  });

  /// `AT-1` … `AT-9`, `DE-BW` … `DE-TH`.
  final String code;

  /// `AT` oder `DE`.
  final String land;
  final String nameDe;
  final String nameEn;

  String name(String sprache) => sprache.startsWith('de') ? nameDe : nameEn;
}

/// Alle wählbaren Regionen, Österreich zuerst, dann Deutschland.
const List<FeiertagsRegion> feiertagsRegionen = [
  FeiertagsRegion(code: 'AT-1', land: 'AT', nameDe: 'Burgenland', nameEn: 'Burgenland'),
  FeiertagsRegion(code: 'AT-2', land: 'AT', nameDe: 'Kärnten', nameEn: 'Carinthia'),
  FeiertagsRegion(code: 'AT-3', land: 'AT', nameDe: 'Niederösterreich', nameEn: 'Lower Austria'),
  FeiertagsRegion(code: 'AT-4', land: 'AT', nameDe: 'Oberösterreich', nameEn: 'Upper Austria'),
  FeiertagsRegion(code: 'AT-5', land: 'AT', nameDe: 'Salzburg', nameEn: 'Salzburg'),
  FeiertagsRegion(code: 'AT-6', land: 'AT', nameDe: 'Steiermark', nameEn: 'Styria'),
  FeiertagsRegion(code: 'AT-7', land: 'AT', nameDe: 'Tirol', nameEn: 'Tyrol'),
  FeiertagsRegion(code: 'AT-8', land: 'AT', nameDe: 'Vorarlberg', nameEn: 'Vorarlberg'),
  FeiertagsRegion(code: 'AT-9', land: 'AT', nameDe: 'Wien', nameEn: 'Vienna'),
  FeiertagsRegion(code: 'DE-BW', land: 'DE', nameDe: 'Baden-Württemberg', nameEn: 'Baden-Württemberg'),
  FeiertagsRegion(code: 'DE-BY', land: 'DE', nameDe: 'Bayern', nameEn: 'Bavaria'),
  FeiertagsRegion(code: 'DE-BE', land: 'DE', nameDe: 'Berlin', nameEn: 'Berlin'),
  FeiertagsRegion(code: 'DE-BB', land: 'DE', nameDe: 'Brandenburg', nameEn: 'Brandenburg'),
  FeiertagsRegion(code: 'DE-HB', land: 'DE', nameDe: 'Bremen', nameEn: 'Bremen'),
  FeiertagsRegion(code: 'DE-HH', land: 'DE', nameDe: 'Hamburg', nameEn: 'Hamburg'),
  FeiertagsRegion(code: 'DE-HE', land: 'DE', nameDe: 'Hessen', nameEn: 'Hesse'),
  FeiertagsRegion(code: 'DE-MV', land: 'DE', nameDe: 'Mecklenburg-Vorpommern', nameEn: 'Mecklenburg-Vorpommern'),
  FeiertagsRegion(code: 'DE-NI', land: 'DE', nameDe: 'Niedersachsen', nameEn: 'Lower Saxony'),
  FeiertagsRegion(code: 'DE-NW', land: 'DE', nameDe: 'Nordrhein-Westfalen', nameEn: 'North Rhine-Westphalia'),
  FeiertagsRegion(code: 'DE-RP', land: 'DE', nameDe: 'Rheinland-Pfalz', nameEn: 'Rhineland-Palatinate'),
  FeiertagsRegion(code: 'DE-SL', land: 'DE', nameDe: 'Saarland', nameEn: 'Saarland'),
  FeiertagsRegion(code: 'DE-SN', land: 'DE', nameDe: 'Sachsen', nameEn: 'Saxony'),
  FeiertagsRegion(code: 'DE-ST', land: 'DE', nameDe: 'Sachsen-Anhalt', nameEn: 'Saxony-Anhalt'),
  FeiertagsRegion(code: 'DE-SH', land: 'DE', nameDe: 'Schleswig-Holstein', nameEn: 'Schleswig-Holstein'),
  FeiertagsRegion(code: 'DE-TH', land: 'DE', nameDe: 'Thüringen', nameEn: 'Thuringia'),
];

/// Region zu einem Code, oder `null`.
FeiertagsRegion? feiertagsRegion(String? code) {
  if (code == null) return null;
  for (final r in feiertagsRegionen) {
    if (r.code == code) return r;
  }
  return null;
}

/// Name der Region (`sprache` = `de` oder `en`), oder `null` bei unbekanntem Code.
String? regionName(String? code, {String sprache = 'de'}) =>
    feiertagsRegion(code)?.name(sprache);

/// Ostersonntag des Jahres (gregorianisch), reiner Tag.
DateTime ostersonntag(int jahr) {
  final a = jahr % 19;
  final b = jahr ~/ 100;
  final c = jahr % 100;
  final d = b ~/ 4;
  final e = b % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = c % 4;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final monat = (h + l - 7 * m + 114) ~/ 31;
  final tag = (h + l - 7 * m + 114) % 31 + 1;
  return DateTime.utc(jahr, monat, tag);
}

/// Buß- und Bettag: Mittwoch vor dem 23. November.
DateTime bussUndBettag(int jahr) {
  var t = DateTime.utc(jahr, 11, 22);
  while (t.weekday != DateTime.wednesday) {
    t = t.subtract(const Duration(days: 1));
  }
  return t;
}

Feiertag _f(DateTime tag, String de, String en) =>
    Feiertag(tag: tag, nameDe: de, nameEn: en);

/// Gesetzliche Feiertage eines Jahres in der Region, aufsteigend nach Tag.
/// Unbekannte Region → leere Liste.
List<Feiertag> feiertageIm(int jahr, String region) {
  final r = feiertagsRegion(region);
  if (r == null) return const [];
  final ostern = ostersonntag(jahr);
  DateTime fix(int monat, int tag) => DateTime.utc(jahr, monat, tag);
  DateTime beweglich(int tage) => ostern.add(Duration(days: tage));

  final out = <Feiertag>[];
  if (r.land == 'AT') {
    out.addAll([
      _f(fix(1, 1), 'Neujahr', "New Year's Day"),
      _f(fix(1, 6), 'Heilige Drei Könige', 'Epiphany'),
      _f(beweglich(1), 'Ostermontag', 'Easter Monday'),
      _f(fix(5, 1), 'Staatsfeiertag', 'Labour Day'),
      _f(beweglich(39), 'Christi Himmelfahrt', 'Ascension Day'),
      _f(beweglich(50), 'Pfingstmontag', 'Whit Monday'),
      _f(beweglich(60), 'Fronleichnam', 'Corpus Christi'),
      _f(fix(8, 15), 'Mariä Himmelfahrt', 'Assumption Day'),
      _f(fix(10, 26), 'Nationalfeiertag', 'National Day'),
      _f(fix(11, 1), 'Allerheiligen', "All Saints' Day"),
      _f(fix(12, 8), 'Mariä Empfängnis', 'Immaculate Conception'),
      _f(fix(12, 25), 'Christtag', 'Christmas Day'),
      _f(fix(12, 26), 'Stefanitag', "St. Stephen's Day"),
    ]);
    // Landesfeiertage (Landespatrone): schulfrei und für Landesbedienstete frei.
    switch (r.code) {
      case 'AT-1':
        out.add(_f(fix(11, 11), 'Martinstag', "St. Martin's Day"));
      case 'AT-2':
        out.add(_f(fix(3, 19), 'Josefitag', "St. Joseph's Day"));
        out.add(_f(fix(10, 10), 'Tag der Volksabstimmung', 'Plebiscite Day'));
      case 'AT-3':
      case 'AT-9':
        out.add(_f(fix(11, 15), 'Leopolditag', "St. Leopold's Day"));
      case 'AT-4':
        out.add(_f(fix(5, 4), 'Florianitag', "St. Florian's Day"));
      case 'AT-5':
        out.add(_f(fix(9, 24), 'Rupertitag', "St. Rupert's Day"));
      case 'AT-6':
      case 'AT-7':
      case 'AT-8':
        out.add(_f(fix(3, 19), 'Josefitag', "St. Joseph's Day"));
    }
  } else {
    final l = r.code.substring(3); // BW, BY, …
    out.addAll([
      _f(fix(1, 1), 'Neujahr', "New Year's Day"),
      _f(beweglich(-2), 'Karfreitag', 'Good Friday'),
      _f(beweglich(1), 'Ostermontag', 'Easter Monday'),
      _f(fix(5, 1), 'Tag der Arbeit', 'Labour Day'),
      _f(beweglich(39), 'Christi Himmelfahrt', 'Ascension Day'),
      _f(beweglich(50), 'Pfingstmontag', 'Whit Monday'),
      _f(fix(10, 3), 'Tag der Deutschen Einheit', 'German Unity Day'),
      _f(fix(12, 25), '1. Weihnachtstag', 'Christmas Day'),
      _f(fix(12, 26), '2. Weihnachtstag', "St. Stephen's Day"),
    ]);
    const dreiKoenige = {'BW', 'BY', 'ST'};
    const frauentag = {'BE', 'MV'};
    const fronleichnam = {'BW', 'BY', 'HE', 'NW', 'RP', 'SL'};
    const reformation = {'BB', 'HB', 'HH', 'MV', 'NI', 'SN', 'ST', 'SH', 'TH'};
    const allerheiligen = {'BW', 'BY', 'NW', 'RP', 'SL'};
    if (dreiKoenige.contains(l)) {
      out.add(_f(fix(1, 6), 'Heilige Drei Könige', 'Epiphany'));
    }
    if (frauentag.contains(l)) {
      out.add(_f(fix(3, 8), 'Internationaler Frauentag', "International Women's Day"));
    }
    if (l == 'BB') {
      out.add(_f(ostern, 'Ostersonntag', 'Easter Sunday'));
      out.add(_f(beweglich(49), 'Pfingstsonntag', 'Whit Sunday'));
    }
    if (fronleichnam.contains(l)) {
      out.add(_f(beweglich(60), 'Fronleichnam', 'Corpus Christi'));
    }
    if (l == 'SL') {
      out.add(_f(fix(8, 15), 'Mariä Himmelfahrt', 'Assumption Day'));
    }
    if (l == 'TH') {
      out.add(_f(fix(9, 20), 'Weltkindertag', "World Children's Day"));
    }
    if (reformation.contains(l)) {
      out.add(_f(fix(10, 31), 'Reformationstag', 'Reformation Day'));
    }
    if (allerheiligen.contains(l)) {
      out.add(_f(fix(11, 1), 'Allerheiligen', "All Saints' Day"));
    }
    if (l == 'SN') {
      out.add(_f(bussUndBettag(jahr), 'Buß- und Bettag', 'Day of Repentance and Prayer'));
    }
  }
  out.sort((a, b) => a.tag.compareTo(b.tag));
  return out;
}

/// Schulferien (noch nicht hinterlegt). Platzhalter mit derselben Struktur,
/// damit der Jahresüberblick sie später ohne Umbau anzeigen kann.
List<Feiertag> ferienIm(int jahr, String region) => const [];

/// Feiertage als Abbildung Tag → Feiertag (schneller Zugriff beim Zeichnen).
Map<DateTime, Feiertag> feiertageNachTag(int jahr, String? region) {
  if (region == null) return const {};
  return {for (final f in feiertageIm(jahr, region)) f.tag: f};
}

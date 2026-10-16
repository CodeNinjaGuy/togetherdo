/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Zerlegt gesprochene Einkaufswünsche wie „2 kg Tomaten und 1 Liter Milch“
/// in Einträge (Menge, Einheit, Name). Reine Dart-Logik ohne Flutter,
/// damit sie sich gut testen lässt.
///
/// Deutsch und Englisch kennen Zahlwörter und Einheiten mit Synonymen,
/// andere Sprachen fallen auf Ziffern + Name zurück.
library;

/// Einheiten, die der Zerleger erkennt. Die Anzeige übersetzt sie über die
/// ARB-Schlüssel `unit_*`.
enum VoiceUnit {
  piece,
  kg,
  g,
  l,
  ml,
  pack,
  can,
  bottle,
  bag,
  bunch,
  head,
  cup,
  jar,
}

class VoiceParsedItem {
  const VoiceParsedItem({required this.name, this.quantity = 1, this.unit});

  final String name;
  final double quantity;
  final VoiceUnit? unit;

  @override
  bool operator ==(Object other) =>
      other is VoiceParsedItem &&
      other.name == name &&
      (other.quantity - quantity).abs() < 1e-9 &&
      other.unit == unit;

  @override
  int get hashCode => Object.hash(name, quantity, unit);

  @override
  String toString() => 'VoiceParsedItem($quantity ${unit?.name ?? '-'} $name)';
}

/// Sprachabhängige Wörterbücher.
class _Lexicon {
  const _Lexicon({
    required this.numberWords,
    required this.units,
    required this.separators,
    required this.fillers,
    required this.halfWords,
    required this.andAHalf,
    this.compoundTens = const {},
    this.compoundJoiner,
    this.halfSuffix,
  });

  /// Zahlwort → Wert („zwei“ → 2, „a“ → 1).
  final Map<String, double> numberWords;

  /// Synonym → Einheit („kilo“ → kg).
  final Map<String, VoiceUnit> units;

  /// Wörter, die Einträge trennen („und“, „and“). Kommas trennen immer.
  final Set<String> separators;

  /// Füllwörter, die aus dem Namen fallen („bitte“, „please“, „of“).
  final Set<String> fillers;

  /// Wörter für „halb“ → 0,5 (auch als Vorsatz: „halbes Kilo“).
  final Set<String> halfWords;

  /// Mehrwort-Folgen für „… und ein halb“ → +0,5.
  final List<List<String>> andAHalf;

  /// Zehner für zusammengesetzte Zahlwörter („dreiundzwanzig“).
  final Map<String, double> compoundTens;

  /// Verbinder in zusammengesetzten Zahlwörtern („und“ in „dreiundzwanzig“).
  final String? compoundJoiner;

  /// Suffix für „zweieinhalb“ → 2,5.
  final String? halfSuffix;
}

const Map<String, VoiceUnit> _unitsDe = {
  'stück': VoiceUnit.piece,
  'stk': VoiceUnit.piece,
  'stk.': VoiceUnit.piece,
  'stueck': VoiceUnit.piece,
  'kg': VoiceUnit.kg,
  'kilo': VoiceUnit.kg,
  'kilos': VoiceUnit.kg,
  'kilogramm': VoiceUnit.kg,
  'g': VoiceUnit.g,
  'gramm': VoiceUnit.g,
  'gr': VoiceUnit.g,
  'l': VoiceUnit.l,
  'liter': VoiceUnit.l,
  'litern': VoiceUnit.l,
  'ml': VoiceUnit.ml,
  'milliliter': VoiceUnit.ml,
  'packung': VoiceUnit.pack,
  'packungen': VoiceUnit.pack,
  'pkg': VoiceUnit.pack,
  'pkg.': VoiceUnit.pack,
  'päckchen': VoiceUnit.pack,
  'paeckchen': VoiceUnit.pack,
  'packerl': VoiceUnit.pack,
  'pack': VoiceUnit.pack,
  'packen': VoiceUnit.pack,
  'schachtel': VoiceUnit.pack,
  'schachteln': VoiceUnit.pack,
  'dose': VoiceUnit.can,
  'dosen': VoiceUnit.can,
  'flasche': VoiceUnit.bottle,
  'flaschen': VoiceUnit.bottle,
  'tüte': VoiceUnit.bag,
  'tüten': VoiceUnit.bag,
  'tuete': VoiceUnit.bag,
  'tueten': VoiceUnit.bag,
  'sackerl': VoiceUnit.bag,
  'beutel': VoiceUnit.bag,
  'sack': VoiceUnit.bag,
  'säcke': VoiceUnit.bag,
  'bund': VoiceUnit.bunch,
  'bünde': VoiceUnit.bunch,
  'buende': VoiceUnit.bunch,
  'kopf': VoiceUnit.head,
  'köpfe': VoiceUnit.head,
  'koepfe': VoiceUnit.head,
  'becher': VoiceUnit.cup,
  'glas': VoiceUnit.jar,
  'gläser': VoiceUnit.jar,
  'glaeser': VoiceUnit.jar,
};

const Map<String, double> _numbersDe = {
  'null': 0,
  'ein': 1,
  'eine': 1,
  'einen': 1,
  'einer': 1,
  'eins': 1,
  'einem': 1,
  'zwei': 2,
  'zwo': 2,
  'drei': 3,
  'vier': 4,
  'fünf': 5,
  'fuenf': 5,
  'sechs': 6,
  'sieben': 7,
  'acht': 8,
  'neun': 9,
  'zehn': 10,
  'elf': 11,
  'zwölf': 12,
  'zwoelf': 12,
  'dreizehn': 13,
  'vierzehn': 14,
  'fünfzehn': 15,
  'fuenfzehn': 15,
  'sechzehn': 16,
  'siebzehn': 17,
  'achtzehn': 18,
  'neunzehn': 19,
  'zwanzig': 20,
  'dreißig': 30,
  'dreissig': 30,
  'vierzig': 40,
  'fünfzig': 50,
  'fuenfzig': 50,
  'sechzig': 60,
  'siebzig': 70,
  'achtzig': 80,
  'neunzig': 90,
  'hundert': 100,
  'eineinhalb': 1.5,
  'anderthalb': 1.5,
  'dutzend': 12,
};

const Map<String, double> _tensDe = {
  'zwanzig': 20,
  'dreißig': 30,
  'dreissig': 30,
  'vierzig': 40,
  'fünfzig': 50,
  'fuenfzig': 50,
  'sechzig': 60,
  'siebzig': 70,
  'achtzig': 80,
  'neunzig': 90,
};

const _lexiconDe = _Lexicon(
  numberWords: _numbersDe,
  units: _unitsDe,
  separators: {'und', 'sowie', 'plus', 'dann', 'außerdem', 'ausserdem'},
  fillers: {'bitte', 'noch', 'mal', 'auch', 'äh', 'ähm', 'also', 'von', 'vom'},
  halfWords: {'halb', 'halbe', 'halben', 'halbes', 'halber'},
  andAHalf: [
    ['und', 'ein', 'halb'],
    ['und', 'eine', 'halbe'],
    ['und', 'einen', 'halben'],
    ['und', 'ein', 'halbes'],
    ['einhalb'],
    ['ein', 'halb'],
  ],
  compoundTens: _tensDe,
  compoundJoiner: 'und',
  halfSuffix: 'einhalb',
);

const Map<String, VoiceUnit> _unitsEn = {
  'piece': VoiceUnit.piece,
  'pieces': VoiceUnit.piece,
  'pc': VoiceUnit.piece,
  'pcs': VoiceUnit.piece,
  'kg': VoiceUnit.kg,
  'kilo': VoiceUnit.kg,
  'kilos': VoiceUnit.kg,
  'kilogram': VoiceUnit.kg,
  'kilograms': VoiceUnit.kg,
  'kilogramme': VoiceUnit.kg,
  'g': VoiceUnit.g,
  'gram': VoiceUnit.g,
  'grams': VoiceUnit.g,
  'gramme': VoiceUnit.g,
  'grammes': VoiceUnit.g,
  'l': VoiceUnit.l,
  'liter': VoiceUnit.l,
  'liters': VoiceUnit.l,
  'litre': VoiceUnit.l,
  'litres': VoiceUnit.l,
  'ml': VoiceUnit.ml,
  'milliliter': VoiceUnit.ml,
  'milliliters': VoiceUnit.ml,
  'millilitre': VoiceUnit.ml,
  'millilitres': VoiceUnit.ml,
  'pack': VoiceUnit.pack,
  'packs': VoiceUnit.pack,
  'package': VoiceUnit.pack,
  'packages': VoiceUnit.pack,
  'packet': VoiceUnit.pack,
  'packets': VoiceUnit.pack,
  'box': VoiceUnit.pack,
  'boxes': VoiceUnit.pack,
  'can': VoiceUnit.can,
  'cans': VoiceUnit.can,
  'tin': VoiceUnit.can,
  'tins': VoiceUnit.can,
  'bottle': VoiceUnit.bottle,
  'bottles': VoiceUnit.bottle,
  'bag': VoiceUnit.bag,
  'bags': VoiceUnit.bag,
  'bunch': VoiceUnit.bunch,
  'bunches': VoiceUnit.bunch,
  'head': VoiceUnit.head,
  'heads': VoiceUnit.head,
  'cup': VoiceUnit.cup,
  'cups': VoiceUnit.cup,
  'tub': VoiceUnit.cup,
  'tubs': VoiceUnit.cup,
  'jar': VoiceUnit.jar,
  'jars': VoiceUnit.jar,
};

const Map<String, double> _numbersEn = {
  'zero': 0,
  'a': 1,
  'an': 1,
  'one': 1,
  'two': 2,
  'three': 3,
  'four': 4,
  'five': 5,
  'six': 6,
  'seven': 7,
  'eight': 8,
  'nine': 9,
  'ten': 10,
  'eleven': 11,
  'twelve': 12,
  'thirteen': 13,
  'fourteen': 14,
  'fifteen': 15,
  'sixteen': 16,
  'seventeen': 17,
  'eighteen': 18,
  'nineteen': 19,
  'twenty': 20,
  'thirty': 30,
  'forty': 40,
  'fifty': 50,
  'sixty': 60,
  'seventy': 70,
  'eighty': 80,
  'ninety': 90,
  'hundred': 100,
  'dozen': 12,
  'couple': 2,
};

const _lexiconEn = _Lexicon(
  numberWords: _numbersEn,
  units: _unitsEn,
  separators: {'and', 'plus', 'then', 'also'},
  fillers: {'please', 'some', 'of', 'the', 'um', 'uh', 'more', 'another'},
  halfWords: {'half'},
  andAHalf: [
    ['and', 'a', 'half'],
    ['and', 'half'],
  ],
  compoundTens: {
    'twenty': 20,
    'thirty': 30,
    'forty': 40,
    'fifty': 50,
    'sixty': 60,
    'seventy': 70,
    'eighty': 80,
    'ninety': 90,
  },
  compoundJoiner: '-',
);

/// Rückfall für andere Sprachen: nur Ziffern, Kommas trennen.
const _lexiconFallback = _Lexicon(
  numberWords: {},
  units: {},
  separators: {},
  fillers: {},
  halfWords: {},
  andAHalf: [],
);

class VoiceItemParser {
  VoiceItemParser.forLanguage(String languageCode)
    : _lex = switch (languageCode.toLowerCase().split(RegExp('[-_]')).first) {
        'de' => _lexiconDe,
        'en' => _lexiconEn,
        _ => _lexiconFallback,
      };

  final _Lexicon _lex;

  static final RegExp _number = RegExp(r'^\d+(?:[.,]\d+)?$');
  static final RegExp _numberWithUnit = RegExp(
    r'^(\d+(?:[.,]\d+)?)\s*([^\d\s.,]+)$',
    unicode: true,
  );
  static final RegExp _fraction = RegExp(r'^(\d+)/(\d+)$');

  List<VoiceParsedItem> parse(String text) {
    final normalized = text
        .toLowerCase()
        .replaceAllMapped(
          RegExp(r'(\d),(\d)'),
          (m) => '${m.group(1)}.${m.group(2)}',
        )
        .replaceAll(RegExp(r'[!?;]'), ',')
        .replaceAll(RegExp(r'\.(\s|$)'), r' ');
    final items = <VoiceParsedItem>[];
    for (final segment in _segments(normalized)) {
      final item = _parseSegment(segment);
      if (item != null) items.add(item);
    }
    return items;
  }

  /// Teilt an Kommas und Trennwörtern. „und“ innerhalb von „… und ein halb“
  /// bleibt zusammen.
  List<List<String>> _segments(String text) {
    final result = <List<String>>[];
    for (final part in text.split(',')) {
      final tokens = part
          .split(RegExp(r'\s+'))
          .where((t) => t.isNotEmpty)
          .toList();
      var current = <String>[];
      for (var i = 0; i < tokens.length; i++) {
        final t = tokens[i];
        if (_lex.separators.contains(t) &&
            !_startsAndAHalf(tokens, i) &&
            current.isNotEmpty &&
            i < tokens.length - 1) {
          result.add(current);
          current = <String>[];
          continue;
        }
        current.add(t);
      }
      if (current.isNotEmpty) result.add(current);
    }
    return result;
  }

  bool _startsAndAHalf(List<String> tokens, int i) {
    for (final phrase in _lex.andAHalf) {
      if (phrase.length <= tokens.length - i) {
        var match = true;
        for (var k = 0; k < phrase.length; k++) {
          if (tokens[i + k] != phrase[k]) {
            match = false;
            break;
          }
        }
        if (match) return true;
      }
    }
    return false;
  }

  VoiceParsedItem? _parseSegment(List<String> rawTokens) {
    // „2kg“ → „2“, „kg“
    final tokens = <String>[];
    for (final t in rawTokens) {
      final m = _numberWithUnit.firstMatch(t);
      if (m != null && _lex.units.containsKey(m.group(2))) {
        tokens.add(m.group(1)!);
        tokens.add(m.group(2)!);
      } else {
        tokens.add(t);
      }
    }

    double? quantity;
    var quantityIndex = -1;
    final consumed = List<bool>.filled(tokens.length, false);

    // 1. Zahl finden (Ziffer, Bruch, Zahlwort, „halb“, zusammengesetzt).
    for (var i = 0; i < tokens.length && quantity == null; i++) {
      final t = tokens[i];
      final value = _numberValue(t);
      final next = i + 1 < tokens.length ? tokens[i + 1] : null;
      if (value == 1 && next != null && _lex.halfWords.contains(next)) {
        // „ein halbes Kilo“ → 0,5; der Halb-Zweig unten übernimmt.
        continue;
      }
      if (value == 1 &&
          next != null &&
          _lex.numberWords[t] == 1 &&
          (_lex.numberWords[next] ?? 0) >= 2) {
        // „ein Dutzend“, „a dozen“: Artikel überspringen.
        consumed[i] = true;
        continue;
      }
      if (value != null) {
        quantity = value;
        quantityIndex = i;
        consumed[i] = true;
        // „1 1/2“
        if (i + 1 < tokens.length) {
          final f = _fraction.firstMatch(tokens[i + 1]);
          if (f != null) {
            quantity =
                quantity + int.parse(f.group(1)!) / int.parse(f.group(2)!);
            consumed[i + 1] = true;
          }
        }
        // „zwei und ein halb“, „two and a half“
        for (final phrase in _lex.andAHalf) {
          final start = i + 1;
          if (start + phrase.length <= tokens.length) {
            var ok = true;
            for (var k = 0; k < phrase.length; k++) {
              if (tokens[start + k] != phrase[k]) {
                ok = false;
                break;
              }
            }
            if (ok) {
              quantity = quantity! + 0.5;
              for (var k = 0; k < phrase.length; k++) {
                consumed[start + k] = true;
              }
              break;
            }
          }
        }
      } else if (_lex.halfWords.contains(t)) {
        // „halbes Kilo“, „half a kilo“, „ein halbes …“
        quantity = 0.5;
        quantityIndex = i;
        consumed[i] = true;
        if (i > 0 && (_lex.numberWords[tokens[i - 1]] == 1)) {
          consumed[i - 1] = true;
        }
        if (i + 1 < tokens.length && _lex.numberWords[tokens[i + 1]] == 1) {
          consumed[i + 1] = true; // „half a kilo“
        }
      }
    }

    // 2. Einheit: Token direkt nach der Zahl, sonst direkt davor, sonst
    //    irgendwo (dann Menge 1).
    VoiceUnit? unit;
    int unitIndex = -1;
    VoiceUnit? unitAt(int idx) =>
        idx >= 0 && idx < tokens.length && !consumed[idx]
        ? _lex.units[tokens[idx]]
        : null;
    if (quantityIndex >= 0) {
      var after = quantityIndex + 1;
      while (after < tokens.length && consumed[after]) {
        after++;
      }
      unit = unitAt(after);
      if (unit != null) {
        unitIndex = after;
      } else {
        unit = unitAt(quantityIndex - 1);
        if (unit != null) unitIndex = quantityIndex - 1;
      }
    }
    if (unit == null) {
      for (var i = 0; i < tokens.length; i++) {
        final u = unitAt(i);
        if (u != null) {
          unit = u;
          unitIndex = i;
          break;
        }
      }
    }
    if (unitIndex >= 0) consumed[unitIndex] = true;

    // 3. Name aus dem Rest, ohne Füllwörter.
    final nameTokens = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (consumed[i]) continue;
      final t = tokens[i];
      if (_lex.fillers.contains(t)) continue;
      if (_lex.separators.contains(t) &&
          (nameTokens.isEmpty || i == tokens.length - 1)) {
        continue;
      }
      nameTokens.add(t);
    }
    if (nameTokens.isEmpty) return null;
    final name = _capitalize(nameTokens.join(' '));

    return VoiceParsedItem(name: name, quantity: quantity ?? 1, unit: unit);
  }

  static final RegExp _times = RegExp(r'^(\d+)x$');

  double? _numberValue(String t) {
    if (_number.hasMatch(t)) return double.parse(t.replaceAll(',', '.'));
    final times = _times.firstMatch(t);
    if (times != null) return double.parse(times.group(1)!);
    final direct = _lex.numberWords[t];
    if (direct != null) return direct;

    // „zweieinhalb“
    final half = _lex.halfSuffix;
    if (half != null && t.endsWith(half) && t.length > half.length) {
      final base = _lex.numberWords[t.substring(0, t.length - half.length)];
      if (base != null) return base + 0.5;
    }
    // „dreiundzwanzig“ / „twenty-three“
    final joiner = _lex.compoundJoiner;
    if (joiner != null && _lex.compoundTens.isNotEmpty) {
      if (joiner == '-') {
        final parts = t.split('-');
        if (parts.length == 2) {
          final tens = _lex.compoundTens[parts[0]];
          final ones = _lex.numberWords[parts[1]];
          if (tens != null && ones != null && ones < 10) return tens + ones;
        }
      } else {
        for (final entry in _lex.compoundTens.entries) {
          final suffix = joiner + entry.key;
          if (t.endsWith(suffix) && t.length > suffix.length) {
            final ones =
                _lex.numberWords[t.substring(0, t.length - suffix.length)];
            if (ones != null && ones < 10) return entry.value + ones;
          }
        }
      }
    }
    return null;
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

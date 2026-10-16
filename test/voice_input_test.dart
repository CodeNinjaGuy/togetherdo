/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Tests für die Spracheingabe: Zerleger (Deutsch, Englisch, Rückfall) und
// das Vorausfüllen des Artikel-Sheets.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/services/speech_service.dart';
import 'package:togetherdo/services/voice_item_parser.dart';
import 'package:togetherdo/utils/app_theme.dart';
import 'package:togetherdo/widgets/shopping/shopping_item_sheet.dart';
import 'package:togetherdo/widgets/shopping/voice_input_sheet.dart';

VoiceParsedItem it(String name, [double q = 1, VoiceUnit? u]) =>
    VoiceParsedItem(name: name, quantity: q, unit: u);

Widget _app(Widget child, {Locale locale = const Locale('de', 'DE')}) {
  return MaterialApp(
    theme: AppTheme.of('Light'),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  group('Zerleger Deutsch', () {
    final p = VoiceItemParser.forLanguage('de');

    final cases = <String, List<VoiceParsedItem>>{
      '2 kg Tomaten': [it('Tomaten', 2, VoiceUnit.kg)],
      '2kg Tomaten': [it('Tomaten', 2, VoiceUnit.kg)],
      'zwei Kilo Tomaten': [it('Tomaten', 2, VoiceUnit.kg)],
      'Tomaten 2 Kilo': [it('Tomaten', 2, VoiceUnit.kg)],
      'Tomaten zwei Kilo': [it('Tomaten', 2, VoiceUnit.kg)],
      'Kilo Tomaten': [it('Tomaten', 1, VoiceUnit.kg)],
      'Milch': [it('Milch')],
      'drei Äpfel': [it('Äpfel', 3)],
      '3 Äpfel': [it('Äpfel', 3)],
      'ein Liter Milch': [it('Milch', 1, VoiceUnit.l)],
      'eine Flasche Wasser': [it('Wasser', 1, VoiceUnit.bottle)],
      'einen Bund Petersilie': [it('Petersilie', 1, VoiceUnit.bunch)],
      '500 g Hackfleisch': [it('Hackfleisch', 500, VoiceUnit.g)],
      '500 Gramm Hackfleisch': [it('Hackfleisch', 500, VoiceUnit.g)],
      '1,5 Liter Milch': [it('Milch', 1.5, VoiceUnit.l)],
      '1.5 Liter Milch': [it('Milch', 1.5, VoiceUnit.l)],
      'eineinhalb Liter Milch': [it('Milch', 1.5, VoiceUnit.l)],
      'anderthalb Kilo Mehl': [it('Mehl', 1.5, VoiceUnit.kg)],
      'zweieinhalb Kilo Kartoffeln': [it('Kartoffeln', 2.5, VoiceUnit.kg)],
      'zwei und ein halb Kilo Kartoffeln': [
        it('Kartoffeln', 2.5, VoiceUnit.kg),
      ],
      'ein halbes Kilo Butter': [it('Butter', 0.5, VoiceUnit.kg)],
      'halbes Kilo Butter': [it('Butter', 0.5, VoiceUnit.kg)],
      'halber Liter Sahne': [it('Sahne', 0.5, VoiceUnit.l)],
      'zwölf Eier': [it('Eier', 12)],
      'ein Dutzend Eier': [it('Eier', 12)],
      'zwanzig Brötchen': [it('Brötchen', 20)],
      'dreiundzwanzig Brötchen': [it('Brötchen', 23)],
      '3 Dosen Mais': [it('Mais', 3, VoiceUnit.can)],
      '2 Packungen Nudeln': [it('Nudeln', 2, VoiceUnit.pack)],
      'zwei Pkg Nudeln': [it('Nudeln', 2, VoiceUnit.pack)],
      'ein Becher Joghurt': [it('Joghurt', 1, VoiceUnit.cup)],
      'zwei Gläser Honig': [it('Honig', 2, VoiceUnit.jar)],
      'eine Tüte Chips': [it('Chips', 1, VoiceUnit.bag)],
      'zwei Köpfe Salat': [it('Salat', 2, VoiceUnit.head)],
      '4 Stück Bananen': [it('Bananen', 4, VoiceUnit.piece)],
      '3x Milch': [it('Milch', 3)],
      'bitte noch 2 Liter Milch': [it('Milch', 2, VoiceUnit.l)],
      '2 kg Tomaten und 1 Liter Milch': [
        it('Tomaten', 2, VoiceUnit.kg),
        it('Milch', 1, VoiceUnit.l),
      ],
      'zwei Kilo Tomaten, ein Liter Milch und sechs Eier': [
        it('Tomaten', 2, VoiceUnit.kg),
        it('Milch', 1, VoiceUnit.l),
        it('Eier', 6),
      ],
      'Eier, Butter, Brot': [it('Eier'), it('Butter'), it('Brot')],
      'Brot und Butter': [it('Brot'), it('Butter')],
      'Olivenöl extra vergine': [it('Olivenöl extra vergine')],
      '2 Liter Milch.': [it('Milch', 2, VoiceUnit.l)],
      'Zwei Kilo Tomaten!': [it('Tomaten', 2, VoiceUnit.kg)],
      '': <VoiceParsedItem>[],
      'und': <VoiceParsedItem>[],
    };

    cases.forEach((input, expected) {
      test('„$input“', () => expect(p.parse(input), expected));
    });
  });

  group('Zerleger Englisch', () {
    final p = VoiceItemParser.forLanguage('en-US');

    final cases = <String, List<VoiceParsedItem>>{
      '2 kg tomatoes': [it('Tomatoes', 2, VoiceUnit.kg)],
      'two kilos of tomatoes': [it('Tomatoes', 2, VoiceUnit.kg)],
      'tomatoes 2 kilos': [it('Tomatoes', 2, VoiceUnit.kg)],
      'a liter of milk': [it('Milk', 1, VoiceUnit.l)],
      'a litre of milk': [it('Milk', 1, VoiceUnit.l)],
      'an apple': [it('Apple')],
      'half a kilo of butter': [it('Butter', 0.5, VoiceUnit.kg)],
      'one and a half liters of milk': [it('Milk', 1.5, VoiceUnit.l)],
      'two and a half kilos of potatoes': [it('Potatoes', 2.5, VoiceUnit.kg)],
      '1.5 l milk': [it('Milk', 1.5, VoiceUnit.l)],
      'a dozen eggs': [it('Eggs', 12)],
      'twelve eggs': [it('Eggs', 12)],
      'twenty-three rolls': [it('Rolls', 23)],
      '3 cans of beans': [it('Beans', 3, VoiceUnit.can)],
      'two bottles of water': [it('Water', 2, VoiceUnit.bottle)],
      'a bunch of parsley': [it('Parsley', 1, VoiceUnit.bunch)],
      'a jar of honey': [it('Honey', 1, VoiceUnit.jar)],
      'two cups of yogurt': [it('Yogurt', 2, VoiceUnit.cup)],
      '500 grams of ground beef': [it('Ground beef', 500, VoiceUnit.g)],
      'please add 2 packs of pasta': [it('Add pasta', 2, VoiceUnit.pack)],
      '2 kg tomatoes and 1 liter of milk': [
        it('Tomatoes', 2, VoiceUnit.kg),
        it('Milk', 1, VoiceUnit.l),
      ],
      'eggs, butter and bread': [it('Eggs'), it('Butter'), it('Bread')],
      'milk': [it('Milk')],
    };

    cases.forEach((input, expected) {
      test('“$input”', () => expect(p.parse(input), expected));
    });
  });

  group('Zerleger Rückfall (andere Sprachen)', () {
    final p = VoiceItemParser.forLanguage('fr');
    test('Ziffer + Name, Kommas trennen', () {
      expect(p.parse('2 tomates'), [it('Tomates', 2)]);
      expect(p.parse('lait, 3 pommes'), [it('Lait'), it('Pommes', 3)]);
      // Zahlwörter und Einheiten anderer Sprachen bleiben Teil des Namens.
      expect(p.parse('deux kilos de tomates'), [it('Deux kilos de tomates')]);
    });
  });

  group('Spracheingabe-Oberfläche', () {
    testWidgets('Drehbuch → Live-Text → Einträge → übernehmen', (tester) async {
      List<ShoppingItemDraft>? result;
      final speech = FakeSpeechService(
        script: '2 Kilo Tomaten und ein Liter Milch',
        wordDelay: const Duration(milliseconds: 50),
      );
      await tester.pumpWidget(
        _app(
          VoiceInputPanel(
            speech: speech,
            addDirectly: true,
            onDone: (d) => result = d,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      await tester.pump(const Duration(milliseconds: 200));
      expect(speech.startedLocales, ['de_DE']);
      expect(find.text('Ich höre zu …'), findsNothing);
      expect(find.textContaining('2 Kilo'), findsWidgets);

      // Zu Ende sprechen lassen.
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Tomaten'), findsOneWidget);
      expect(find.text('Milch'), findsOneWidget);
      expect(find.text('2 Artikel hinzufügen'), findsOneWidget);

      // Einen Eintrag entfernen, dann übernehmen.
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('1 Artikel hinzufügen'), findsOneWidget);
      await tester.tap(find.text('1 Artikel hinzufügen'));
      await tester.pump();

      expect(result, hasLength(1));
      expect(result!.single.name, 'Milch');
      expect(result!.single.quantity, 1);
      expect(result!.single.unit, 'l');
    });

    testWidgets('Mikrofon im Sheet füllt Name, Menge und Einheit', (
      tester,
    ) async {
      ShoppingItemDraft? saved;
      await tester.pumpWidget(
        _app(
          ShoppingItemForm(
            initial: const ShoppingItemDraft(),
            onSubmit: (d) => saved = d,
            onVoice: () async => const ShoppingItemDraft(
              name: 'Tomaten',
              quantity: 2,
              unit: 'kg',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Tomaten'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();
      expect(saved?.name, 'Tomaten');
      expect(saved?.quantity, 2);
      expect(saved?.unit, 'kg');
    });

    testWidgets('verweigert → Hinweis mit Einstellungen', (tester) async {
      await tester.pumpWidget(
        _app(
          VoiceInputPanel(
            speech: FakeSpeechService(
              script: '',
              status: SpeechStartStatus.permissionDenied,
            ),
            onDone: (_) {},
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Mikrofon nicht erlaubt'), findsOneWidget);
    });

    testWidgets('englisch: Einheit übersetzt', (tester) async {
      List<ShoppingItemDraft>? result;
      await tester.pumpWidget(
        _app(
          VoiceInputPanel(
            speech: FakeSpeechService(
              script: 'two bottles of water',
              wordDelay: const Duration(milliseconds: 20),
            ),
            onDone: (d) => result = d,
          ),
          locale: const Locale('en', 'US'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Use 1 entry'), findsOneWidget);
      await tester.tap(find.text('Use 1 entry'));
      await tester.pump();
      expect(result!.single.unit, 'Bottle');
      expect(result!.single.quantity, 2);
    });
  });
}

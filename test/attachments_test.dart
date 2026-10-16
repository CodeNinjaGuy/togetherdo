/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:togetherdo/design/attachments/td_attachments.dart';
import 'package:togetherdo/design/td_design.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/models/anhang_model.dart';
import 'package:togetherdo/utils/app_theme.dart';

Uint8List _png(int w, int h, {bool alpha = false}) {
  final bild = img.Image(width: w, height: h, numChannels: alpha ? 4 : 3);
  img.fill(bild, color: img.ColorRgba8(40, 120, 200, alpha ? 128 : 255));
  return Uint8List.fromList(img.encodePng(bild));
}

Uint8List _jpg(int w, int h) {
  final bild = img.Image(width: w, height: h);
  img.fill(bild, color: img.ColorRgb8(200, 80, 40));
  return Uint8List.fromList(img.encodeJpg(bild, quality: 80));
}

bool _istJpeg(Uint8List b) => b.length > 3 && b[0] == 0xFF && b[1] == 0xD8;

Widget _wrap(
  Widget child, {
  Size size = const Size(390, 844),
  String theme = 'Light',
}) {
  return MediaQuery(
    data: MediaQueryData(size: size),
    child: MaterialApp(
      theme: AppTheme.of(theme),
      locale: const Locale('de'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(body: child),
    ),
  );
}

Anhang _bild(String id, {String von = 'u1'}) => Anhang(
  id: id,
  name: 'foto-$id.jpg',
  typ: 'image/jpeg',
  groesse: 123456,
  pfad: 'termine/L1/T1/$id',
  vorschauPfad: 'termine/L1/T1/${id}_vorschau.jpg',
  hochgeladenVon: von,
  hochgeladenAm: DateTime.utc(2026, 10, 16),
);

Anhang _pdf(String id, {String von = 'u1'}) => Anhang(
  id: id,
  name: 'rechnung-$id.pdf',
  typ: 'application/pdf',
  groesse: 2 * 1024 * 1024 + 100,
  pfad: 'termine/L1/T1/$id',
  hochgeladenVon: von,
  hochgeladenAm: DateTime.utc(2026, 10, 16),
);

FakeAttachmentService _fakeMitBildern(List<Anhang> anhaenge) {
  final s = FakeAttachmentService(bilderVerarbeiten: false);
  final klein = _jpg(8, 8);
  for (final a in anhaenge) {
    s.dateien[a.pfad] = klein;
    if (a.vorschauPfad != null) s.dateien[a.vorschauPfad!] = klein;
  }
  return s;
}

void main() {
  setUpAll(() {
    TdTypography.useGoogleFonts = false;
  });

  group('Bildfunktionen', () {
    test('bildVerkleinern: längste Seite 2048, JPEG, Seitenverhältnis', () {
      final out = bildVerkleinern(_png(2500, 1250))!;
      expect(_istJpeg(out), isTrue);
      final d = img.decodeImage(out)!;
      expect(d.width, 2048);
      expect(d.height, 1024);
    });

    test('bildVerkleinern: Hochformat und kleine Bilder bleiben', () {
      final hoch = img.decodeImage(bildVerkleinern(_png(1000, 3000))!)!;
      expect(hoch.width, 683);
      expect(hoch.height, 2048);
      final klein = img.decodeImage(bildVerkleinern(_png(300, 200))!)!;
      expect(klein.width, 300);
      expect(klein.height, 200);
    });

    test('bildVerkleinern: Transparenz wird zu JPEG ohne Alpha', () {
      final out = bildVerkleinern(_png(50, 50, alpha: true))!;
      expect(_istJpeg(out), isTrue);
      expect(img.decodeImage(out)!.hasAlpha, isFalse);
    });

    test('vorschauErzeugen: längste Seite 400', () {
      final d = img.decodeImage(vorschauErzeugen(_png(2500, 1250))!)!;
      expect(d.width, 400);
      expect(d.height, 200);
    });

    test('bildUndVorschau liefert beides, Vorschau kleiner als Bild', () {
      final e = bildUndVorschau(_png(1600, 1200))!;
      expect(img.decodeImage(e.bild)!.width, 1600);
      expect(img.decodeImage(e.vorschau)!.width, 400);
      expect(e.vorschau.length, lessThan(e.bild.length));
    });

    test('unlesbare Daten ergeben null', () {
      final muell = Uint8List.fromList(List.filled(64, 7));
      expect(bildVerkleinern(muell), isNull);
      expect(vorschauErzeugen(muell), isNull);
      expect(bildUndVorschau(muell), isNull);
    });
  });

  group('Grenzen und Fehlerklassen', () {
    test('Konstanten', () {
      expect(AnhangGrenzen.maxBildBytes, 10 * 1024 * 1024);
      expect(AnhangGrenzen.maxDokumentBytes, 20 * 1024 * 1024);
      expect(AnhangGrenzen.maxAnzahl, 20);
      expect(AnhangGrenzen.dokumentErweiterungen, contains('ics'));
      expect(AnhangGrenzen.dokumentMimeTypen, contains('application/pdf'));
    });

    test('Bild zu groß', () {
      final a = AnhangAuswahl(
        bytes: Uint8List(AnhangGrenzen.maxBildBytes + 1),
        name: 'x.jpg',
        mime: 'image/jpeg',
      );
      expect(
        () => anhangPruefen(a),
        throwsA(
          isA<AnhangZuGross>()
              .having((e) => e.maxGroesse, 'max', AnhangGrenzen.maxBildBytes)
              .having((e) => e.name, 'name', 'x.jpg'),
        ),
      );
    });

    test('PDF darf größer sein als ein Bild, aber nicht über 20 MB', () {
      final mittel = AnhangAuswahl(
        bytes: Uint8List(AnhangGrenzen.maxBildBytes + 1),
        name: 'a.pdf',
        mime: 'application/pdf',
      );
      expect(() => anhangPruefen(mittel), returnsNormally);
      final gross = AnhangAuswahl(
        bytes: Uint8List(AnhangGrenzen.maxDokumentBytes + 1),
        name: 'b.pdf',
        mime: 'application/pdf',
      );
      expect(() => anhangPruefen(gross), throwsA(isA<AnhangZuGross>()));
    });

    test('falscher Typ', () {
      final a = AnhangAuswahl(
        bytes: Uint8List(10),
        name: 'x.zip',
        mime: 'application/zip',
      );
      expect(
        () => anhangPruefen(a),
        throwsA(
          isA<AnhangTypUnzulaessig>().having(
            (e) => e.mime,
            'mime',
            'application/zip',
          ),
        ),
      );
    });

    test('Anzahlgrenze', () {
      expect(() => anhangAnzahlPruefen(19), returnsNormally);
      expect(
        () => anhangAnzahlPruefen(20),
        throwsA(isA<AnhangLimitErreicht>()),
      );
      expect(
        () => anhangAnzahlPruefen(18, neu: 3),
        throwsA(isA<AnhangLimitErreicht>()),
      );
    });

    test('MIME aus Dateiname, Name bereinigen', () {
      expect(AnhangGrenzen.mimeAusName('Plan.PDF'), 'application/pdf');
      expect(AnhangGrenzen.mimeAusName('kalender.ics'), 'text/calendar');
      expect(AnhangGrenzen.mimeAusName('bild.jpeg'), 'image/jpeg');
      expect(AnhangGrenzen.mimeAusName('ohne'), 'application/octet-stream');
      expect(anhangNameBereinigen(' a/b:c.pdf '), 'a_b_c.pdf');
      expect(anhangNameBereinigen(''), 'datei');
      expect(anhangNameBereinigen('${'x' * 200}.pdf').length, 120);
    });

    test('Cache verdrängt die ältesten Einträge', () {
      final c = AnhangCache(maxBytes: 100);
      c.put('a', Uint8List(40));
      c.put('b', Uint8List(40));
      expect(c.get('a'), isNotNull); // a wird „frisch“
      c.put('c', Uint8List(40)); // b fliegt
      expect(c.get('b'), isNull);
      expect(c.get('a'), isNotNull);
      expect(c.get('c'), isNotNull);
      expect(c.groesse, 80);
      c.put('riesig', Uint8List(200)); // passt nie, wird nicht gehalten
      expect(c.get('riesig'), isNull);
    });
  });

  group('FakeAttachmentService', () {
    test(
      'Upload eines Bilds: Fortschritt steigt, fertiges Anhang-Objekt',
      () async {
        final s = FakeAttachmentService();
        final auswahl = AnhangAuswahl(
          bytes: _png(900, 600),
          name: 'Urlaub.png',
          mime: 'image/png',
        );
        final ereignisse = await s
            .hochladen(basisPfad: 'termine/L1/T1', datei: auswahl, userId: 'u1')
            .toList();
        expect(ereignisse.length, greaterThanOrEqualTo(3));
        for (var i = 1; i < ereignisse.length; i++) {
          expect(
            ereignisse[i].fortschritt,
            greaterThanOrEqualTo(ereignisse[i - 1].fortschritt),
          );
          expect(ereignisse[i - 1].istFertig, isFalse);
        }
        final letztes = ereignisse.last;
        expect(letztes.fortschritt, 1);
        expect(letztes.istFertig, isTrue);
        final a = letztes.fertig!;
        expect(a.id, letztes.anhangId);
        expect(a.pfad, 'termine/L1/T1/${a.id}');
        expect(a.vorschauPfad, 'termine/L1/T1/${a.id}_vorschau.jpg');
        expect(a.typ, 'image/jpeg');
        expect(a.hochgeladenVon, 'u1');
        expect(a.istBild, isTrue);
        expect(s.dateien[a.pfad], isNotNull);
        expect(s.dateien[a.vorschauPfad!], isNotNull);
        expect(a.groesse, s.dateien[a.pfad]!.length);
        expect(await s.laden(a.pfad), s.dateien[a.pfad]);
      },
    );

    test('Upload eines PDFs: keine Vorschau, Bytes unverändert', () async {
      final s = FakeAttachmentService();
      final bytes = Uint8List.fromList(List.generate(500, (i) => i % 256));
      final letztes = await s
          .hochladen(
            basisPfad: 'todos/L1/X1',
            datei: AnhangAuswahl(
              bytes: bytes,
              name: 'Angebot.pdf',
              mime: 'application/pdf',
            ),
            userId: 'u2',
          )
          .last;
      final a = letztes.fertig!;
      expect(a.istPdf, isTrue);
      expect(a.vorschauPfad, isNull);
      expect(a.pfad, startsWith('todos/L1/X1/'));
      expect(a.groesse, 500);
      expect(s.dateien[a.pfad], bytes);
    });

    test('Upload bricht bei Grenzverletzung mit Fehlerklasse ab', () {
      final s = FakeAttachmentService();
      final zuGross = AnhangAuswahl(
        bytes: Uint8List(AnhangGrenzen.maxBildBytes + 1),
        name: 'x.jpg',
        mime: 'image/jpeg',
      );
      expect(
        s.hochladen(basisPfad: 'termine/L1/T1', datei: zuGross, userId: 'u'),
        emitsError(isA<AnhangZuGross>()),
      );
      final falsch = AnhangAuswahl(
        bytes: Uint8List(5),
        name: 'x.exe',
        mime: 'application/x-msdownload',
      );
      expect(
        s.hochladen(basisPfad: 'termine/L1/T1', datei: falsch, userId: 'u'),
        emitsError(isA<AnhangTypUnzulaessig>()),
      );
    });

    test(
      'loeschen entfernt Datei und Vorschau, teilen/öffnen protokolliert',
      () async {
        final a = _bild('a1');
        final s = _fakeMitBildern([a]);
        await s.teilen(a);
        await s.oeffnen(a);
        await s.loeschen(a);
        expect(s.geteilt, [a]);
        expect(s.geoeffnet, [a]);
        expect(s.geloescht, [a]);
        expect(s.dateien, isEmpty);
      },
    );
  });

  group('TdAnhangGalerie', () {
    testWidgets('zeigt Kacheln, laufenden Upload und Plus', (tester) async {
      final anhaenge = [_bild('a1'), _pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      var plus = 0;
      await tester.pumpWidget(
        _wrap(
          TdAnhangGalerie(
            anhaenge: anhaenge,
            service: s,
            laufend: const {
              'up1': UploadFortschritt(
                anhangId: 'up1',
                name: 'neu.jpg',
                fortschritt: 0.42,
              ),
            },
            onHinzufuegen: () => plus++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TdAnhangBild), findsOneWidget);
      expect(find.text('rechnung-p1.pdf'), findsOneWidget);
      expect(find.text('2,0 MB'), findsOneWidget);
      expect(find.byType(TdRingProgress), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('Anhang hinzufügen'), findsOneWidget);

      await tester.tap(find.text('Anhang hinzufügen'));
      await tester.pump();
      expect(plus, 1);
    });

    testWidgets(
      'ohne onHinzufuegen keine Plus-Kachel; voll = keine Plus-Kachel',
      (tester) async {
        final s = _fakeMitBildern([]);
        await tester.pumpWidget(
          _wrap(TdAnhangGalerie(anhaenge: const [], service: s)),
        );
        await tester.pumpAndSettle();
        expect(find.text('Anhang hinzufügen'), findsNothing);

        final viele = [for (var i = 0; i < 20; i++) _pdf('p$i')];
        await tester.pumpWidget(
          _wrap(
            TdAnhangGalerie(anhaenge: viele, service: s, onHinzufuegen: () {}),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Anhang hinzufügen'), findsNothing);
      },
    );

    testWidgets('Antippen öffnet das Vollbild', (tester) async {
      final anhaenge = [_pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      await tester.pumpWidget(
        _wrap(TdAnhangGalerie(anhaenge: anhaenge, service: s)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('rechnung-p1.pdf'));
      await tester.pumpAndSettle();
      expect(find.byType(TdAnhangVollbild), findsOneWidget);
      expect(find.text('Öffnen'), findsWidgets);
    });
  });

  group('TdAnhangListe', () {
    testWidgets('Zeilen mit Name, Typ und Größe; Menü ohne Löschen', (
      tester,
    ) async {
      final anhaenge = [_bild('a1'), _pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      await tester.pumpWidget(
        _wrap(TdAnhangListe(anhaenge: anhaenge, service: s)),
      );
      await tester.pumpAndSettle();
      expect(find.text('foto-a1.jpg'), findsOneWidget);
      expect(find.text('Bild · 121 kB'), findsOneWidget);
      expect(find.text('PDF · 2,0 MB'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_horiz_rounded).last);
      await tester.pumpAndSettle();
      expect(find.text('Öffnen'), findsOneWidget);
      expect(find.text('Teilen'), findsOneWidget);
      expect(find.text('Löschen'), findsNothing);
      await tester.tap(find.text('Teilen'));
      await tester.pumpAndSettle();
      expect(s.geteilt, [anhaenge[1]]);
    });
  });

  group('TdAnhangVollbild', () {
    testWidgets('Löschen-Knopf nur mit Erlaubnis', (tester) async {
      final anhaenge = [_bild('a1'), _pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      await tester.pumpWidget(
        _wrap(TdAnhangVollbild(anhaenge: anhaenge, service: s)),
      );
      await tester.pumpAndSettle();
      expect(find.text('foto-a1.jpg'), findsOneWidget);
      expect(find.text('1 von 2'), findsOneWidget);
      expect(find.text('Teilen'), findsOneWidget);
      expect(find.text('Löschen'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          TdAnhangVollbild(
            anhaenge: anhaenge,
            service: s,
            darfLoeschen: (a) => a.hochgeladenVon == 'u1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Löschen'), findsOneWidget);
    });

    testWidgets('Löschen fragt nach, löscht im Service und meldet', (
      tester,
    ) async {
      final anhaenge = [_bild('a1'), _pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      final geloescht = <Anhang>[];
      await tester.pumpWidget(
        _wrap(
          TdAnhangVollbild(
            anhaenge: anhaenge,
            service: s,
            darfLoeschen: (_) => true,
            onLoeschen: geloescht.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      expect(find.text('„foto-a1.jpg“ wirklich löschen?'), findsOneWidget);
      await tester.tap(find.text('Abbrechen'));
      await tester.pumpAndSettle();
      expect(s.geloescht, isEmpty);

      await tester.tap(find.text('Löschen'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
      await tester.pumpAndSettle();
      expect(s.geloescht, [anhaenge[0]]);
      expect(geloescht, [anhaenge[0]]);
      // Der nächste Anhang wird gezeigt (Leiste und Dokumentkachel).
      expect(find.text('foto-a1.jpg'), findsNothing);
      expect(find.text('rechnung-p1.pdf'), findsWidgets);
      expect(find.text('1 von 2'), findsNothing);
    });

    testWidgets('Dokumentseite: Öffnen und Teilen rufen den Service', (
      tester,
    ) async {
      final anhaenge = [_pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      await tester.pumpWidget(
        _wrap(TdAnhangVollbild(anhaenge: anhaenge, service: s)),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TdButton), findsOneWidget);
      await tester.tap(find.byType(TdButton));
      await tester.pumpAndSettle();
      expect(s.geoeffnet, [anhaenge[0]]);
      await tester.tap(find.text('Teilen'));
      await tester.pumpAndSettle();
      expect(s.geteilt, [anhaenge[0]]);
    });

    testWidgets('Bildseite: Ladefehler zeigt Hinweis mit Wiederholen', (
      tester,
    ) async {
      final anhaenge = [_bild('a1')];
      final s = _fakeMitBildern(anhaenge)..ladeFehler = StateError('weg');
      await tester.pumpWidget(
        _wrap(TdAnhangVollbild(anhaenge: anhaenge, service: s)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Anhang konnte nicht geladen werden'), findsOneWidget);
      s.ladeFehler = null;
      await tester.tap(find.text('Erneut versuchen'));
      // Die Bildseite kennt Doppeltipp (Zoom); der Einzeltipp gilt erst
      // nach der Doppeltipp-Frist.
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(find.text('Anhang konnte nicht geladen werden'), findsNothing);
      expect(find.byType(InteractiveViewer), findsOneWidget);
    });

    testWidgets('dunkles Theme und iPad-Breite bauen ohne Fehler', (
      tester,
    ) async {
      final anhaenge = [_bild('a1'), _pdf('p1')];
      final s = _fakeMitBildern(anhaenge);
      await tester.pumpWidget(
        _wrap(
          Column(
            children: [
              TdAnhangGalerie(
                anhaenge: anhaenge,
                service: s,
                onHinzufuegen: () {},
              ),
              Expanded(
                child: TdAnhangListe(anhaenge: anhaenge, service: s),
              ),
            ],
          ),
          size: const Size(1024, 1366),
          theme: 'Dark',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(TdAnhangGalerie), findsOneWidget);
    });
  });

  group('Auswahl-Blatt', () {
    testWidgets('zeigt drei Kacheln und liefert die Quelle', (tester) async {
      AnhangQuelle? ergebnis;
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => TdButton(
              label: 'Los',
              onPressed: () async {
                ergebnis = await showTdAnhangQuelleSheet(context);
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('Los'));
      await tester.pumpAndSettle();
      expect(find.text('Foto aufnehmen'), findsOneWidget);
      expect(find.text('Aus Galerie'), findsOneWidget);
      expect(find.text('Dokument'), findsOneWidget);
      await tester.tap(find.text('Dokument'));
      await tester.pumpAndSettle();
      expect(ergebnis, AnhangQuelle.dokument);
    });
  });
}

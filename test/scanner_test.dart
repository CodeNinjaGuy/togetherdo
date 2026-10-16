/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Tests für den Strichcode-Scanner: Open-Food-Facts-Antworten (gemockt),
// Zwischenspeicher-Kette, Menge erhöhen statt Duplikat, unbekannter Code,
// kein Netz, Bearbeiten-Sheet und Scanner-Bildschirm im Demo-Modus.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:togetherdo/models/product_info.dart';
import 'package:togetherdo/models/shopping_item_model.dart';
import 'package:togetherdo/repositories/product_repository.dart';
import 'package:togetherdo/repositories/shopping_repository.dart';
import 'package:togetherdo/screens/shopping/barcode_scanner_screen.dart';
import 'package:togetherdo/services/product_lookup_service.dart';
import 'package:togetherdo/services/scanner_session.dart';
import 'package:togetherdo/utils/app_theme.dart';
import 'package:togetherdo/widgets/shopping/shopping_item_sheet.dart';
import 'package:togetherdo/widgets/shopping/shopping_item_widget.dart';

const nutellaEan = '3017620422003';
const offBody = {
  'status': 1,
  'product': {
    'product_name': 'Nutella',
    'product_name_de': 'Nutella Nuss-Nougat-Creme',
    'brands': 'Ferrero, Nutella',
    'quantity': '400 g',
    'image_front_small_url':
        'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_de.200.jpg',
  },
};

http.Response _json(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json; charset=utf-8'},
    );

ProductLookupService _service(
  MockClient client, {
  Duration timeout = const Duration(seconds: 2),
}) =>
    ProductLookupService(client: client, appVersion: '9.9.9', timeout: timeout);

ProductInfo _product({String ean = nutellaEan, String name = 'Nutella'}) =>
    ProductInfo(
      ean: ean,
      name: name,
      brand: 'Ferrero',
      quantity: '400 g',
      imageUrl: 'https://images.openfoodfacts.org/n.jpg',
      source: ProductSource.off,
      updatedAt: DateTime(2026, 10, 16),
    );

Widget _app(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: AppTheme.of(brightness == Brightness.dark ? 'Dark' : 'Light'),
    locale: const Locale('de', 'DE'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('de', 'DE'), Locale('en', 'US')],
    home: child,
  );
}

/// Scanner-Sitzung für Tests: feste Antworten je Code.
class _FakeSession implements ScannerSession {
  final Map<String, ProductLookupResult> answers = {};
  final List<(ProductInfo, double)> added = [];
  final List<String> remembered = [];
  ScanAddOutcome outcome = ScanAddOutcome.added;

  @override
  Future<ProductLookupResult> lookup(String ean) async =>
      answers[ean] ?? const ProductLookupResult.unknown();

  @override
  Future<ScanAddOutcome> addToList(ProductInfo product, double quantity) async {
    added.add((product, quantity));
    return outcome;
  }

  @override
  Future<ProductInfo> rememberProduct({
    required String ean,
    required String name,
    String? brand,
    String? packageSize,
  }) async {
    remembered.add('$ean=$name');
    return ProductInfo(
      ean: ean,
      name: name,
      brand: brand,
      quantity: packageSize,
      source: ProductSource.nutzer,
      updatedAt: DateTime(2026),
    );
  }
}

/// Der Scanner animiert die Scan-Linie endlos, `pumpAndSettle` würde nie
/// enden – daher feste Frames.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('User-Agent ist ein gültiger HTTP-Header (nur ASCII)', () {
    final ua = ProductLookupService(appVersion: '1.3.0').userAgent;
    expect(ua.codeUnits.every((c) => c >= 0x20 && c < 0x7f), isTrue, reason: ua);
  });

  group('Open-Facts-Antwort lesen', () {
    test('deutscher Name, erste Marke, Menge und Bild', () {
      final p = ProductLookupService.parseProduct(
        offBody,
        ean: nutellaEan,
        source: ProductSource.off,
        now: DateTime(2026),
      )!;
      expect(p.name, 'Nutella Nuss-Nougat-Creme');
      expect(p.brand, 'Ferrero');
      expect(p.quantity, '400 g');
      expect(p.imageUrl, startsWith('https://images.openfoodfacts.org/'));
      expect(p.source, ProductSource.off);
      expect(p.detailLine, 'Ferrero · 400 g');
    });

    test('ohne Namen oder mit status 0 kein Produkt', () {
      expect(
        ProductLookupService.parseProduct(
          {'status': 0, 'status_verbose': 'product not found'},
          ean: nutellaEan,
          source: ProductSource.off,
        ),
        isNull,
      );
      expect(
        ProductLookupService.parseProduct(
          {
            'status': 1,
            'product': {'brands': 'X'},
          },
          ean: nutellaEan,
          source: ProductSource.off,
        ),
        isNull,
      );
    });

    test('Bild nur mit https und zu lange Texte gekürzt', () {
      final p = ProductLookupService.parseProduct(
        {
          'status': 1,
          'product': {
            'product_name': 'A' * 300,
            'image_front_small_url': 'http://unsicher.test/a.jpg',
          },
        },
        ean: nutellaEan,
        source: ProductSource.off,
      )!;
      expect(p.name.length, ProductInfo.maxTextLength);
      expect(p.imageUrl, isNull);
    });

    test('Firestore-Form hin und zurück', () {
      final p = _product();
      final back = ProductInfo.fromJson(p.toJson());
      expect(back, p);
      expect(p.toJson()['quelle'], 'off');
      expect(p.toJson()['marke'], 'Ferrero');
    });

    test('gültige Strichcodes', () {
      expect(ProductInfo.isValidEan('40084002'), isTrue);
      expect(ProductInfo.isValidEan('012345678905'), isTrue);
      expect(ProductInfo.isValidEan(nutellaEan), isTrue);
      expect(ProductInfo.isValidEan('abc'), isFalse);
      expect(ProductInfo.isValidEan('1234567'), isFalse);
    });
  });

  group('Produktsuche mit Rückfall', () {
    test('sendet eigenen User-Agent und liest Open Food Facts', () async {
      String? agent;
      final client = MockClient((req) async {
        agent = req.headers['User-Agent'];
        expect(req.url.host, 'world.openfoodfacts.org');
        expect(req.url.path, '/api/v2/product/$nutellaEan');
        expect(req.url.queryParameters['fields'], contains('product_name_de'));
        return _json(offBody);
      });
      final p = await _service(client).lookup(nutellaEan);
      expect(p?.name, 'Nutella Nuss-Nougat-Creme');
      expect(agent, 'ToGetherDo/9.9.9 (https://seebubble.me)');
    });

    test(
      'unbekannt bei OFF → Open Beauty Facts → Open Products Facts',
      () async {
        final hosts = <String>[];
        final client = MockClient((req) async {
          hosts.add(req.url.host);
          if (req.url.host == 'world.openproductsfacts.org') {
            return _json({
              'status': 1,
              'product': {'product_name': 'Glühbirne', 'brands': 'Osram'},
            });
          }
          return _json({'status': 0}, 404);
        });
        final p = await _service(client).lookup('4008321000000');
        expect(hosts, [
          'world.openfoodfacts.org',
          'world.openbeautyfacts.org',
          'world.openproductsfacts.org',
        ]);
        expect(p?.name, 'Glühbirne');
        expect(p?.source, ProductSource.opf);
      },
    );

    test('überall unbekannt → null', () async {
      final client = MockClient((_) async => _json({'status': 0}, 404));
      expect(await _service(client).lookup(nutellaEan), isNull);
    });

    test('kein Netz → ProductLookupException(offline)', () async {
      final client = MockClient(
        (_) async => throw const SocketException('offline'),
      );
      expect(
        () => _service(client).lookup(nutellaEan),
        throwsA(
          isA<ProductLookupException>().having(
            (e) => e.isOffline,
            'offline',
            isTrue,
          ),
        ),
      );
    });

    test('Zeitlimit zählt als kein Netz', () async {
      final client = MockClient((_) async {
        await Future.delayed(const Duration(milliseconds: 200));
        return _json(offBody);
      });
      expect(
        () => _service(
          client,
          timeout: const Duration(milliseconds: 20),
        ).lookup(nutellaEan),
        throwsA(
          isA<ProductLookupException>().having(
            (e) => e.isOffline,
            'offline',
            isTrue,
          ),
        ),
      );
    });

    test('Serverfehler bei OFF, Treffer bei OBF', () async {
      final client = MockClient((req) async {
        if (req.url.host == 'world.openfoodfacts.org') {
          return http.Response('kaputt', 500);
        }
        return _json({
          'status': 1,
          'product': {'product_name': 'Shampoo'},
        });
      });
      final p = await _service(client).lookup(nutellaEan);
      expect(p?.name, 'Shampoo');
      expect(p?.source, ProductSource.obf);
    });
  });

  group('Zwischenspeicher-Kette', () {
    late InMemoryProductStore store;
    late int netCalls;
    late ProductRepository repo;

    ProductRepository build(MockClient client) => ProductRepository(
      store: store,
      lookupService: _service(client),
      localCache: ProductLocalCache(),
      now: () => DateTime(2026, 10, 16),
    );

    setUp(() {
      store = InMemoryProductStore();
      netCalls = 0;
    });

    test(
      'Netz-Treffer landet in Firestore und im Gerät; zweiter Scan ohne Netz',
      () async {
        repo = build(
          MockClient((_) async {
            netCalls++;
            return _json(offBody);
          }),
        );
        final first = await repo.find(nutellaEan);
        expect(first.status, ProductLookupStatus.found);
        expect(store.writes, 1);
        expect(store.docs[nutellaEan]?['quelle'], 'off');
        expect(netCalls, 1);

        // Jetzt offline: Gerät liefert trotzdem.
        repo = build(MockClient((_) async => throw const SocketException('x')));
        final second = await repo.find(nutellaEan);
        expect(second.status, ProductLookupStatus.found);
        expect(second.product?.name, 'Nutella Nuss-Nougat-Creme');
        expect(store.reads, 1, reason: 'zweiter Scan kommt aus dem Gerät');
      },
    );

    test('Firestore-Treffer spart den Netzaufruf', () async {
      store.docs[nutellaEan] = _product(name: 'Aus Firestore').toJson();
      repo = build(
        MockClient((_) async {
          netCalls++;
          return _json(offBody);
        }),
      );
      final r = await repo.find(nutellaEan);
      expect(r.product?.name, 'Aus Firestore');
      expect(netCalls, 0);
    });

    test('unbekannt und offline werden unterschieden', () async {
      repo = build(MockClient((_) async => _json({'status': 0}, 404)));
      expect(
        (await repo.find('4008400999999')).status,
        ProductLookupStatus.unknown,
      );

      repo = build(MockClient((_) async => throw const SocketException('x')));
      expect(
        (await repo.find('4008400999998')).status,
        ProductLookupStatus.offline,
      );
      expect(store.writes, 0);
    });

    test(
      'kein Strichcode → unbekannt, ohne Netz- oder Speicherzugriff',
      () async {
        repo = build(
          MockClient((_) async {
            netCalls++;
            return _json(offBody);
          }),
        );
        expect((await repo.find('hallo')).status, ProductLookupStatus.unknown);
        expect(netCalls, 0);
        expect(store.reads, 0);
      },
    );

    test(
      'Nutzer benennt unbekannten Code → Quelle nutzer mit Urheber',
      () async {
        repo = build(MockClient((_) async => _json({'status': 0}, 404)));
        final p = await repo.rememberUserProduct(
          ean: '40084002',
          name: '  Hausmarke Müsli ',
          userId: 'u1',
          brand: '',
        );
        expect(p.name, 'Hausmarke Müsli');
        expect(p.brand, isNull);
        expect(p.source, ProductSource.nutzer);
        expect(store.docs['40084002']?['erstelltVon'], 'u1');
        expect((await repo.find('40084002')).product, p);
      },
    );
  });

  group('Menge erhöhen statt Duplikat', () {
    test('MockShoppingRepository.addOrIncrement', () async {
      final repo = MockShoppingRepository()..delay = Duration.zero;
      final a = await repo.addOrIncrement(
        name: 'Nutella',
        quantity: 1,
        unit: 'Stück',
        userId: 'u',
        listId: 'L',
        ean: nutellaEan,
      );
      final b = await repo.addOrIncrement(
        name: 'Nutella',
        quantity: 2,
        unit: 'Stück',
        userId: 'u',
        listId: 'L',
        ean: nutellaEan,
        imageUrl: 'https://img.test/n.jpg',
      );
      expect(repo.items.length, 1);
      expect(b.id, a.id);
      expect(b.quantity, 3);
      expect(
        b.imageUrl,
        'https://img.test/n.jpg',
        reason: 'fehlendes Bild nachtragen',
      );

      // Gekaufter Artikel zählt nicht mehr als Duplikat.
      await repo.updateItem(b.copyWith(isPurchased: true));
      final c = await repo.addOrIncrement(
        name: 'Nutella',
        quantity: 1,
        unit: 'Stück',
        userId: 'u',
        listId: 'L',
        ean: nutellaEan,
      );
      expect(c.id, isNot(a.id));
      expect(repo.items.length, 2);

      // Andere Liste: eigener Artikel.
      await repo.addOrIncrement(
        name: 'Nutella',
        quantity: 1,
        unit: 'Stück',
        userId: 'u',
        listId: 'M',
        ean: nutellaEan,
      );
      expect(repo.items.length, 3);
    });

    test('ListScannerSession meldet hinzugefügt bzw. erhöht', () async {
      final shopping = MockShoppingRepository()..delay = Duration.zero;
      final session = ListScannerSession(
        products: ProductRepository(
          store: InMemoryProductStore(),
          lookupService: _service(MockClient((_) async => _json(offBody))),
        ),
        shopping: shopping,
        listId: 'L',
        userId: 'u',
        defaultUnit: 'Stück',
      );
      expect(await session.addToList(_product(), 1), ScanAddOutcome.added);
      expect(
        await session.addToList(_product(), 1),
        ScanAddOutcome.incremented,
      );
      expect(shopping.items.single.quantity, 2);
      expect(shopping.items.single.ean, nutellaEan);
    });

    test('ShoppingItemModel trägt ean und imageUrl durch JSON', () {
      final item = ShoppingItemModel(
        id: 'i',
        name: 'Nutella',
        quantity: 1,
        unit: 'Stück',
        createdAt: DateTime(2026),
        userId: 'u',
        listId: 'L',
        ean: nutellaEan,
        imageUrl: 'https://img.test/n.jpg',
      );
      final back = ShoppingItemModel.fromJson(item.toJson());
      expect(back, item);
      expect(back.copyWith(clearProduct: true).ean, isNull);
      expect(item.toJson().containsKey('ean'), isTrue);
    });
  });

  group('Bearbeiten-Sheet', () {
    testWidgets('vorausgefüllt aus Produkt, liefert Entwurf', (tester) async {
      ShoppingItemDraft? result;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: ShoppingItemForm(
                initial: ShoppingItemDraft.fromProduct(_product()),
                onSubmit: (d) => result = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nutella'), findsOneWidget);
      expect(find.text('Verknüpftes Produkt'), findsOneWidget);
      expect(find.text('Code $nutellaEan'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Packung'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hinzufügen'));
      await tester.pumpAndSettle();

      expect(result, isNotNull);
      expect(result!.name, 'Nutella');
      expect(result!.quantity, 2);
      expect(result!.unit, 'Packung');
      expect(result!.ean, nutellaEan);
    });

    testWidgets('leerer Name zeigt Hinweis; Produkt entfernen leert ean', (
      tester,
    ) async {
      ShoppingItemDraft? result;
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: SingleChildScrollView(
              child: ShoppingItemForm(
                initial: const ShoppingItemDraft(
                  name: '',
                  ean: nutellaEan,
                  imageUrl: 'https://img.test/n.jpg',
                ),
                isEdit: true,
                onSubmit: (d) => result = d,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(find.text('Bitte einen Namen eingeben'), findsOneWidget);
      expect(result, isNull);

      await tester.tap(find.byIcon(Icons.link_off_rounded));
      await tester.pumpAndSettle();
      expect(find.text('Code $nutellaEan'), findsNothing);

      await tester.enterText(find.byType(TextFormField).first, 'Brot');
      await tester.tap(find.text('Speichern'));
      await tester.pumpAndSettle();
      expect(result?.name, 'Brot');
      expect(result?.ean, isNull);
      expect(result?.imageUrl, isNull);
    });
  });

  group('Artikelzeile', () {
    testWidgets('zeigt Bildplatzhalter, Menge und reagiert auf Abhaken', (
      tester,
    ) async {
      bool? toggled;
      final item = ShoppingItemModel(
        id: 'i',
        name: 'Hafermilch',
        quantity: 2,
        unit: 'l',
        createdAt: DateTime(2026),
        userId: 'u',
        listId: 'L',
        notes: 'Bio',
      );
      await tester.pumpWidget(
        _app(
          Scaffold(
            body: ShoppingItemWidget(
              item: item,
              onTogglePurchased: (v) => toggled = v,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hafermilch'), findsOneWidget);
      expect(find.text('2 l'), findsOneWidget);
      expect(find.text('Bio'), findsOneWidget);
      expect(find.byIcon(Icons.shopping_basket_outlined), findsOneWidget);

      await tester.tap(find.byIcon(Icons.check_rounded));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);
    });
  });

  group('Scanner-Bildschirm (Demo)', () {
    Future<_FakeSession> pumpScanner(
      WidgetTester tester, {
      Brightness brightness = Brightness.light,
      bool pickMode = false,
    }) async {
      final session = _FakeSession()
        ..answers[nutellaEan] = ProductLookupResult.found(_product())
        ..answers['9999999999999'] = const ProductLookupResult.offline();
      await tester.pumpWidget(
        _app(
          BarcodeScannerScreen(
            session: session,
            demo: true,
            pickMode: pickMode,
            demoCodes: const [nutellaEan, '0000000000000', '9999999999999'],
          ),
          brightness: brightness,
        ),
      );
      await tester.pump();
      return session;
    }

    testWidgets('Treffer → Karte → Hinzufügen zählt hoch', (tester) async {
      final session = await pumpScanner(tester);
      expect(find.text('Richte die Kamera auf den Strichcode'), findsOneWidget);
      expect(find.text('Noch nichts hinzugefügt'), findsOneWidget);

      await tester.tap(find.text('Demo-Treffer'));
      await settle(tester);
      expect(find.text('Nutella'), findsOneWidget);
      expect(find.text('Ferrero · 400 g'), findsOneWidget);
      expect(find.text('Daten: Open Food Facts (ODbL)'), findsWidgets);

      // Menge auf 2 und hinzufügen.
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await settle(tester);
      await tester.tap(find.text('Hinzufügen'));
      await settle(tester);

      expect(session.added.single.$2, 2);
      expect(find.text('1 Artikel hinzugefügt'), findsOneWidget);
      expect(find.text('Fertig'), findsOneWidget);
    });

    testWidgets('unbekannter Code → Artikel benennen → gemerkt', (
      tester,
    ) async {
      final session = await pumpScanner(tester);
      await tester.tap(find.text('Demo-Treffer'));
      await settle(tester);
      // zweiter Demo-Code ist unbekannt
      await tester.tap(find.text('Weiter scannen'));
      await settle(tester);
      await tester.tap(find.text('Demo-Treffer'));
      await settle(tester);

      expect(find.text('Artikel benennen'), findsOneWidget);
      expect(find.text('Code 0000000000000'), findsOneWidget);
      await tester.tap(find.text('Hinzufügen und merken'));
      await settle(tester);
      expect(find.text('Bitte einen Namen eingeben'), findsOneWidget);

      await tester.enterText(
        find.byType(TextFormField).first,
        'Hausmarke Müsli',
      );
      await tester.tap(find.text('Hinzufügen und merken'));
      await settle(tester);

      expect(session.remembered, ['0000000000000=Hausmarke Müsli']);
      expect(session.added.single.$1.name, 'Hausmarke Müsli');
      expect(session.added.single.$1.source, ProductSource.nutzer);
    });

    testWidgets('kein Netz → Karte mit Erneut versuchen', (tester) async {
      final session = await pumpScanner(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Demo-Treffer'));
        await settle(tester);
        await tester.tap(find.text('Weiter scannen'));
        await settle(tester);
      }
      await tester.tap(find.text('Demo-Treffer'));
      await settle(tester);
      expect(find.text('Kein Netz'), findsOneWidget);
      expect(find.text('Erneut versuchen'), findsOneWidget);

      // Netz ist zurück → Erneut versuchen findet das Produkt.
      session.answers['9999999999999'] = ProductLookupResult.found(
        _product(ean: '9999999999999'),
      );
      await tester.tap(find.text('Erneut versuchen'));
      await settle(tester);
      expect(find.text('Nutella'), findsOneWidget);
    });

    testWidgets('Auswahlmodus liefert Produkt zurück, dunkel', (tester) async {
      await pumpScanner(tester, brightness: Brightness.dark, pickMode: true);
      await tester.tap(find.text('Demo-Treffer'));
      await settle(tester);
      expect(find.text('Übernehmen'), findsOneWidget);
      expect(find.text('Menge'), findsNothing);
    });
  });
}

/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

// Debug-Demo der Einkaufsliste mit Scanner, ohne Firebase und ohne
// Anmeldung: Route `/design/einkauf` (nur im Debug-Build). Der Simulator
// hat keine Kamera, deshalb läuft der Scanner hier im Demo-Modus.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/theme/theme_event.dart';
import '../../design/td_design.dart';
import '../../models/product_info.dart';
import '../../models/shopping_item_model.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/shopping_repository.dart';
import '../../services/scanner_session.dart';
import '../../widgets/shopping/shopping_item_sheet.dart';
import '../../widgets/shopping/shopping_quick_actions.dart';
import 'barcode_scanner_screen.dart';
import 'shopping_screen.dart';

/// Beispielprodukte mit echten Open-Food-Facts-Bildern.
abstract final class DemoProducts {
  static final DateTime _t = DateTime(2026, 10, 16, 9);

  static final nutella = ProductInfo(
    ean: '3017620422003',
    name: 'Nutella',
    brand: 'Ferrero',
    quantity: '400 g',
    imageUrl:
        'https://images.openfoodfacts.org/images/products/301/762/042/2003/front_de.400.200.jpg',
    source: ProductSource.off,
    updatedAt: _t,
  );
  static final haferdrink = ProductInfo(
    ean: '4008400202020',
    name: 'Hafer Drink Natur',
    brand: 'Oatly',
    quantity: '1 l',
    imageUrl:
        'https://images.openfoodfacts.org/images/products/736/409/700/0070/front_de.4.200.jpg',
    source: ProductSource.off,
    updatedAt: _t,
  );
  static final tomaten = ProductInfo(
    ean: '8076800195057',
    name: 'Passierte Tomaten',
    brand: 'Mutti',
    quantity: '700 g',
    imageUrl:
        'https://images.openfoodfacts.org/images/products/807/680/019/5057/front_de.52.200.jpg',
    source: ProductSource.off,
    updatedAt: _t,
  );

  static const String offlineCode = '9999999999999';
  static const String unknownCode = '0000000000000';

  static ProductInfo? byEan(String ean) =>
      [nutella, haferdrink, tomaten].where((p) => p.ean == ean).firstOrNull;
}

/// Scanner-Sitzung ohne Netz und Firebase.
class DemoScannerSession implements ScannerSession {
  DemoScannerSession({required this.shopping, required this.listId});

  final MockShoppingRepository shopping;
  final String listId;
  final Map<String, ProductInfo> named = {};

  @override
  Future<ProductLookupResult> lookup(String ean) async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (ean == DemoProducts.offlineCode) {
      return const ProductLookupResult.offline();
    }
    final p = DemoProducts.byEan(ean) ?? named[ean];
    return p == null
        ? const ProductLookupResult.unknown()
        : ProductLookupResult.found(p);
  }

  @override
  Future<ScanAddOutcome> addToList(ProductInfo product, double quantity) async {
    final item = await shopping.addOrIncrement(
      name: product.name,
      quantity: quantity,
      unit: 'Stück',
      userId: 'demo',
      listId: listId,
      ean: product.ean,
      imageUrl: product.imageUrl,
    );
    return item.quantity > quantity
        ? ScanAddOutcome.incremented
        : ScanAddOutcome.added;
  }

  @override
  Future<ProductInfo> rememberProduct({
    required String ean,
    required String name,
    String? brand,
    String? packageSize,
  }) async {
    final p = ProductInfo(
      ean: ean,
      name: name,
      brand: brand,
      quantity: packageSize,
      source: ProductSource.nutzer,
      updatedAt: DateTime.now(),
      createdBy: 'demo',
    );
    named[ean] = p;
    return p;
  }
}

class ShoppingDemoScreen extends StatefulWidget {
  const ShoppingDemoScreen({super.key});

  @override
  State<ShoppingDemoScreen> createState() => _ShoppingDemoScreenState();
}

class _ShoppingDemoScreenState extends State<ShoppingDemoScreen> {
  static const String _listId = 'demo-liste';
  final MockShoppingRepository _repo = MockShoppingRepository()
    ..delay = Duration.zero;
  late final DemoScannerSession _session = DemoScannerSession(
    shopping: _repo,
    listId: _listId,
  );
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    _seed();
  }

  Future<void> _seed() async {
    final now = DateTime.now();
    for (final (p, qty, done) in [
      (DemoProducts.nutella, 1.0, false),
      (DemoProducts.haferdrink, 2.0, false),
      (DemoProducts.tomaten, 3.0, true),
    ]) {
      final item = await _repo.addItem(
        name: p.name,
        quantity: qty,
        unit: 'Stück',
        userId: 'demo',
        listId: _listId,
        ean: p.ean,
        imageUrl: p.imageUrl,
      );
      if (done) {
        await _repo.updateItem(
          item.copyWith(
            isPurchased: true,
            purchasedBy: 'Martin',
            purchasedAt: now.subtract(const Duration(hours: 2)),
          ),
        );
      }
    }
    await _repo.addItem(
      name: 'Äpfel',
      quantity: 1,
      unit: 'kg',
      userId: 'demo',
      listId: _listId,
      notes: 'Bio, möglichst regional',
    );
    if (mounted) setState(() {});
  }

  void _toggleTheme() {
    _dark = !_dark;
    context.read<ThemeBloc>().add(ThemeChanged(_dark ? 'Dark' : 'Light'));
    setState(() {});
  }

  Future<void> _scan() async {
    final l10n = AppLocalizations.of(context)!;
    final added = await BarcodeScannerScreen.open<int>(
      context,
      session: _session,
      demo: true,
    );
    if (!mounted) return;
    setState(() {});
    if (added != null && added > 0) {
      TdToast.show(
        context,
        l10n.scanCount(added),
        variant: TdToastVariant.success,
      );
    }
  }

  Future<ProductInfo?> _pick() => BarcodeScannerScreen.open<ProductInfo>(
    context,
    session: _session,
    pickMode: true,
    demo: true,
  );

  Future<void> _add() async {
    final draft = await showShoppingItemSheet(context, onScan: _pick);
    if (draft == null) return;
    await _repo.addItem(
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit ?? 'Stück',
      userId: 'demo',
      listId: _listId,
      notes: draft.notes,
      ean: draft.ean,
      imageUrl: draft.imageUrl,
    );
    if (mounted) setState(() {});
  }

  Future<void> _edit(ShoppingItemModel item) async {
    final draft = await showShoppingItemSheet(
      context,
      initial: ShoppingItemDraft.fromItem(item),
      isEdit: true,
      onScan: _pick,
    );
    if (draft == null) return;
    await _repo.updateItem(
      item.copyWith(
        name: draft.name,
        quantity: draft.quantity,
        unit: draft.unit,
        notes: draft.notes,
        ean: draft.ean,
        imageUrl: draft.imageUrl,
        clearProduct: draft.ean == null,
      ),
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.shoppingList),
        actions: [
          IconButton(
            tooltip: l10n.scanBarcode,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            onPressed: _scan,
          ),
          IconButton(
            icon: Icon(
              _dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            ),
            onPressed: _toggleTheme,
          ),
        ],
      ),
      body: ShoppingItemsView(
        items: _repo.items.where((i) => i.listId == _listId).toList(),
        canEdit: true,
        canToggle: true,
        currentUserName: 'Martin',
        onToggle: (item, v) async {
          await _repo.updateItem(
            ShoppingItemModel(
              id: item.id,
              name: item.name,
              quantity: item.quantity,
              unit: item.unit,
              isPurchased: v,
              purchasedBy: v ? 'Martin' : null,
              purchasedAt: v ? DateTime.now() : null,
              createdAt: item.createdAt,
              userId: item.userId,
              notes: item.notes,
              listId: item.listId,
              ean: item.ean,
              imageUrl: item.imageUrl,
            ),
          );
          if (mounted) setState(() {});
        },
        onEdit: _edit,
        onDelete: (item) async {
          await _repo.deleteItem(item.id);
          if (mounted) setState(() {});
        },
        onAddFirst: _add,
        onScanFirst: _scan,
      ),
      floatingActionButton: ShoppingQuickActions(onAdd: _add, onScan: _scan),
    );
  }
}

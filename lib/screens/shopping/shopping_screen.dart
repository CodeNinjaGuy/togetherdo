/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import 'package:go_router/go_router.dart';

import '../../design/td_design.dart';
import '../../models/list_model.dart';
import '../../models/product_info.dart';
import '../../models/shopping_item_model.dart';
import '../../repositories/list_repository.dart';
import '../../repositories/product_repository.dart';
import '../../repositories/shopping_repository.dart';
import '../../services/scanner_session.dart';
import '../../services/speech_service.dart';
import '../../widgets/shopping/shopping_item_sheet.dart';
import '../../widgets/shopping/shopping_item_widget.dart';
import '../../widgets/shopping/shopping_quick_actions.dart';
import '../../widgets/lists/list_visuals.dart';
import '../../widgets/shopping/voice_input_sheet.dart';
import 'barcode_scanner_screen.dart';

class ShoppingScreen extends StatefulWidget {
  final String listId;
  final String? highlightItemId;

  const ShoppingScreen({super.key, required this.listId, this.highlightItemId});

  @override
  State<ShoppingScreen> createState() => _ShoppingScreenState();
}

class _ShoppingScreenState extends State<ShoppingScreen> {
  String? _highlightItemId;
  late final FirebaseShoppingRepository _shoppingRepository;
  late final FirebaseListRepository _listRepository;
  late final Future<ListModel?> _listFuture;
  final SpeechService _speech = DeviceSpeechService();

  @override
  void initState() {
    super.initState();
    _highlightItemId = widget.highlightItemId;
    _shoppingRepository =
        context.read<ShoppingRepository>() as FirebaseShoppingRepository;
    _listRepository = context.read<ListRepository>() as FirebaseListRepository;
    _listFuture = _listRepository.getListById(widget.listId);
  }

  @override
  void didUpdateWidget(covariant ShoppingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.highlightItemId != oldWidget.highlightItemId) {
      setState(() => _highlightItemId = widget.highlightItemId);
    }
  }

  void _onHighlightEnd() => setState(() => _highlightItemId = null);

  // ------------------------------------------------------------ Nutzer

  AuthAuthenticated? get _auth {
    final state = context.read<AuthBloc>().state;
    return state is AuthAuthenticated ? state : null;
  }

  String get _userId => _auth?.user.id ?? '';
  String? get _userName => _auth?.user.displayName;

  ({bool canEdit, bool canToggle}) _rights(ListModel list) {
    final uid = _userId;
    final isOwner = list.ownerId == uid;
    final isMember = list.memberIds.contains(uid);
    return (
      canEdit: isOwner || (isMember && list.allowEdit),
      canToggle: isOwner || isMember,
    );
  }

  // ----------------------------------------------------------- Aktionen

  ScannerSession _session(AppLocalizations l10n) => ListScannerSession(
    products: context.read<ProductRepository>(),
    shopping: _shoppingRepository,
    listId: widget.listId,
    userId: _userId,
    defaultUnit: l10n.unit_piece,
  );

  Future<void> _openScanner() async {
    final l10n = AppLocalizations.of(context)!;
    final added = await BarcodeScannerScreen.open<int>(
      context,
      session: _session(l10n),
    );
    if (!mounted || added == null || added == 0) return;
    TdToast.show(
      context,
      l10n.scanCount(added),
      variant: TdToastVariant.success,
      icon: Icons.shopping_basket_rounded,
    );
  }

  Future<ProductInfo?> _pickProduct() {
    final l10n = AppLocalizations.of(context)!;
    return BarcodeScannerScreen.open<ProductInfo>(
      context,
      session: _session(l10n),
      pickMode: true,
    );
  }

  /// Mikrofon im Sheet: ein Eintrag füllt die Felder.
  Future<ShoppingItemDraft?> _voiceForSheet() async {
    final drafts = await showVoiceInputSheet(
      context,
      speech: _speech,
      singleEntry: true,
    );
    return drafts?.firstOrNull;
  }

  /// Mikrofon als Schnellaktion: ein Eintrag → Sheet vorausgefüllt,
  /// mehrere → nach Bestätigung direkt in die Liste.
  Future<void> _voiceQuickAdd() async {
    final drafts = await showVoiceInputSheet(
      context,
      speech: _speech,
      addDirectly: true,
    );
    if (drafts == null || drafts.isEmpty || !mounted) return;
    if (drafts.length == 1) {
      await _addManually(initial: drafts.first);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    var added = 0;
    for (final d in drafts) {
      if (await _saveDraft(d, l10n, quiet: true)) added++;
    }
    if (!mounted || added == 0) return;
    TdToast.show(
      context,
      l10n.voiceItemsAdded(added),
      variant: TdToastVariant.success,
      icon: Icons.mic_rounded,
    );
  }

  Future<void> _addManually({ShoppingItemDraft? initial}) async {
    final draft = await showShoppingItemSheet(
      context,
      initial: initial,
      onScan: barcodeScannerSupported ? _pickProduct : null,
      onVoice: speechInputSupported ? _voiceForSheet : null,
    );
    if (draft == null || !mounted) return;
    await _saveDraft(draft, AppLocalizations.of(context)!);
  }

  Future<bool> _saveDraft(
    ShoppingItemDraft draft,
    AppLocalizations l10n, {
    bool quiet = false,
  }) async {
    try {
      await _shoppingRepository.addItem(
        name: draft.name,
        quantity: draft.quantity,
        unit: draft.unit ?? l10n.unit_piece,
        userId: _userId,
        notes: draft.notes,
        listId: widget.listId,
        ean: draft.ean,
        imageUrl: draft.imageUrl,
      );
      if (!mounted) return true;
      if (!quiet) {
        TdToast.show(
          context,
          l10n.scanAdded(draft.name),
          variant: TdToastVariant.success,
          icon: Icons.add_shopping_cart_rounded,
        );
      }
      return true;
    } catch (e) {
      if (!mounted) return false;
      TdToast.show(
        context,
        '${l10n.loadError}: $e',
        variant: TdToastVariant.error,
      );
      return false;
    }
  }

  Future<void> _edit(ShoppingItemModel item) async {
    final draft = await showShoppingItemSheet(
      context,
      initial: ShoppingItemDraft.fromItem(item),
      isEdit: true,
      onScan: barcodeScannerSupported ? _pickProduct : null,
      onVoice: speechInputSupported ? _voiceForSheet : null,
    );
    if (draft == null || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final updated = item.copyWith(
      name: draft.name,
      quantity: draft.quantity,
      unit: draft.unit,
      notes: draft.notes,
      ean: draft.ean,
      imageUrl: draft.imageUrl,
      clearProduct: draft.ean == null,
    );
    // `notes` leeren: copyWith lässt null durch, daher eigenes Objekt.
    final toSave = draft.notes == null && item.notes != null
        ? ShoppingItemModel(
            id: updated.id,
            name: updated.name,
            quantity: updated.quantity,
            unit: updated.unit,
            isPurchased: updated.isPurchased,
            purchasedBy: updated.purchasedBy,
            purchasedAt: updated.purchasedAt,
            createdAt: updated.createdAt,
            userId: updated.userId,
            listId: updated.listId,
            ean: updated.ean,
            imageUrl: updated.imageUrl,
          )
        : updated;
    try {
      await _shoppingRepository.updateItem(toSave);
      if (!mounted) return;
      TdToast.show(context, l10n.itemSaved, variant: TdToastVariant.success);
    } catch (e) {
      if (!mounted) return;
      TdToast.show(
        context,
        '${l10n.loadError}: $e',
        variant: TdToastVariant.error,
      );
    }
  }

  Future<void> _toggle(ShoppingItemModel item, bool value) async {
    final updated = ShoppingItemModel(
      id: item.id,
      name: item.name,
      quantity: item.quantity,
      unit: item.unit,
      isPurchased: value,
      purchasedBy: value ? _userName : null,
      purchasedAt: value ? DateTime.now() : null,
      createdAt: item.createdAt,
      userId: item.userId,
      notes: item.notes,
      listId: item.listId,
      ean: item.ean,
      imageUrl: item.imageUrl,
    );
    try {
      await _shoppingRepository.updateItem(updated);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      TdToast.show(
        context,
        '${l10n.loadError}: $e',
        variant: TdToastVariant.error,
      );
    }
  }

  Future<void> _confirmDelete(ShoppingItemModel item) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteItemTitle),
        content: Text(l10n.deleteItemContent(item.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: ctx.td.danger),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _shoppingRepository.deleteItem(item.id);
  }

  // -------------------------------------------------------------- Aufbau

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();

    return FutureBuilder<ListModel?>(
      future: _listFuture,
      builder: (context, listSnapshot) {
        final list = listSnapshot.data;
        final rights = list == null
            ? (canEdit: false, canToggle: false)
            : _rights(list);

        return Scaffold(
          body: SafeArea(
            bottom: false,
            child: _buildBody(context, l10n, listSnapshot, rights),
          ),
          floatingActionButton: rights.canEdit
              ? ShoppingQuickActions(
                  onAdd: () => _addManually(),
                  onScan: barcodeScannerSupported ? _openScanner : null,
                  onVoice: speechInputSupported ? _voiceQuickAdd : null,
                )
              : null,
        );
      },
    );
  }

  /// Kopf wie bei Aufgabenlisten: Zurück (Handy), Symbol mit Hero, Name,
  /// Mitglieder, Nur-lesen-Hinweis per Tooltip, Scanner.
  Widget _header(
    BuildContext context,
    AppLocalizations l10n,
    ListModel list,
    ({bool canEdit, bool canToggle}) rights,
  ) {
    final compact = context.tdIsCompact;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.page,
        TdSpace.md,
        TdSpace.page,
        TdSpace.sm,
      ),
      child: Row(
        children: [
          if (compact)
            Padding(
              padding: const EdgeInsets.only(right: TdSpace.sm),
              child: TdIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: l10n.navLists,
                size: 40,
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/lists'),
              ),
            ),
          Expanded(
            child: ListHeader(
              list: list,
              iconSize: compact ? 52 : 64,
              subtitle: l10n.memberCount(list.memberCount),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!rights.canEdit)
                    Tooltip(
                      message: l10n.readOnlyMode,
                      triggerMode: TooltipTriggerMode.tap,
                      child: TdTag(
                        label: l10n.readOnly,
                        icon: Icons.lock_outline_rounded,
                        filled: false,
                      ),
                    ),
                  if (rights.canEdit && barcodeScannerSupported) ...[
                    const SizedBox(width: TdSpace.sm),
                    TdIconButton(
                      icon: Icons.qr_code_scanner_rounded,
                      tooltip: l10n.scanBarcode,
                      size: 40,
                      onPressed: _openScanner,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    AsyncSnapshot<ListModel?> listSnapshot,
    ({bool canEdit, bool canToggle}) rights,
  ) {
    if (listSnapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }
    final list = listSnapshot.data;
    if (list == null) {
      return Center(
        child: TdEmptyState(
          icon: Icons.search_off_rounded,
          title: l10n.listNotFound,
          action: TdButton.secondary(
            label: l10n.navLists,
            icon: Icons.arrow_back_rounded,
            onPressed: () => context.go('/lists'),
          ),
        ),
      );
    }

    return Column(
      children: [
        TdFadeSlideIn(child: _header(context, l10n, list, rights)),
        Expanded(
          child: StreamBuilder<List<ShoppingItemModel>>(
            stream: _shoppingRepository.getItemsStream(widget.listId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text('${l10n.loadError}: ${snapshot.error}'),
                );
              }
              return ShoppingItemsView(
                items: snapshot.data ?? const [],
                canEdit: rights.canEdit,
                canToggle: rights.canToggle,
                currentUserName: _userName,
                highlightItemId: _highlightItemId,
                onHighlightEnd: _onHighlightEnd,
                onToggle: _toggle,
                onEdit: _edit,
                onDelete: _confirmDelete,
                onAddFirst: rights.canEdit ? () => _addManually() : null,
                onScanFirst: rights.canEdit && barcodeScannerSupported
                    ? _openScanner
                    : null,
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Die Artikelliste selbst: „Noch zu kaufen“ und „Gekauft“ mit Zählern,
/// Leerzustand mit Schnellstart. Ohne Firebase, damit sie auch in der
/// Debug-Demo und in Tests läuft.
class ShoppingItemsView extends StatelessWidget {
  const ShoppingItemsView({
    super.key,
    required this.items,
    required this.canEdit,
    required this.canToggle,
    this.currentUserName,
    this.highlightItemId,
    this.onHighlightEnd,
    this.onToggle,
    this.onEdit,
    this.onDelete,
    this.onAddFirst,
    this.onScanFirst,
  });

  final List<ShoppingItemModel> items;
  final bool canEdit;
  final bool canToggle;
  final String? currentUserName;
  final String? highlightItemId;
  final VoidCallback? onHighlightEnd;
  final void Function(ShoppingItemModel item, bool value)? onToggle;
  final ValueChanged<ShoppingItemModel>? onEdit;
  final ValueChanged<ShoppingItemModel>? onDelete;
  final VoidCallback? onAddFirst;
  final VoidCallback? onScanFirst;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (items.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: TdEmptyState(
            icon: Icons.shopping_cart_outlined,
            title: l10n.shoppingListEmpty,
            message: canEdit ? l10n.addFirstItem : l10n.listIsEmpty,
            action: canEdit
                ? Wrap(
                    spacing: TdSpace.sm,
                    runSpacing: TdSpace.sm,
                    alignment: WrapAlignment.center,
                    children: [
                      if (onScanFirst != null)
                        TdButton.primary(
                          label: l10n.scanBarcode,
                          icon: Icons.qr_code_scanner_rounded,
                          onPressed: onScanFirst,
                        ),
                      TdButton.secondary(
                        label: l10n.addManually,
                        icon: Icons.edit_outlined,
                        onPressed: onAddFirst,
                      ),
                    ],
                  )
                : null,
          ),
        ),
      );
    }

    final pending = items.where((i) => !i.isPurchased).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final purchased = items.where((i) => i.isPurchased).toList()
      ..sort((a, b) {
        final at = a.purchasedAt, bt = b.purchasedAt;
        if (at == null || bt == null) return 0;
        return bt.compareTo(at);
      });

    var index = 0;
    Widget tile(ShoppingItemModel item) => ShoppingItemWidget(
      key: ValueKey(item.id),
      item: item,
      index: index++,
      highlight: highlightItemId == item.id,
      onHighlightEnd: onHighlightEnd,
      canEdit: canEdit,
      canToggle: canToggle,
      currentUserName: currentUserName,
      onTogglePurchased: onToggle == null ? null : (v) => onToggle!(item, v),
      onTap: onEdit == null ? null : () => onEdit!(item),
      onDelete: onDelete == null ? null : () => onDelete!(item),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.page,
        TdSpace.lg,
        TdSpace.page,
        120,
      ),
      children: [
        if (pending.isNotEmpty) ...[
          _SectionHeader(title: l10n.stillToBuy, count: pending.length),
          const SizedBox(height: TdSpace.sm),
          ...pending.map(tile),
          const SizedBox(height: TdSpace.lg),
        ],
        if (purchased.isNotEmpty) ...[
          _SectionHeader(
            title: l10n.bought,
            count: purchased.length,
            muted: true,
          ),
          const SizedBox(height: TdSpace.sm),
          ...purchased.map(tile),
        ],
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.count,
    this.muted = false,
  });

  final String title;
  final int count;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(left: TdSpace.xs),
      child: Row(
        children: [
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: muted ? context.td.muted : null,
            ),
          ),
          const SizedBox(width: TdSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: TdSpace.sm,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: muted
                  ? scheme.surfaceContainerHighest
                  : scheme.primaryContainer,
              borderRadius: BorderRadius.circular(TdRadius.pill),
            ),
            child: TdAnimatedCounter(
              value: count,
              style: context.text.labelMedium?.copyWith(
                color: muted ? context.td.muted : scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

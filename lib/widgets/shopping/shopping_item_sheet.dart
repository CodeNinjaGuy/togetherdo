/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../models/product_info.dart';
import '../../models/shopping_item_model.dart';
import 'product_thumbnail.dart';
import 'quantity_stepper.dart';

/// Vorausgefüllte Werte für das Sheet, z. B. aus einem Scan.
class ShoppingItemDraft {
  const ShoppingItemDraft({
    this.name = '',
    this.quantity = 1,
    this.unit,
    this.notes,
    this.ean,
    this.imageUrl,
  });

  factory ShoppingItemDraft.fromItem(ShoppingItemModel item) =>
      ShoppingItemDraft(
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        notes: item.notes,
        ean: item.ean,
        imageUrl: item.imageUrl,
      );

  factory ShoppingItemDraft.fromProduct(ProductInfo product) =>
      ShoppingItemDraft(
        name: product.name,
        ean: product.ean,
        imageUrl: product.imageUrl,
      );

  final String name;
  final double quantity;
  final String? unit;
  final String? notes;
  final String? ean;
  final String? imageUrl;

  bool get hasProduct => ean != null;

  ShoppingItemDraft copyWith({
    String? name,
    double? quantity,
    String? unit,
    String? notes,
    String? ean,
    String? imageUrl,
    bool clearProduct = false,
  }) => ShoppingItemDraft(
    name: name ?? this.name,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    notes: notes ?? this.notes,
    ean: clearProduct ? null : (ean ?? this.ean),
    imageUrl: clearProduct ? null : (imageUrl ?? this.imageUrl),
  );
}

/// Die auswählbaren Einheiten in der Sprache des Nutzers.
List<String> shoppingUnits(AppLocalizations l10n) => [
  l10n.unit_piece,
  l10n.unit_kg,
  l10n.unit_g,
  l10n.unit_l,
  l10n.unit_ml,
  l10n.unit_pack,
  l10n.unit_can,
  l10n.unit_bottle,
  l10n.unit_bag,
  l10n.unit_bunch,
  l10n.unit_head,
  l10n.unit_cup,
  l10n.unit_jar,
];

/// Öffnet das Sheet zum Anlegen oder Bearbeiten eines Einkaufsartikels.
/// Liefert den fertigen Entwurf oder `null` bei Abbruch. Speichern
/// übernimmt der Aufrufer (Repository), damit das Sheet ohne Firebase
/// testbar bleibt.
///
/// [onScan] öffnet den Scanner im Auswahlmodus und liefert ein Produkt;
/// `null` blendet den Knopf „Neu scannen“ aus (Plattform ohne Kamera).
Future<ShoppingItemDraft?> showShoppingItemSheet(
  BuildContext context, {
  ShoppingItemDraft? initial,
  bool isEdit = false,
  Future<ProductInfo?> Function()? onScan,
  Future<ShoppingItemDraft?> Function()? onVoice,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showTdSheet<ShoppingItemDraft>(
    context,
    title: isEdit ? l10n.editItem : l10n.addItem,
    builder: (ctx) => ShoppingItemForm(
      initial: initial ?? const ShoppingItemDraft(),
      isEdit: isEdit,
      onScan: onScan,
      onVoice: onVoice,
      onSubmit: (draft) => Navigator.of(ctx).pop(draft),
    ),
  );
}

class ShoppingItemForm extends StatefulWidget {
  const ShoppingItemForm({
    super.key,
    required this.initial,
    required this.onSubmit,
    this.isEdit = false,
    this.onScan,
    this.onVoice,
  });

  final ShoppingItemDraft initial;
  final ValueChanged<ShoppingItemDraft> onSubmit;
  final bool isEdit;
  final Future<ProductInfo?> Function()? onScan;

  /// Spracheingabe: liefert einen Entwurf, der die Felder füllt.
  /// `null` blendet das Mikrofon aus (Plattform ohne Spracherkennung).
  final Future<ShoppingItemDraft?> Function()? onVoice;

  @override
  State<ShoppingItemForm> createState() => _ShoppingItemFormState();
}

class _ShoppingItemFormState extends State<ShoppingItemForm> {
  late final TextEditingController _name = TextEditingController(
    text: widget.initial.name,
  );
  late final TextEditingController _notes = TextEditingController(
    text: widget.initial.notes ?? '',
  );
  late double _quantity = widget.initial.quantity;
  String? _unit;
  String? _ean;
  String? _imageUrl;
  bool _showError = false;
  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _ean = widget.initial.ean;
    _imageUrl = widget.initial.imageUrl;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final l10n = AppLocalizations.of(context);
    if (l10n != null) {
      _unit ??= widget.initial.unit ?? l10n.unit_piece;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Übernimmt Werte von außen (z. B. aus der Spracheingabe).
  void applyDraft(ShoppingItemDraft draft) {
    setState(() {
      _name.text = draft.name;
      _quantity = draft.quantity;
      if (draft.unit != null) _unit = draft.unit;
      if (draft.notes != null) _notes.text = draft.notes!;
      _showError = false;
    });
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    widget.onSubmit(
      ShoppingItemDraft(
        name: name,
        quantity: _quantity,
        unit: _unit,
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
        ean: _ean,
        imageUrl: _imageUrl,
      ),
    );
  }

  Future<void> _scan() async {
    final onScan = widget.onScan;
    if (onScan == null || _scanning) return;
    setState(() => _scanning = true);
    try {
      final product = await onScan();
      if (!mounted || product == null) return;
      setState(() {
        _ean = product.ean;
        _imageUrl = product.imageUrl;
        if (_name.text.trim().isEmpty) _name.text = product.name;
      });
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _voice() async {
    final onVoice = widget.onVoice;
    if (onVoice == null) return;
    final draft = await onVoice();
    if (!mounted || draft == null) return;
    applyDraft(draft);
  }

  void _removeProduct() => setState(() {
    _ean = null;
    _imageUrl = null;
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = context.colors;
    final units = shoppingUnits(l10n);
    final unit = _unit ?? units.first;
    final hasProduct = _ean != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Produkt-Zeile: Bild, Code, Neu scannen / entfernen.
        if (hasProduct || widget.onScan != null)
          TdCard(
            variant: TdCardVariant.surface,
            padding: const EdgeInsets.all(TdSpace.md),
            child: Row(
              children: [
                ProductThumbnail(
                  imageUrl: _imageUrl,
                  size: 56,
                  radius: TdRadius.sm,
                ),
                const SizedBox(width: TdSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasProduct ? l10n.productLinked : l10n.noProductLinked,
                        style: context.text.labelLarge,
                      ),
                      if (hasProduct) ...[
                        const SizedBox(height: 2),
                        Text(
                          l10n.scanCodeLabel(_ean!),
                          style: context.text.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (widget.onScan != null)
                  TdIconButton(
                    icon: Icons.qr_code_scanner_rounded,
                    tooltip: l10n.rescanProduct,
                    filled: true,
                    onPressed: _scanning ? null : _scan,
                  ),
                if (hasProduct) ...[
                  const SizedBox(width: TdSpace.sm),
                  TdIconButton(
                    icon: Icons.link_off_rounded,
                    tooltip: l10n.removeProduct,
                    onPressed: _removeProduct,
                  ),
                ],
              ],
            ),
          ),
        if (hasProduct || widget.onScan != null)
          const SizedBox(height: TdSpace.lg),

        // Name
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TdTextField(
                controller: _name,
                label: l10n.itemLabel,
                hint: l10n.exampleItem,
                autofocus: !widget.isEdit && widget.initial.name.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                onChanged: (_) {
                  if (_showError) setState(() => _showError = false);
                },
              ),
            ),
            if (widget.onVoice != null) ...[
              const SizedBox(width: TdSpace.sm),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: TdIconButton(
                  icon: Icons.mic_rounded,
                  tooltip: l10n.voiceInput,
                  filled: true,
                  size: 48,
                  onPressed: _voice,
                ),
              ),
            ],
          ],
        ),
        TdReveal(
          visible: _showError,
          child: Padding(
            padding: const EdgeInsets.only(top: TdSpace.sm, left: TdSpace.xs),
            child: Text(
              l10n.itemNameRequired,
              style: context.text.bodySmall?.copyWith(color: context.td.danger),
            ),
          ),
        ),
        const SizedBox(height: TdSpace.lg),

        // Menge
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.quantity,
              style: context.text.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            QuantityStepper(
              value: _quantity,
              min: 0.5,
              step: _quantity < 1 ? 0.5 : 1,
              onChanged: (v) => setState(() => _quantity = v),
              decreaseLabel: l10n.decreaseQuantity,
              increaseLabel: l10n.increaseQuantity,
            ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),

        // Einheit
        Text(
          l10n.unit,
          style: context.text.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TdSpace.sm),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final u in units)
              TdChip(
                label: u,
                dense: true,
                selected: u == unit,
                onTap: () => setState(() => _unit = u),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),

        // Notiz
        TdTextField(
          controller: _notes,
          label: l10n.notesOptional,
          hint: l10n.exampleNotes,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: TdSpace.xl),

        TdButton.primary(
          label: widget.isEdit ? l10n.save : l10n.add,
          icon: widget.isEdit ? Icons.check_rounded : Icons.add_rounded,
          expanded: true,
          size: TdButtonSize.large,
          onPressed: _submit,
        ),
      ],
    );
  }
}

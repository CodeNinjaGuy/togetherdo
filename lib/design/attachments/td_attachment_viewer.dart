/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../components/td_button.dart';
import '../tokens/td_tokens.dart';
import 'td_attachment_gallery.dart';

/// Vollbild für Anhänge: Blättern zwischen Bildern, Zoom per Geste,
/// dunkler Hintergrund, Kopfzeile mit Name, Löschen und Schließen.
/// Dateien (PDF) zeigen ein Symbol und einen Knopf zum Öffnen.
class TdAttachmentViewer extends StatefulWidget {
  const TdAttachmentViewer({
    super.key,
    required this.items,
    this.initialIndex = 0,
    this.onDelete,
    this.onOpenExternal,
    this.openLabel,
    this.deleteLabel,
    this.closeLabel,
  });

  final List<TdAttachmentItem> items;
  final int initialIndex;

  /// Löschen (nur für Einträge mit `canDelete`); liefert `true`, wenn
  /// gelöscht wurde – der Eintrag verschwindet dann aus der Ansicht.
  final Future<bool> Function(TdAttachmentItem item)? onDelete;

  /// Öffnet eine Datei außerhalb (z. B. PDF im System).
  final void Function(TdAttachmentItem item)? onOpenExternal;
  final String? openLabel;
  final String? deleteLabel;
  final String? closeLabel;

  static Future<void> open(
    BuildContext context, {
    required List<TdAttachmentItem> items,
    int initialIndex = 0,
    Future<bool> Function(TdAttachmentItem item)? onDelete,
    void Function(TdAttachmentItem item)? onOpenExternal,
    String? openLabel,
    String? deleteLabel,
    String? closeLabel,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      PageRouteBuilder<void>(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: TdMotion.page,
        reverseTransitionDuration: TdMotion.page,
        pageBuilder: (_, _, _) => TdAttachmentViewer(
          items: items,
          initialIndex: initialIndex,
          onDelete: onDelete,
          onOpenExternal: onOpenExternal,
          openLabel: openLabel,
          deleteLabel: deleteLabel,
          closeLabel: closeLabel,
        ),
        transitionsBuilder: (_, a, _, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  State<TdAttachmentViewer> createState() => _TdAttachmentViewerState();
}

class _TdAttachmentViewerState extends State<TdAttachmentViewer> {
  late final List<TdAttachmentItem> _items = List.of(widget.items);
  late final PageController _pages = PageController(
    initialPage: widget.initialIndex.clamp(0, widget.items.length - 1),
  );
  late int _index = widget.initialIndex.clamp(0, widget.items.length - 1);
  bool _zoomed = false;
  bool _busy = false;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final item = _items[_index];
    final onDelete = widget.onDelete;
    if (onDelete == null || _busy) return;
    setState(() => _busy = true);
    final ok = await onDelete(item);
    if (!mounted) return;
    if (!ok) {
      setState(() => _busy = false);
      return;
    }
    setState(() {
      _items.removeAt(_index);
      _busy = false;
      if (_items.isEmpty) return;
      _index = _index.clamp(0, _items.length - 1);
    });
    if (_items.isEmpty) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty) return const SizedBox.shrink();
    final item = _items[_index];
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            PageView.builder(
              controller: _pages,
              physics: _zoomed ? const NeverScrollableScrollPhysics() : null,
              onPageChanged: (i) => setState(() => _index = i),
              itemCount: _items.length,
              itemBuilder: (context, i) {
                final it = _items[i];
                if (!it.isImage) {
                  return _FilePage(
                    item: it,
                    openLabel: widget.openLabel,
                    onOpen: widget.onOpenExternal == null
                        ? null
                        : () => widget.onOpenExternal!(it),
                  );
                }
                return GestureDetector(
                  onTap: () => Navigator.of(context).maybePop(),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 5,
                    onInteractionEnd: (d) {},
                    onInteractionUpdate: (d) {
                      final zoomed = d.scale != 1.0;
                      if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
                    },
                    child: Center(
                      child: Hero(
                        tag: it.heroTag,
                        child: TdAttachmentImage(item: it, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                );
              },
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(TdSpace.sm),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: widget.closeLabel,
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (_items.length > 1)
                            Text(
                              '${_index + 1} / ${_items.length}',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (item.canDelete && widget.onDelete != null)
                      IconButton(
                        tooltip: widget.deleteLabel,
                        onPressed: _busy ? null : _delete,
                        icon: _busy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.delete_outline_rounded,
                                color: Colors.white,
                              ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilePage extends StatelessWidget {
  const _FilePage({required this.item, this.onOpen, this.openLabel});

  final TdAttachmentItem item;
  final VoidCallback? onOpen;
  final String? openLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Hero(
            tag: item.heroTag,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(TdRadius.lg),
              ),
              child: const Icon(
                Icons.picture_as_pdf_rounded,
                color: Colors.white,
                size: 56,
              ),
            ),
          ),
          const SizedBox(height: TdSpace.lg),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TdSpace.xxl),
            child: Text(
              item.name,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          if (onOpen != null) ...[
            const SizedBox(height: TdSpace.xl),
            TdButton.primary(
              label: openLabel ?? 'PDF',
              icon: Icons.open_in_new_rounded,
              onPressed: onOpen,
            ),
          ],
        ],
      ),
    );
  }
}

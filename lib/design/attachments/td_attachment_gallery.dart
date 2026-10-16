/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../components/td_pressable.dart';
import '../motion/td_entrance.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Darstellungsdaten eines Anhangs – unabhängig vom Datenmodell.
@immutable
class TdAttachmentItem {
  const TdAttachmentItem({
    required this.id,
    required this.name,
    this.url,
    this.bytes,
    this.isImage = true,
    this.canDelete = false,
    this.uploadedBy,
  });

  final String id;
  final String name;

  /// Adresse des Bilds/der Datei (nach dem Upload).
  final String? url;

  /// Lokale Daten (vor dem Upload) für die Vorschau.
  final Uint8List? bytes;
  final bool isImage;
  final bool canDelete;
  final String? uploadedBy;

  Object get heroTag => 'attachment-$id';
}

/// Laufender Upload mit Fortschritt 0…1.
@immutable
class TdUploadProgress {
  const TdUploadProgress({required this.name, required this.progress, this.bytes});

  final String name;
  final double progress;
  final Uint8List? bytes;
}

/// Reihe kleiner Kacheln: Bilder, Dateien, laufende Uploads und ganz
/// vorne die Kachel „Hinzufügen“. Tippen öffnet die Vollansicht.
class TdAttachmentGallery extends StatelessWidget {
  const TdAttachmentGallery({
    super.key,
    required this.items,
    this.uploads = const [],
    this.onAdd,
    this.onOpen,
    this.onDelete,
    this.addLabel,
    this.deleteLabel,
    this.tileSize = 88,
  });

  final List<TdAttachmentItem> items;
  final List<TdUploadProgress> uploads;
  final VoidCallback? onAdd;
  final void Function(int index)? onOpen;
  final void Function(TdAttachmentItem item)? onDelete;
  final String? addLabel;
  final String? deleteLabel;
  final double tileSize;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: tileSize,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          if (onAdd != null)
            Padding(
              padding: const EdgeInsets.only(right: TdSpace.sm),
              child: _AddTile(size: tileSize, onTap: onAdd!, label: addLabel),
            ),
          for (final (i, u) in uploads.indexed)
            Padding(
              key: ValueKey('upload-$i-${u.name}'),
              padding: const EdgeInsets.only(right: TdSpace.sm),
              child: _UploadTile(size: tileSize, upload: u),
            ),
          for (final (i, item) in items.indexed)
            Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.only(right: TdSpace.sm),
              child: TdFadeSlideIn(
                index: i,
                offset: const Offset(0.1, 0),
                child: TdAttachmentTile(
                  item: item,
                  size: tileSize,
                  onTap: onOpen == null ? null : () => onOpen!(i),
                  onDelete: item.canDelete && onDelete != null
                      ? () => onDelete!(item)
                      : null,
                  deleteLabel: deleteLabel,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Eine Kachel: Bild (Netz oder lokal) oder Datei-Symbol mit Namen.
class TdAttachmentTile extends StatelessWidget {
  const TdAttachmentTile({
    super.key,
    required this.item,
    this.size = 88,
    this.onTap,
    this.onDelete,
    this.deleteLabel,
    this.hero = true,
  });

  final TdAttachmentItem item;
  final double size;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final String? deleteLabel;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    Widget content = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TdRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: item.isImage
          ? TdAttachmentImage(item: item, fit: BoxFit.cover)
          : _FileFace(name: item.name),
    );
    if (hero) content = Hero(tag: item.heroTag, child: content);
    content = TdPressable(onTap: onTap, scale: 0.95, child: content);
    if (onDelete == null) return content;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          top: -6,
          right: -6,
          child: Tooltip(
            message: deleteLabel ?? '',
            child: TdPressable(
              onTap: onDelete,
              scale: 0.85,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: scheme.onSurface,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 2),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: scheme.surface,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bild aus Netz oder Speicher, mit weicher Einblendung und Platzhalter.
class TdAttachmentImage extends StatelessWidget {
  const TdAttachmentImage({super.key, required this.item, this.fit = BoxFit.cover});

  final TdAttachmentItem item;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final bytes = item.bytes;
    if (bytes != null) {
      return Image.memory(bytes, fit: fit, gaplessPlayback: true);
    }
    final url = item.url;
    if (url == null || url.isEmpty) {
      return Icon(Icons.image_outlined, color: scheme.onSurfaceVariant);
    }
    return Image.network(
      url,
      fit: fit,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, wasSync) {
        if (wasSync) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: TdMotion.of(context, TdMotion.base),
          child: child,
        );
      },
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              value: progress.expectedTotalBytes == null
                  ? null
                  : progress.cumulativeBytesLoaded /
                        progress.expectedTotalBytes!,
            ),
          ),
        );
      },
      errorBuilder: (_, _, _) =>
          Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
    );
  }
}

class _FileFace extends StatelessWidget {
  const _FileFace({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final ext = name.contains('.')
        ? name.substring(name.lastIndexOf('.') + 1).toUpperCase()
        : '';
    return Padding(
      padding: const EdgeInsets.all(TdSpace.sm),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.picture_as_pdf_rounded, color: scheme.secondary, size: 28),
          const SizedBox(height: TdSpace.xs),
          Text(
            name,
            style: context.text.labelSmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (ext.isNotEmpty)
            Text(
              ext,
              style: context.text.labelSmall?.copyWith(
                color: scheme.secondary,
                fontSize: 9,
              ),
            ),
        ],
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.size, required this.onTap, this.label});

  final double size;
  final VoidCallback onTap;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TdPressable(
      onTap: onTap,
      scale: 0.95,
      haptic: true,
      semanticLabel: label,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(TdRadius.md),
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: scheme.primary, size: 24),
            if (label != null) ...[
              const SizedBox(height: TdSpace.xs),
              Text(
                label!,
                style: context.text.labelSmall?.copyWith(color: scheme.primary),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({required this.size, required this.upload});

  final double size;
  final TdUploadProgress upload;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(TdRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (upload.bytes != null)
            Opacity(
              opacity: 0.5,
              child: Image.memory(upload.bytes!, fit: BoxFit.cover),
            ),
          Center(
            child: SizedBox(
              width: 34,
              height: 34,
              child: CircularProgressIndicator(
                value: upload.progress <= 0 ? null : upload.progress,
                strokeWidth: 3,
                backgroundColor: scheme.surface.withValues(alpha: 0.6),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kleines Etikett „📎 2“ in der Aufgabenzeile.
class TdAttachmentBadge extends StatelessWidget {
  const TdAttachmentBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final scheme = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.attach_file_rounded, size: 13, color: scheme.onSurfaceVariant),
        Text(
          '$count',
          style: context.text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

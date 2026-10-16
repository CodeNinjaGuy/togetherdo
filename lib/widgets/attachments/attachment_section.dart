/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/td_design.dart';
import '../../models/attachment_model.dart';
import '../../repositories/attachment_repository.dart';
import '../../services/aufgaben_anhang_service.dart';
import 'attachment_source_sheet.dart';

/// Noch nicht hochgeladene Anhänge einer neuen Aufgabe. Das Formular lädt
/// sie nach dem Anlegen hoch.
class AttachmentStaging extends ValueNotifier<List<PickedAttachment>> {
  AttachmentStaging() : super(const []);

  void add(PickedAttachment file) => value = [...value, file];

  void removeAt(int index) =>
      value = [for (final (i, f) in value.indexed) if (i != index) f];
}

/// Anhänge einer Aufgabe: Galerie mit „Hinzufügen“, Upload mit Fortschritt,
/// Vollbild, Löschen (eigene Anhänge oder mit Bearbeitungsrecht).
///
/// Mit [todoId] werden die Anhänge aus Firestore gelesen und sofort
/// hochgeladen; ohne (neue Aufgabe) landen sie in [staging].
class AttachmentSection extends StatefulWidget {
  const AttachmentSection({
    super.key,
    required this.listId,
    required this.currentUserId,
    required this.currentUserName,
    required this.canEdit,
    required this.service,
    required this.repository,
    this.todoId,
    this.staging,
    this.showTitle = true,
  });

  final String listId;
  final String? todoId;
  final String currentUserId;
  final String currentUserName;

  /// Bearbeitungsrecht an der Liste: darf fremde Anhänge löschen.
  final bool canEdit;
  final AttachmentService service;
  final AttachmentRepository repository;
  final AttachmentStaging? staging;
  final bool showTitle;

  @override
  State<AttachmentSection> createState() => _AttachmentSectionState();
}

class _AttachmentSectionState extends State<AttachmentSection> {
  final List<TdUploadProgress> _uploads = [];

  Future<void> _add() async {
    final file = await pickAttachmentWithFeedback(context, widget.service);
    if (file == null || !mounted) return;
    final todoId = widget.todoId;
    if (todoId == null) {
      widget.staging?.add(file);
      return;
    }
    await uploadAttachment(file, todoId);
  }

  /// Lädt eine Datei hoch und trägt sie in Firestore ein.
  Future<void> uploadAttachment(PickedAttachment file, String todoId) async {
    final progress = TdUploadProgress(
      name: file.name,
      progress: 0,
      bytes: file.isImage ? file.bytes : null,
    );
    var current = progress;
    setState(() => _uploads.add(current));
    void update(double p) {
      if (!mounted) return;
      final i = _uploads.indexOf(current);
      if (i < 0) return;
      setState(() {
        current = TdUploadProgress(
          name: current.name,
          progress: p,
          bytes: current.bytes,
        );
        _uploads[i] = current;
      });
    }

    try {
      final model = await widget.service.upload(
        file: file,
        listId: widget.listId,
        todoId: todoId,
        userId: widget.currentUserId,
        userName: widget.currentUserName,
        onProgress: update,
      );
      await widget.repository.add(model);
    } catch (e) {
      debugPrint('Anhang hochladen fehlgeschlagen: $e');
      if (mounted) {
        TdToast.show(
          context,
          AppLocalizations.of(context)!.attachmentUploadFailed,
          variant: TdToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploads.remove(current));
    }
  }

  Future<bool> _delete(AttachmentModel a) async {
    final l10n = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.attachmentDelete),
        content: Text(l10n.attachmentDeleteConfirm(a.name)),
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
    if (ok != true || !mounted) return false;
    try {
      await widget.repository.remove(a.todoId, a.id);
      await widget.service.delete(a.path);
      return true;
    } catch (e) {
      debugPrint('Anhang löschen fehlgeschlagen: $e');
      if (mounted) {
        TdToast.show(
          context,
          l10n.attachmentDeleteFailed,
          variant: TdToastVariant.error,
        );
      }
      return false;
    }
  }

  TdAttachmentItem _item(AttachmentModel a) => TdAttachmentItem(
    id: a.id,
    name: a.name,
    url: a.url,
    isImage: a.isImage,
    canDelete: widget.canEdit || a.uploadedBy == widget.currentUserId,
    uploadedBy: a.uploadedByName,
  );

  void _open(List<AttachmentModel> all, int index) {
    final l10n = AppLocalizations.of(context)!;
    final byId = {for (final a in all) a.id: a};
    TdAttachmentViewer.open(
      context,
      items: all.map(_item).toList(),
      initialIndex: index,
      openLabel: l10n.attachmentOpen,
      deleteLabel: l10n.attachmentDelete,
      closeLabel: l10n.close,
      onDelete: (item) async {
        final a = byId[item.id];
        return a == null ? false : _delete(a);
      },
      onOpenExternal: (item) {
        final a = byId[item.id];
        if (a != null) launchUrl(Uri.parse(a.url), mode: LaunchMode.externalApplication);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final todoId = widget.todoId;
    if (todoId == null) {
      final staging = widget.staging;
      if (staging == null) return const SizedBox.shrink();
      return ValueListenableBuilder<List<PickedAttachment>>(
        valueListenable: staging,
        builder: (context, files, _) => _frame(
          l10n,
          TdAttachmentGallery(
            onAdd: _add,
            addLabel: l10n.attachmentAdd,
            deleteLabel: l10n.attachmentDelete,
            items: [
              for (final (i, f) in files.indexed)
                TdAttachmentItem(
                  id: 'staged-$i',
                  name: f.name,
                  bytes: f.isImage ? f.bytes : null,
                  isImage: f.isImage,
                  canDelete: true,
                ),
            ],
            onDelete: (item) =>
                staging.removeAt(int.parse(item.id.substring(7))),
          ),
        ),
      );
    }
    return StreamBuilder<List<AttachmentModel>>(
      stream: widget.repository.watch(todoId),
      builder: (context, snap) {
        final all = snap.data ?? const <AttachmentModel>[];
        return _frame(
          l10n,
          TdAttachmentGallery(
            onAdd: _add,
            addLabel: l10n.attachmentAdd,
            deleteLabel: l10n.attachmentDelete,
            uploads: _uploads,
            items: all.map(_item).toList(),
            onOpen: (i) => _open(all, i),
            onDelete: (item) {
              final a = all.where((x) => x.id == item.id).firstOrNull;
              if (a != null) _delete(a);
            },
          ),
        );
      },
    );
  }

  Widget _frame(AppLocalizations l10n, Widget gallery) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (widget.showTitle) ...[
        Row(
          children: [
            Icon(Icons.attach_file_rounded, size: 16, color: context.td.muted),
            const SizedBox(width: TdSpace.xs),
            Text(l10n.attachments, style: context.text.labelMedium),
          ],
        ),
        const SizedBox(height: TdSpace.sm),
      ],
      gallery,
    ],
  );
}

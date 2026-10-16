/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../services/avatar_service.dart';

/// Auswahl „Foto aufnehmen / Aus Fotos wählen / Entfernen“.
class AvatarSourceSheet extends StatelessWidget {
  final bool canUseCamera;
  final bool hasAvatar;

  const AvatarSourceSheet({
    super.key,
    required this.canUseCamera,
    required this.hasAvatar,
  });

  /// Text für die Galerie-Option: auf Desktop/Web eine Dateiauswahl.
  static bool get _usesFilePicker =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(
              l10n.avatarSheetTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (canUseCamera)
            ListTile(
              key: const ValueKey('avatar-option-camera'),
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(l10n.avatarTakePhoto),
              onTap: () => Navigator.of(context).pop(AvatarAction.camera),
            ),
          ListTile(
            key: const ValueKey('avatar-option-gallery'),
            leading: Icon(
              _usesFilePicker
                  ? Icons.folder_open_outlined
                  : Icons.photo_library_outlined,
            ),
            title: Text(
              _usesFilePicker
                  ? l10n.avatarChooseFile
                  : l10n.avatarChooseFromPhotos,
            ),
            onTap: () => Navigator.of(context).pop(AvatarAction.gallery),
          ),
          if (hasAvatar)
            ListTile(
              key: const ValueKey('avatar-option-remove'),
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                l10n.avatarRemove,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => Navigator.of(context).pop(AvatarAction.remove),
            ),
          ListTile(
            key: const ValueKey('avatar-option-cancel'),
            leading: const Icon(Icons.close),
            title: Text(l10n.cancel),
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Zeigt die Auswahl als Bottom-Sheet und liefert die gewählte Aktion.
Future<AvatarAction?> showAvatarSourceSheet(
  BuildContext context, {
  required bool canUseCamera,
  required bool hasAvatar,
}) {
  return showModalBottomSheet<AvatarAction>(
    context: context,
    showDragHandle: true,
    builder: (_) =>
        AvatarSourceSheet(canUseCamera: canUseCamera, hasAvatar: hasAvatar),
  );
}

/// Freundlicher Hinweis bei verweigerter Berechtigung, mit Weg zu den
/// Einstellungen (falls die Plattform das kann).
Future<void> showAvatarPermissionHint(
  BuildContext context, {
  required AvatarAction action,
  required bool canOpenSettings,
  required Future<void> Function() onOpenSettings,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        action == AvatarAction.camera
            ? Icons.photo_camera_outlined
            : Icons.photo_library_outlined,
      ),
      title: Text(l10n.avatarPermissionTitle),
      content: Text(
        action == AvatarAction.camera
            ? l10n.avatarCameraPermissionMessage
            : l10n.avatarPhotosPermissionMessage,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.avatarNotNow),
        ),
        if (canOpenSettings)
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              onOpenSettings();
            },
            child: Text(l10n.avatarOpenSettings),
          ),
      ],
    ),
  );
}

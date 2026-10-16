/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_event.dart';
import '../../blocs/auth/auth_state.dart';
import '../../models/user_model.dart';
import '../../services/avatar_service.dart';
import '../common/user_avatar.dart';
import 'avatar_source_sheet.dart';

/// Eigenes Profilbild mit Kamera-Knopf: öffnet die Auswahl, bereitet das
/// Bild auf und stößt Upload bzw. Entfernen über den [AuthBloc] an.
class EditableProfileAvatar extends StatefulWidget {
  final UserModel user;
  final double radius;

  /// Für Tests austauschbar.
  final AvatarService? avatarService;

  const EditableProfileAvatar({
    super.key,
    required this.user,
    this.radius = 60,
    this.avatarService,
  });

  @override
  State<EditableProfileAvatar> createState() => _EditableProfileAvatarState();
}

class _EditableProfileAvatarState extends State<EditableProfileAvatar> {
  late final AvatarService _service = widget.avatarService ?? AvatarService();
  bool _busy = false;

  Future<void> _onPressed() async {
    if (_busy) return;
    final canUseCamera = await _service.canUseCamera();
    if (!mounted) return;
    final action = await showAvatarSourceSheet(
      context,
      canUseCamera: canUseCamera,
      hasAvatar: widget.user.avatarUrl != null,
    );
    if (action == null || !mounted) return;

    final bloc = context.read<AuthBloc>();
    if (action == AvatarAction.remove) {
      bloc.add(const AuthRemoveAvatarRequested());
      return;
    }

    setState(() => _busy = true);
    final result = await _service.pick(action);
    if (!mounted) return;
    setState(() => _busy = false);

    switch (result.status) {
      case AvatarPickStatus.picked:
        bloc.add(AuthUploadAvatarRequested(jpegBytes: result.bytes!));
      case AvatarPickStatus.cancelled:
        break;
      case AvatarPickStatus.permissionDenied:
        await showAvatarPermissionHint(
          context,
          action: action,
          canOpenSettings: _service.device.canOpenSettings,
          onOpenSettings: () async {
            await _service.device.openAppSettings();
          },
        );
      case AvatarPickStatus.unavailable:
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.avatarImageUnavailable)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return BlocConsumer<AuthBloc, AuthState>(
      listenWhen: (_, state) =>
          state is AuthAvatarUpdateFailure || state is AuthAvatarUpdated,
      listener: (context, state) {
        if (state is AuthAvatarUpdated) {
          UserAvatarCache.instance.put(state.user.id, state.user.avatarUrl);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                state.user.avatarUrl == null
                    ? l10n.avatarRemoved
                    : l10n.avatarUpdated,
              ),
            ),
          );
        } else if (state is AuthAvatarUpdateFailure) {
          debugPrint('Profilbild: ${state.message}');
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.avatarUploadFailed)));
        }
      },
      buildWhen: (previous, current) =>
          (previous is AuthAvatarUpdating) != (current is AuthAvatarUpdating),
      builder: (context, state) {
        final working = _busy || state is AuthAvatarUpdating;
        final buttonSize = widget.radius * 0.6;
        return SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              GestureDetector(
                onTap: working ? null : _onPressed,
                child: UserAvatar(
                  userId: widget.user.id,
                  name: widget.user.displayName,
                  avatarUrl: widget.user.avatarUrl,
                  urlIsAuthoritative: true,
                  radius: widget.radius,
                ),
              ),
              if (working)
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                  ),
                ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  elevation: 2,
                  child: IconButton(
                    key: const ValueKey('avatar-camera-button'),
                    tooltip: l10n.avatarChange,
                    constraints: BoxConstraints.tight(
                      Size(buttonSize.clamp(36, 48), buttonSize.clamp(36, 48)),
                    ),
                    padding: EdgeInsets.zero,
                    iconSize: (buttonSize * 0.5).clamp(18, 24),
                    icon: Icon(Icons.camera_alt, color: scheme.onPrimary),
                    onPressed: working ? null : _onPressed,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/auth/auth_state.dart';
import '../../design/td_design.dart';
import '../../models/chat_message_model.dart';
import '../../repositories/chat_repository.dart';
import '../../repositories/todo_repository.dart';
import '../../design/attachments/td_attachments.dart';
import '../../models/anhang_model.dart';
import '../../widgets/attachments/anhang_abschnitt.dart';
import '../../widgets/common/user_avatar.dart';

/// Chat zu einer Aufgabe: Sprechblasen mit Tagestrennern, eigene rechts
/// im Markenverlauf, Bilder senden und im Vollbild ansehen.
class ChatScreen extends StatefulWidget {
  const ChatScreen({
    super.key,
    required this.todoId,
    required this.todoTitle,
    this.listId,
  });

  final String todoId;
  final String todoTitle;

  /// Für den Speicherpfad der Bilder; fehlt sie (Push), wird sie geladen.
  final String? listId;

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  String? _listId;
  String _title = '';
  bool _sending = false;
  double? _uploadProgress;

  @override
  void initState() {
    super.initState();
    _listId = widget.listId;
    _title = widget.todoTitle;
    _markMessagesAsRead();
    if (_listId == null || _title.isEmpty) _loadTodo();
  }

  Future<void> _loadTodo() async {
    final repo = context.read<TodoRepository>();
    if (repo is! FirebaseTodoRepository) return;
    final todo = await repo.getTodoById(widget.todoId);
    if (!mounted || todo == null) return;
    setState(() {
      _listId ??= todo.listId;
      if (_title.isEmpty) _title = todo.title;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  AuthAuthenticated? get _auth {
    final s = context.read<AuthBloc>().state;
    return s is AuthAuthenticated ? s : null;
  }

  Future<void> _markMessagesAsRead() async {
    final auth = _auth;
    if (auth == null) return;
    await context.read<ChatRepository>().markAsRead(
      widget.todoId,
      auth.user.id,
    );
  }

  Future<void> _send({String? imagePath, String? imagePreviewPath}) async {
    final text = imagePath == null ? _controller.text.trim() : '';
    if (text.isEmpty && imagePath == null) return;
    final auth = _auth;
    if (auth == null || _sending) return;
    setState(() => _sending = true);
    final user = auth.user;
    final message = ChatMessageModel(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      todoId: widget.todoId,
      userId: user.id,
      userName: user.displayName,
      message: text,
      timestamp: DateTime.now(),
      imagePath: imagePath,
      imagePreviewPath: imagePreviewPath,
    );
    try {
      await context.read<ChatRepository>().sendMessage(message);
      if (imagePath == null) _controller.clear();
    } catch (e) {
      debugPrint('Nachricht senden fehlgeschlagen: $e');
      if (mounted) {
        TdToast.show(
          context,
          AppLocalizations.of(context)!.saveFailed,
          variant: TdToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Bilder wählen (Kamera oder Galerie), verkleinert hochladen und je
  /// Bild eine Nachricht senden. Gleicher Dienst wie Anhänge an Aufgaben.
  Future<void> _attachImage() async {
    final auth = _auth;
    final listId = _listId;
    if (auth == null || listId == null) return;
    final service = context.read<AttachmentService>();
    final dateien = await anhaengeWaehlen(
      context,
      service: service,
      dokumentErlaubt: false,
    );
    if (dateien.isEmpty || !mounted) return;
    setState(() => _uploadProgress = 0);
    try {
      for (final d in dateien) {
        await for (final f in service.hochladen(
          basisPfad: 'chats/$listId/${widget.todoId}',
          datei: d,
          userId: auth.user.id,
        )) {
          if (mounted) setState(() => _uploadProgress = f.fortschritt);
          final a = f.fertig;
          if (a != null) {
            await _send(imagePath: a.pfad, imagePreviewPath: a.vorschauPfad);
          }
        }
      }
    } catch (e) {
      debugPrint('Bild senden fehlgeschlagen: $e');
      if (mounted) {
        TdToast.show(
          context,
          anhangL10n(context).anhangFehler(e),
          variant: TdToastVariant.error,
        );
      }
    } finally {
      if (mounted) setState(() => _uploadProgress = null);
    }
  }

  /// Chat-Bild als Anhang für das gemeinsame Vollbild.
  static Anhang _alsAnhang(ChatMessageModel m) => Anhang(
    id: 'chat-${m.id}',
    name: m.userName,
    typ: 'image/jpeg',
    groesse: 0,
    pfad: m.imagePath!,
    vorschauPfad: m.imagePreviewPath,
    hochgeladenVon: m.userId,
    hochgeladenAm: m.timestamp,
  );

  void _openImage(List<ChatMessageModel> images, ChatMessageModel msg) {
    TdAnhangVollbild.oeffnen(
      context,
      anhaenge: images.map(_alsAnhang).toList(),
      start: images.indexOf(msg),
      service: context.read<AttachmentService>(),
      heroPraefix: 'chat',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    if (l10n == null) return const SizedBox.shrink();
    final uid = _auth?.user.id ?? '';
    final scheme = context.colors;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _title.isEmpty ? l10n.chat : _title,
              style: context.text.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(l10n.chatSubtitle, style: context.text.bodySmall),
          ],
        ),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<ChatMessageModel>>(
                  stream: context.read<ChatRepository>().getMessages(
                    widget.todoId,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final messages = snapshot.data!;
                    if (messages.isEmpty) {
                      return Center(
                        child: TdEmptyState(
                          icon: Icons.forum_outlined,
                          title: l10n.noMessagesYet,
                          message: l10n.chatEmptyMessage,
                        ),
                      );
                    }
                    final images = messages.where((m) => m.hasImage).toList();
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(
                        TdSpace.lg,
                        TdSpace.lg,
                        TdSpace.lg,
                        TdSpace.sm,
                      ),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final i = messages.length - 1 - index;
                        final msg = messages[i];
                        final prev = i > 0 ? messages[i - 1] : null;
                        final isMe = msg.userId == uid;
                        final newDay =
                            prev == null ||
                            !_sameDay(prev.timestamp, msg.timestamp);
                        final sameAuthor =
                            prev != null &&
                            prev.userId == msg.userId &&
                            !newDay;
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (newDay) _DayDivider(date: msg.timestamp),
                            _Bubble(
                              message: msg,
                              isMe: isMe,
                              showName: !isMe && !sameAuthor,
                              onImageTap: msg.hasImage
                                  ? () => _openImage(images, msg)
                                  : null,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),
              if (_uploadProgress != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: TdSpace.lg),
                  child: TdProgressBar(value: _uploadProgress!, height: 4),
                ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(
                    TdSpace.md,
                    TdSpace.sm,
                    TdSpace.md,
                    TdSpace.md,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      TdIconButton(
                        icon: Icons.add_photo_alternate_outlined,
                        tooltip: l10n.attachmentSendImage,
                        size: 48,
                        onPressed: _uploadProgress == null && _listId != null
                            ? _attachImage
                            : null,
                      ),
                      const SizedBox(width: TdSpace.sm),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          textInputAction: TextInputAction.send,
                          decoration: InputDecoration(
                            hintText: l10n.enterMessage,
                            fillColor: scheme.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: TdSpace.lg,
                              vertical: TdSpace.md,
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: TdSpace.sm),
                      ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, v, _) => _SendButton(
                          enabled: v.text.trim().isNotEmpty && !_sending,
                          loading: _sending,
                          tooltip: l10n.send,
                          onPressed: _send,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _SendButton extends StatelessWidget {
  const _SendButton({
    required this.enabled,
    required this.loading,
    required this.onPressed,
    this.tooltip,
  });

  final bool enabled;
  final bool loading;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    return TdPressable(
      onTap: enabled ? onPressed : null,
      enabled: enabled,
      haptic: true,
      scale: 0.9,
      semanticLabel: tooltip,
      child: AnimatedContainer(
        duration: TdMotion.of(context, TdMotion.base),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: enabled ? td.primaryGradient : null,
          color: enabled ? null : scheme.surfaceContainerHighest,
          borderRadius: TdRadius.control,
          boxShadow: enabled ? TdShadows.glow(scheme.primary) : null,
        ),
        alignment: Alignment.center,
        child: loading
            ? SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: td.palette.onPrimary,
                ),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                color: enabled ? td.palette.onPrimary : scheme.onSurfaceVariant,
              ),
      ),
    );
  }
}

class _DayDivider extends StatelessWidget {
  const _DayDivider({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(date.year, date.month, date.day);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final label = day == today
        ? l10n.dueToday
        : day == today.subtract(const Duration(days: 1))
        ? l10n.yesterday
        : DateFormat.MMMEd(locale).format(date);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: TdSpace.md),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TdSpace.md),
            child: Text(label, style: context.text.labelSmall),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.message,
    required this.isMe,
    required this.showName,
    this.onImageTap,
  });

  final ChatMessageModel message;
  final bool isMe;
  final bool showName;
  final VoidCallback? onImageTap;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final scheme = context.colors;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.Hm(locale).format(message.timestamp);
    final fg = isMe ? td.palette.onPrimary : scheme.onSurface;
    final radius = BorderRadius.only(
      topLeft: const Radius.circular(TdRadius.lg),
      topRight: const Radius.circular(TdRadius.lg),
      bottomLeft: Radius.circular(isMe ? TdRadius.lg : TdRadius.xs),
      bottomRight: Radius.circular(isMe ? TdRadius.xs : TdRadius.lg),
    );

    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.72,
      ),
      decoration: BoxDecoration(
        gradient: isMe ? td.primaryGradient : null,
        color: isMe ? null : scheme.surface,
        borderRadius: radius,
        border: isMe ? null : Border.all(color: scheme.outlineVariant),
        boxShadow: isMe ? td.shadowSoft : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (message.hasImage)
            GestureDetector(
              onTap: onImageTap,
              child: Hero(
                tag: tdAnhangHeroTag(
                  'chat',
                  _ChatScreenState._alsAnhang(message),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: TdAnhangBild(
                    service: context.read<AttachmentService>(),
                    pfad: message.imagePreviewPath ?? message.imagePath!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TdSpace.md,
              TdSpace.sm + 2,
              TdSpace.md,
              TdSpace.sm,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      message.userName,
                      style: context.text.labelSmall?.copyWith(
                        color: scheme.primary,
                      ),
                    ),
                  ),
                if (message.message.isNotEmpty)
                  Text(
                    message.message,
                    style: context.text.bodyMedium?.copyWith(color: fg),
                  ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(
                    time,
                    style: context.text.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: showName ? TdSpace.md : TdSpace.xs),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: TdSpace.sm),
              child: showName
                  ? UserAvatar(
                      userId: message.userId,
                      name: message.userName,
                      radius: 14,
                    )
                  : const SizedBox(width: 28),
            ),
          TdFadeSlideIn(offset: const Offset(0, 0.15), child: bubble),
        ],
      ),
    );
  }
}

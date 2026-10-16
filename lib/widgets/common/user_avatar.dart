/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Liefert Profilbild-Adressen anderer Nutzer und merkt sie sich für die
/// Laufzeit der App, damit Listen nicht für jede Zeile neu nachfragen.
class UserAvatarCache {
  UserAvatarCache._();

  static final UserAvatarCache instance = UserAvatarCache._();

  /// Für Tests austauschbar; ohne Wert wird Firestore gefragt.
  Future<String?> Function(String userId)? loaderOverride;

  final Map<String, String?> _urls = {};
  final Map<String, Future<String?>> _pending = {};

  /// Bereits bekannte Adresse (oder `null`, wenn unbekannt/kein Bild).
  String? peek(String userId) => _urls[userId];

  bool contains(String userId) => _urls.containsKey(userId);

  Future<String?> urlFor(String userId) {
    if (_urls.containsKey(userId)) return Future.value(_urls[userId]);
    return _pending[userId] ??= _load(userId).then((url) {
      _urls[userId] = url;
      _pending.remove(userId);
      return url;
    });
  }

  /// Nach eigenem Upload/Löschen sofort den neuen Stand eintragen.
  void put(String userId, String? url) {
    _urls[userId] = url;
    _pending.remove(userId);
  }

  void clear() {
    _urls.clear();
    _pending.clear();
  }

  Future<String?> _load(String userId) async {
    final override = loaderOverride;
    if (override != null) return override(userId);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
      final url = doc.data()?['avatarUrl'];
      return url is String && url.isNotEmpty ? url : null;
    } catch (e) {
      // Kein Zugriff oder offline: Initialen anzeigen.
      debugPrint('Profilbild für $userId nicht ladbar: $e');
      return null;
    }
  }
}

/// Bildet bis zu zwei Initialen aus einem Namen („Martin Bundschuh“ → „MB“).
String initialsFor(String name) {
  final parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  String first(String s) => String.fromCharCodes(s.runes.take(1)).toUpperCase();
  if (parts.length == 1) return first(parts.first);
  return first(parts.first) + first(parts.last);
}

/// Rundes Nutzerbild mit Initialen als Ersatz.
///
/// Ist [avatarUrl] gesetzt, wird es direkt verwendet. Sonst wird – falls eine
/// [userId] bekannt ist – das Bild über den [UserAvatarCache] nachgeladen.
class UserAvatar extends StatefulWidget {
  final String? userId;
  final String name;
  final String? avatarUrl;
  final double radius;

  /// `true`, wenn [avatarUrl] maßgeblich ist (auch wenn `null`), z. B. beim
  /// eigenen Profil. Dann wird nichts nachgeladen.
  final bool urlIsAuthoritative;

  const UserAvatar({
    super.key,
    this.userId,
    required this.name,
    this.avatarUrl,
    this.radius = 20,
    this.urlIsAuthoritative = false,
  });

  @override
  State<UserAvatar> createState() => _UserAvatarState();
}

class _UserAvatarState extends State<UserAvatar> {
  String? _url;
  bool _imageFailed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant UserAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.avatarUrl != widget.avatarUrl ||
        oldWidget.userId != widget.userId ||
        oldWidget.urlIsAuthoritative != widget.urlIsAuthoritative) {
      _imageFailed = false;
      _resolve();
    }
  }

  void _resolve() {
    if (widget.avatarUrl != null || widget.urlIsAuthoritative) {
      _url = widget.avatarUrl;
      return;
    }
    final id = widget.userId;
    if (id == null || id.isEmpty) {
      _url = null;
      return;
    }
    final cache = UserAvatarCache.instance;
    if (cache.contains(id)) {
      _url = cache.peek(id);
      return;
    }
    _url = null;
    cache.urlFor(id).then((url) {
      if (!mounted || widget.userId != id) return;
      if (url != _url) setState(() => _url = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = _imageFailed ? null : _url;
    final initials = Text(
      initialsFor(widget.name),
      key: const ValueKey('user-avatar-initials'),
      style: TextStyle(
        fontSize: widget.radius * 0.8,
        fontWeight: FontWeight.bold,
        color: scheme.onPrimaryContainer,
      ),
    );
    return Semantics(
      label: widget.name,
      image: true,
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: scheme.primaryContainer,
        foregroundImage: url != null ? NetworkImage(url) : null,
        onForegroundImageError: url != null
            ? (_, _) {
                if (mounted) setState(() => _imageFailed = true);
              }
            : null,
        child: initials,
      ),
    );
  }
}

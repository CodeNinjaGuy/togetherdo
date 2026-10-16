/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

/// Einstellungen für E-Mails: Termin-Erinnerungen per Push/E-Mail/beides/
/// keine, Wochen- und Monatsüberblick, Einladungen. Liest und schreibt
/// `users/{uid}.mailEinstellungen` (die Functions werten es aus).
/// Wird vom Stufe-4-Helfer ins Profil eingebaut:
/// `MailEinstellungen(userId: uid)`.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/fehler_text.dart';
import '../../design/td_design.dart';
import '../../l10n/app_localizations.dart';

/// Gespeicherte Werte (Standard wie in den Functions).
class MailEinstellungenWerte {
  const MailEinstellungenWerte({
    this.erinnerungen = 'push',
    this.wochenueberblick = false,
    this.monatsueberblick = false,
    this.einladungen = true,
  });

  /// `push` | `mail` | `beide` | `keine`
  final String erinnerungen;
  final bool wochenueberblick;
  final bool monatsueberblick;
  final bool einladungen;

  factory MailEinstellungenWerte.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const MailEinstellungenWerte();
    return MailEinstellungenWerte(
      erinnerungen: json['erinnerungen'] as String? ?? 'push',
      wochenueberblick: json['wochenueberblick'] as bool? ?? false,
      monatsueberblick: json['monatsueberblick'] as bool? ?? false,
      einladungen: json['einladungen'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'erinnerungen': erinnerungen,
    'wochenueberblick': wochenueberblick,
    'monatsueberblick': monatsueberblick,
    'einladungen': einladungen,
  };

  MailEinstellungenWerte copyWith({
    String? erinnerungen,
    bool? wochenueberblick,
    bool? monatsueberblick,
    bool? einladungen,
  }) => MailEinstellungenWerte(
    erinnerungen: erinnerungen ?? this.erinnerungen,
    wochenueberblick: wochenueberblick ?? this.wochenueberblick,
    monatsueberblick: monatsueberblick ?? this.monatsueberblick,
    einladungen: einladungen ?? this.einladungen,
  );
}

/// Speicherort – austauschbar für Tests.
abstract class MailEinstellungenSpeicher {
  Stream<MailEinstellungenWerte> beobachten(String userId);
  Future<void> speichern(String userId, MailEinstellungenWerte werte);
}

class FirestoreMailEinstellungenSpeicher implements MailEinstellungenSpeicher {
  FirestoreMailEinstellungenSpeicher({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  @override
  Stream<MailEinstellungenWerte> beobachten(String userId) => _db
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((d) => MailEinstellungenWerte.fromJson(
            (d.data()?['mailEinstellungen'] as Map?)?.cast<String, dynamic>(),
          ));

  @override
  Future<void> speichern(String userId, MailEinstellungenWerte werte) =>
      _db.collection('users').doc(userId).set(
        {'mailEinstellungen': werte.toJson()},
        SetOptions(merge: true),
      );
}

class SpeicherMailEinstellungen implements MailEinstellungenSpeicher {
  SpeicherMailEinstellungen([this.werte = const MailEinstellungenWerte()]);

  MailEinstellungenWerte werte;

  @override
  Stream<MailEinstellungenWerte> beobachten(String userId) => Stream.value(werte);

  @override
  Future<void> speichern(String userId, MailEinstellungenWerte w) async => werte = w;
}

class MailEinstellungen extends StatefulWidget {
  const MailEinstellungen({super.key, required this.userId, this.speicher});

  final String userId;
  final MailEinstellungenSpeicher? speicher;

  @override
  State<MailEinstellungen> createState() => _MailEinstellungenState();
}

class _MailEinstellungenState extends State<MailEinstellungen> {
  late final MailEinstellungenSpeicher _speicher =
      widget.speicher ?? FirestoreMailEinstellungenSpeicher();
  MailEinstellungenWerte? _lokal;

  Future<void> _setzen(MailEinstellungenWerte w) async {
    setState(() => _lokal = w);
    try {
      await _speicher.speichern(widget.userId, w);
    } catch (e) {
      if (!mounted) return;
      final s = AppLocalizations.of(context)!;
      TdToast.show(context, kalFehlerText(s, e), variant: TdToastVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocalizations.of(context)!;
    return StreamBuilder<MailEinstellungenWerte>(
      stream: _speicher.beobachten(widget.userId),
      builder: (ctx, snap) {
        final w = _lokal ?? snap.data ?? const MailEinstellungenWerte();
        return TdCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.mail_outline_rounded, color: ctx.td.palette.primary),
                  const SizedBox(width: TdSpace.sm),
                  Text(s.kalMailEinstellungen, style: ctx.text.titleMedium),
                ],
              ),
              const SizedBox(height: TdSpace.md),
              Text(s.kalMailErinnerungen, style: ctx.text.labelMedium?.copyWith(color: ctx.td.muted)),
              const SizedBox(height: TdSpace.xs),
              Wrap(
                spacing: TdSpace.sm,
                runSpacing: TdSpace.sm,
                children: [
                  for (final (wert, label, icon) in [
                    ('push', s.kalMailPush, Icons.notifications_rounded),
                    ('mail', s.kalMailMail, Icons.mail_rounded),
                    ('beide', s.kalMailBeide, Icons.done_all_rounded),
                    ('keine', s.kalMailKeine, Icons.notifications_off_rounded),
                  ])
                    TdChip(
                      label: label,
                      icon: icon,
                      dense: true,
                      selected: w.erinnerungen == wert,
                      onTap: () => _setzen(w.copyWith(erinnerungen: wert)),
                    ),
                ],
              ),
              const SizedBox(height: TdSpace.sm),
              _Schalter(
                label: s.kalMailWochenueberblick,
                wert: w.wochenueberblick,
                onChanged: (v) => _setzen(w.copyWith(wochenueberblick: v)),
              ),
              _Schalter(
                label: s.kalMailMonatsueberblick,
                wert: w.monatsueberblick,
                onChanged: (v) => _setzen(w.copyWith(monatsueberblick: v)),
              ),
              _Schalter(
                label: s.kalMailEinladungen,
                wert: w.einladungen,
                onChanged: (v) => _setzen(w.copyWith(einladungen: v)),
              ),
              const SizedBox(height: TdSpace.xs),
              Text(s.kalMailHinweis, style: ctx.text.bodySmall),
            ],
          ),
        );
      },
    );
  }
}

class _Schalter extends StatelessWidget {
  const _Schalter({required this.label, required this.wert, required this.onChanged});

  final String label;
  final bool wert;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: TdSpace.xs),
    child: Row(
      children: [
        Expanded(child: Text(label, style: context.text.bodyMedium)),
        Switch.adaptive(value: wert, onChanged: onChanged),
      ],
    ),
  );
}

/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../../models/anhang_model.dart';
import '../../services/attachment_service.dart';
import '../components/td_pressable.dart';
import '../components/td_progress.dart';
import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';
import 'anhang_texte.dart';
import 'td_anhang_bild.dart';
import 'td_anhang_vollbild.dart';

/// Hero-Kennung einer Kachel (Galerie und Vollbild nutzen dieselbe).
String tdAnhangHeroTag(String praefix, Anhang a) => '$praefix-anhang-${a.id}';

/// Waagerechte Kachelreihe der Anhänge eines Eintrags: Bilder als
/// Vorschau, Dokumente mit Symbol, Name und Größe, laufende Uploads mit
/// Fortschrittsring, am Ende eine Plus-Kachel. Antippen öffnet das Vollbild.
///
/// Löschen: Der Baustein löscht die Datei über den [service] und ruft dann
/// [onLoeschen] auf; der Aufrufer entfernt nur noch den Eintrag aus dem
/// Dokument.
class TdAnhangGalerie extends StatelessWidget {
  const TdAnhangGalerie({
    super.key,
    required this.anhaenge,
    required this.service,
    this.laufend = const {},
    this.darfLoeschen,
    this.onLoeschen,
    this.onHinzufuegen,
    this.kachelGroesse = 96,
    this.padding = const EdgeInsets.symmetric(horizontal: TdSpace.page),
    this.heroPraefix = 'galerie',
  });

  final List<Anhang> anhaenge;
  final AttachmentService service;

  /// Laufende Uploads, Schlüssel = `UploadFortschritt.anhangId`.
  final Map<String, UploadFortschritt> laufend;

  /// Ob der Nutzer diesen Anhang löschen darf. Ohne Angabe: nie.
  final bool Function(Anhang a)? darfLoeschen;

  /// Nach erfolgreichem Löschen in Storage.
  final ValueChanged<Anhang>? onLoeschen;

  /// Plus-Kachel; ohne Angabe wird keine gezeigt.
  final VoidCallback? onHinzufuegen;
  final double kachelGroesse;
  final EdgeInsetsGeometry padding;

  /// Unterscheidet Hero-Kennungen, wenn mehrere Galerien auf einer Seite
  /// dieselben Anhänge zeigen.
  final String heroPraefix;

  bool get _vollzaehlig =>
      anhaenge.length + laufend.length >= AnhangGrenzen.maxAnzahl;

  @override
  Widget build(BuildContext context) {
    final zeigePlus = onHinzufuegen != null && !_vollzaehlig;
    final anzahl = anhaenge.length + laufend.length + (zeigePlus ? 1 : 0);
    final laufende = laufend.values.toList();
    return SizedBox(
      height: kachelGroesse,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: anzahl,
        clipBehavior: Clip.none,
        separatorBuilder: (_, _) => const SizedBox(width: TdSpace.md),
        itemBuilder: (context, i) {
          if (i < anhaenge.length) {
            final a = anhaenge[i];
            return _AnhangKachel(
              anhang: a,
              service: service,
              groesse: kachelGroesse,
              heroTag: tdAnhangHeroTag(heroPraefix, a),
              onTap: () => TdAnhangVollbild.oeffnen(
                context,
                anhaenge: anhaenge,
                start: i,
                service: service,
                darfLoeschen: darfLoeschen,
                onLoeschen: onLoeschen,
                heroPraefix: heroPraefix,
              ),
            );
          }
          final j = i - anhaenge.length;
          if (j < laufende.length) {
            return _UploadKachel(
              fortschritt: laufende[j],
              groesse: kachelGroesse,
            );
          }
          return _PlusKachel(groesse: kachelGroesse, onTap: onHinzufuegen!);
        },
      ),
    );
  }
}

/// Kompakte Zeilenliste: Symbol/Vorschau, Name, Typ · Größe und ein Menü
/// mit Öffnen, Teilen und (wenn erlaubt) Löschen.
class TdAnhangListe extends StatelessWidget {
  const TdAnhangListe({
    super.key,
    required this.anhaenge,
    required this.service,
    this.laufend = const {},
    this.darfLoeschen,
    this.onLoeschen,
    this.heroPraefix = 'liste',
  });

  final List<Anhang> anhaenge;
  final AttachmentService service;
  final Map<String, UploadFortschritt> laufend;
  final bool Function(Anhang a)? darfLoeschen;
  final ValueChanged<Anhang>? onLoeschen;
  final String heroPraefix;

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final scheme = context.colors;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < anhaenge.length; i++)
          _AnhangZeile(
            anhang: anhaenge[i],
            service: service,
            heroTag: tdAnhangHeroTag(heroPraefix, anhaenge[i]),
            darfLoeschen: darfLoeschen?.call(anhaenge[i]) ?? false,
            onTap: () => TdAnhangVollbild.oeffnen(
              context,
              anhaenge: anhaenge,
              start: i,
              service: service,
              darfLoeschen: darfLoeschen,
              onLoeschen: onLoeschen,
              heroPraefix: heroPraefix,
            ),
            onLoeschen: () => tdAnhangLoeschenMitRueckfrage(
              context,
              anhang: anhaenge[i],
              service: service,
              onGeloescht: onLoeschen,
            ),
          ),
        for (final f in laufend.values)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: TdSpace.sm),
            child: Row(
              children: [
                TdRingProgress(value: f.fortschritt, size: 36, stroke: 4),
                const SizedBox(width: TdSpace.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.name,
                        style: context.text.bodyMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        l.anhangWirdHochgeladen,
                        style: context.text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Fragt nach, löscht in Storage und meldet das Ergebnis. Liefert `true`,
/// wenn gelöscht wurde.
Future<bool> tdAnhangLoeschenMitRueckfrage(
  BuildContext context, {
  required Anhang anhang,
  required AttachmentService service,
  ValueChanged<Anhang>? onGeloescht,
}) async {
  final l = anhangL10n(context);
  final ja = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.anhangLoeschenFrage(anhang.name)),
      content: Text(l.anhangLoeschenHinweis),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l.anhangAbbrechen),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: TextButton.styleFrom(foregroundColor: ctx.td.danger),
          child: Text(l.anhangLoeschen),
        ),
      ],
    ),
  );
  if (ja != true) return false;
  try {
    await service.loeschen(anhang);
  } catch (_) {
    return false;
  }
  onGeloescht?.call(anhang);
  return true;
}

// ---------------------------------------------------------------------------

class _AnhangKachel extends StatelessWidget {
  const _AnhangKachel({
    required this.anhang,
    required this.service,
    required this.groesse,
    required this.heroTag,
    required this.onTap,
  });

  final Anhang anhang;
  final AttachmentService service;
  final double groesse;
  final String heroTag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final scheme = context.colors;
    final td = context.td;
    final reduced = TdMotion.reduced(context);

    Widget inhalt;
    if (anhang.istBild) {
      inhalt = TdAnhangBild(
        service: service,
        pfad: anhang.vorschauPfad ?? anhang.pfad,
      );
    } else {
      final akzent = anhang.istPdf ? td.danger : scheme.primary;
      inhalt = Container(
        color: scheme.surface,
        padding: const EdgeInsets.all(TdSpace.sm),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(anhangSymbol(anhang.typ), size: 30, color: akzent),
            const SizedBox(height: TdSpace.xs),
            Text(
              anhang.name,
              style: context.text.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
            Text(
              l.anhangGroesse(anhang.groesse),
              style: context.text.labelSmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    Widget kachel = Container(
      width: groesse,
      height: groesse,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: TdRadius.control,
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surfaceContainerHigh,
      ),
      child: inhalt,
    );
    if (!reduced) kachel = Hero(tag: heroTag, child: kachel);

    return Semantics(
      label: '${l.anhangTyp(anhang)}: ${anhang.name}',
      button: true,
      child: TdPressable(
        onTap: onTap,
        scale: 0.95,
        borderRadius: TdRadius.control,
        child: kachel,
      ),
    );
  }
}

class _UploadKachel extends StatelessWidget {
  const _UploadKachel({required this.fortschritt, required this.groesse});

  final UploadFortschritt fortschritt;
  final double groesse;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final prozent = (fortschritt.fortschritt * 100).round();
    return Semantics(
      label: '${anhangL10n(context).anhangWirdHochgeladen} $prozent %',
      child: Container(
        width: groesse,
        height: groesse,
        decoration: BoxDecoration(
          borderRadius: TdRadius.control,
          border: Border.all(color: scheme.outlineVariant),
          color: scheme.surfaceContainerHigh,
        ),
        alignment: Alignment.center,
        child: TdRingProgress(
          value: fortschritt.fortschritt,
          size: groesse * 0.5,
          stroke: 4,
          child: Text(
            '$prozent',
            style: context.text.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _PlusKachel extends StatelessWidget {
  const _PlusKachel({required this.groesse, required this.onTap});

  final double groesse;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l = anhangL10n(context);
    return TdPressable(
      onTap: onTap,
      haptic: true,
      scale: 0.93,
      semanticLabel: l.anhangHinzufuegen,
      borderRadius: TdRadius.control,
      child: Container(
        width: groesse,
        height: groesse,
        decoration: BoxDecoration(
          borderRadius: TdRadius.control,
          border: Border.all(
            color: scheme.primary.withValues(alpha: 0.5),
            width: 1.5,
          ),
          color: scheme.primaryContainer.withValues(alpha: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 30, color: scheme.primary),
            const SizedBox(height: TdSpace.xs),
            Text(
              l.anhangHinzufuegen,
              style: context.text.labelSmall?.copyWith(color: scheme.primary),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnhangZeile extends StatelessWidget {
  const _AnhangZeile({
    required this.anhang,
    required this.service,
    required this.heroTag,
    required this.darfLoeschen,
    required this.onTap,
    required this.onLoeschen,
  });

  final Anhang anhang;
  final AttachmentService service;
  final String heroTag;
  final bool darfLoeschen;
  final VoidCallback onTap;
  final VoidCallback onLoeschen;

  @override
  Widget build(BuildContext context) {
    final l = anhangL10n(context);
    final scheme = context.colors;
    final td = context.td;
    final reduced = TdMotion.reduced(context);

    Widget vorschau = Container(
      width: 44,
      height: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TdRadius.sm),
        color: scheme.surfaceContainerHigh,
      ),
      alignment: Alignment.center,
      child: anhang.istBild
          ? TdAnhangBild(
              service: service,
              pfad: anhang.vorschauPfad ?? anhang.pfad,
            )
          : Icon(
              anhangSymbol(anhang.typ),
              color: anhang.istPdf ? td.danger : scheme.primary,
            ),
    );
    if (!reduced) vorschau = Hero(tag: heroTag, child: vorschau);

    return TdPressable(
      onTap: onTap,
      borderRadius: TdRadius.control,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TdSpace.sm),
        child: Row(
          children: [
            vorschau,
            const SizedBox(width: TdSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    anhang.name,
                    style: context.text.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${l.anhangTyp(anhang)} · ${l.anhangGroesse(anhang.groesse)}',
                    style: context.text.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton<_ZeilenAktion>(
              tooltip: l.anhangWeitereAktionen,
              icon: Icon(
                Icons.more_horiz_rounded,
                color: scheme.onSurfaceVariant,
              ),
              onSelected: (a) {
                switch (a) {
                  case _ZeilenAktion.oeffnen:
                    service.oeffnen(anhang);
                  case _ZeilenAktion.teilen:
                    service.teilen(anhang);
                  case _ZeilenAktion.loeschen:
                    onLoeschen();
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _ZeilenAktion.oeffnen,
                  child: ListTile(
                    leading: const Icon(Icons.open_in_new_rounded),
                    title: Text(l.anhangOeffnen),
                  ),
                ),
                PopupMenuItem(
                  value: _ZeilenAktion.teilen,
                  child: ListTile(
                    leading: const Icon(Icons.ios_share_rounded),
                    title: Text(l.anhangTeilen),
                  ),
                ),
                if (darfLoeschen)
                  PopupMenuItem(
                    value: _ZeilenAktion.loeschen,
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline_rounded,
                        color: td.danger,
                      ),
                      title: Text(
                        l.anhangLoeschen,
                        style: TextStyle(color: td.danger),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _ZeilenAktion { oeffnen, teilen, loeschen }

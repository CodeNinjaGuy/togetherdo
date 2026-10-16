/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'package:flutter/material.dart';

import '../td_design.dart';
import 'showcase_data.dart';
import 'showcase_strings.dart';

/// Galerie aller Bausteine (nur Debug). Auf breiten Bildschirmen stehen
/// die gewählte Palette und ihr Gegenstück (hell ↔ dunkel) nebeneinander;
/// auf dem Handy schaltet ein Umschalter um.
class TdDesignGalleryScreen extends StatefulWidget {
  const TdDesignGalleryScreen({super.key, this.initialPaletteId = 'Light'});

  final String initialPaletteId;

  @override
  State<TdDesignGalleryScreen> createState() => _TdDesignGalleryScreenState();
}

class _TdDesignGalleryScreenState extends State<TdDesignGalleryScreen> {
  late String _paletteId = widget.initialPaletteId;
  bool _showDark = false;

  TdPalette get _palette => TdPalettes.byId(_paletteId);

  /// Gegenstück: Light ↔ Dark, sonst die Markenpalette der anderen Helligkeit.
  TdPalette get _counterpart => switch (_paletteId) {
    'Light' => TdPalettes.dark,
    'Dark' => TdPalettes.light,
    _ => _palette.isDark ? TdPalettes.light : TdPalettes.dark,
  };

  @override
  Widget build(BuildContext context) {
    final s = ShowcaseStrings.of(context);
    final wide = context.tdLayout != TdLayoutSize.compact;

    final first = _palette.isDark ? _counterpart : _palette;
    final second = _palette.isDark ? _palette : _counterpart;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.galleryTitle),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: TdSpace.md),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _paletteId,
                borderRadius: TdRadius.control,
                items: [
                  for (final p in TdPalettes.all)
                    DropdownMenuItem(
                      value: p.id,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: p.resolvedHeroGradient,
                              ),
                            ),
                          ),
                          const SizedBox(width: TdSpace.sm),
                          Text(p.id),
                        ],
                      ),
                    ),
                ],
                onChanged: (v) => setState(() => _paletteId = v ?? 'Light'),
              ),
            ),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: [
                Expanded(child: _ThemedColumn(palette: first)),
                Expanded(child: _ThemedColumn(palette: second)),
              ],
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(TdSpace.md),
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(s.light),
                        icon: const Icon(Icons.light_mode_outlined),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(s.dark),
                        icon: const Icon(Icons.dark_mode_outlined),
                      ),
                    ],
                    selected: {_showDark},
                    onSelectionChanged: (v) =>
                        setState(() => _showDark = v.first),
                  ),
                ),
                Expanded(
                  child: _ThemedColumn(palette: _showDark ? second : first),
                ),
              ],
            ),
    );
  }
}

class _ThemedColumn extends StatelessWidget {
  const _ThemedColumn({required this.palette});

  final TdPalette palette;

  @override
  Widget build(BuildContext context) {
    final theme = TdThemeBuilder.build(palette);
    return Theme(
      data: theme,
      child: Builder(
        builder: (ctx) => Container(
          color: theme.scaffoldBackgroundColor,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              TdSpace.page,
              TdSpace.lg,
              TdSpace.page,
              TdSpace.xxxl,
            ),
            children: [
              Text(palette.id, style: ctx.text.displaySmall),
              Text(
                palette.isDark ? 'dunkel' : 'hell',
                style: ctx.text.bodySmall,
              ),
              const _Section(title: 'Farben', child: _ColorsDemo()),
              const _Section(title: 'Typografie', child: _TypographyDemo()),
              const _Section(title: 'Knöpfe', child: _ButtonsDemo()),
              const _Section(title: 'Eingabe', child: _InputsDemo()),
              const _Section(title: 'Chips & Etiketten', child: _ChipsDemo()),
              const _Section(title: 'Karten', child: _CardsDemo()),
              const _Section(title: 'Listenzeilen', child: _TilesDemo()),
              const _Section(title: 'Avatare', child: _AvatarsDemo()),
              const _Section(
                title: 'Fortschritt & Fairness',
                child: _ProgressDemo(),
              ),
              const _Section(title: 'Leerzustand', child: _EmptyDemo()),
              const _Section(
                title: 'Sheet, Toast, Konfetti',
                child: _OverlaysDemo(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdSectionHeader(title: title),
        child,
      ],
    );
  }
}

class _ColorsDemo extends StatelessWidget {
  const _ColorsDemo();

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    final c = context.colors;
    final swatches = <(String, Color)>[
      ('primary', c.primary),
      ('secondary', c.secondary),
      ('tertiary', c.tertiary),
      ('success', td.success),
      ('warning', td.warning),
      ('danger', td.danger),
      ('surface', c.surface),
      ('elevated', c.surfaceContainerHigh),
      ('outline', c.outlineVariant),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: td.heroGradient,
            borderRadius: TdRadius.control,
          ),
        ),
        const SizedBox(height: TdSpace.md),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final (name, color) in swatches)
              Column(
                children: [
                  Container(
                    width: 56,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(TdRadius.sm),
                      border: Border.all(color: c.outlineVariant),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(name, style: context.text.labelSmall),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _TypographyDemo extends StatelessWidget {
  const _TypographyDemo();

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Gemeinsam erledigt', style: t.displaySmall),
        Text('Fair verteilt', style: t.headlineMedium),
        Text('Überschrift klein', style: t.headlineSmall),
        Text('Titel mittel', style: t.titleMedium),
        const SizedBox(height: TdSpace.sm),
        Text(
          'Fließtext groß: Paare, Familien und WGs teilen Aufgaben.',
          style: t.bodyLarge,
        ),
        Text(
          'Fließtext mittel: Wer wie viel trägt, wird sichtbar.',
          style: t.bodyMedium,
        ),
        Text('Hinweis klein, gedämpft', style: t.bodySmall),
        const SizedBox(height: TdSpace.sm),
        Text('BESCHRIFTUNG', style: t.labelSmall),
      ],
    );
  }
}

class _ButtonsDemo extends StatefulWidget {
  const _ButtonsDemo();

  @override
  State<_ButtonsDemo> createState() => _ButtonsDemoState();
}

class _ButtonsDemoState extends State<_ButtonsDemo> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TdSpace.md,
      runSpacing: TdSpace.md,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        TdButton.primary(
          label: 'Anlegen',
          icon: Icons.add_rounded,
          loading: _loading,
          onPressed: () async {
            setState(() => _loading = true);
            await Future<void>.delayed(const Duration(milliseconds: 1200));
            if (mounted) setState(() => _loading = false);
          },
        ),
        TdButton.secondary(label: 'Abbrechen', onPressed: () {}),
        TdButton.tonal(
          label: 'Teilen',
          icon: Icons.ios_share_rounded,
          onPressed: () {},
        ),
        TdButton.ghost(label: 'Mehr', onPressed: () {}),
        TdButton.danger(
          label: 'Löschen',
          icon: Icons.delete_outline_rounded,
          onPressed: () {},
        ),
        const TdButton.primary(label: 'Inaktiv'),
        TdButton.primary(
          label: 'Klein',
          size: TdButtonSize.small,
          onPressed: () {},
        ),
        TdIconButton(
          icon: Icons.notifications_outlined,
          badge: 3,
          onPressed: () {},
        ),
        TdIconButton(
          icon: Icons.chat_bubble_outline_rounded,
          filled: true,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _InputsDemo extends StatelessWidget {
  const _InputsDemo();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        TdTextField(
          label: 'E-Mail',
          hint: 'name@beispiel.de',
          prefixIcon: Icons.mail_outline_rounded,
        ),
        SizedBox(height: TdSpace.md),
        TdTextField(
          label: 'Passwort',
          hint: '••••••••',
          prefixIcon: Icons.lock_outline_rounded,
          obscureText: true,
        ),
        SizedBox(height: TdSpace.md),
        TdTextField(hint: 'Suchen …', prefixIcon: Icons.search_rounded),
      ],
    );
  }
}

class _ChipsDemo extends StatefulWidget {
  const _ChipsDemo();

  @override
  State<_ChipsDemo> createState() => _ChipsDemoState();
}

class _ChipsDemoState extends State<_ChipsDemo> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final td = context.td;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            for (final (i, l) in DemoData.lists.indexed)
              TdChip(
                label: l.name,
                icon: l.icon,
                color: l.color,
                selected: _sel == i,
                onTap: () => setState(() => _sel = i),
              ),
          ],
        ),
        const SizedBox(height: TdSpace.md),
        Wrap(
          spacing: TdSpace.sm,
          runSpacing: TdSpace.sm,
          children: [
            const TdTag(
              label: 'Haushalt',
              icon: Icons.home_rounded,
              color: Color(0xFF6A5AE0),
            ),
            TdTag(
              label: 'überfällig',
              icon: Icons.schedule_rounded,
              color: td.danger,
            ),
            TdTag(
              label: 'heute Abend',
              icon: Icons.nightlight_round,
              color: td.warning,
            ),
            const TdTag(
              label: 'heute',
              icon: Icons.today_rounded,
              filled: false,
            ),
            const TdWeightTag(weight: TdWeight.light, label: 'leicht'),
            const TdWeightTag(weight: TdWeight.medium, label: 'mittel'),
            const TdWeightTag(weight: TdWeight.heavy, label: 'schwer'),
          ],
        ),
      ],
    );
  }
}

class _CardsDemo extends StatelessWidget {
  const _CardsDemo();

  @override
  Widget build(BuildContext context) {
    Widget body(String t) => Text(t, style: context.text.titleMedium);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TdCard(onTap: () {}, child: body('Fläche (drückbar)')),
        const SizedBox(height: TdSpace.md),
        TdCard(variant: TdCardVariant.elevated, child: body('Angehoben')),
        const SizedBox(height: TdSpace.md),
        TdCard(variant: TdCardVariant.outlined, child: body('Nur Kante')),
        const SizedBox(height: TdSpace.md),
        TdCard(
          variant: TdCardVariant.gradient,
          child: Stack(
            children: [
              body('Verlauf'),
              Positioned(
                right: 0,
                top: 0,
                child: TdCard(
                  variant: TdCardVariant.glass,
                  padding: const EdgeInsets.symmetric(
                    horizontal: TdSpace.md,
                    vertical: TdSpace.sm,
                  ),
                  child: const Text('Glas'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TilesDemo extends StatefulWidget {
  const _TilesDemo();

  @override
  State<_TilesDemo> createState() => _TilesDemoState();
}

class _TilesDemoState extends State<_TilesDemo> {
  final List<DemoTask> _tasks = DemoData.tasks().take(3).toList();
  final DemoTask _item = DemoData.shopping().first;

  @override
  Widget build(BuildContext context) {
    final list = DemoData.listById('haus');
    return Column(
      children: [
        TdAnimatedList<DemoTask>(
          items: _tasks,
          keyOf: (t) => t.id,
          shrinkWrap: true,
          primary: false,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, t, i) => TdTaskTile(
            title: t.title,
            subtitle: t.subtitle,
            done: t.done,
            accent: DemoData.listById(t.listId).color,
            assignee: t.assignee,
            tags: [
              TdTag(
                label: DemoData.listById(t.listId).name,
                color: DemoData.listById(t.listId).color,
              ),
              TdWeightTag(weight: t.weight),
            ],
            onChanged: (v) => setState(() => t.done = v),
            onDelete: () => setState(() => _tasks.remove(t)),
          ),
        ),
        TdTaskTile(
          dense: true,
          title: _item.title,
          done: _item.done,
          accent: list.color,
          leadingLabel: _item.quantity,
          onChanged: (v) => setState(() => _item.done = v),
        ),
        const SizedBox(height: TdSpace.sm),
        const TdTaskTile(
          title: 'Ohne Berechtigung (nicht abhakbar)',
          done: false,
        ),
      ],
    );
  }
}

class _AvatarsDemo extends StatelessWidget {
  const _AvatarsDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const TdAvatar(data: DemoData.me, size: 48),
        const SizedBox(width: TdSpace.md),
        const TdAvatar(data: DemoData.anna, size: 36),
        const SizedBox(width: TdSpace.md),
        const TdAvatar(data: TdAvatarData(name: 'Sam Oberhuber'), size: 28),
        const SizedBox(width: TdSpace.xl),
        TdAvatarStack(
          people: [
            ...DemoData.people,
            const TdAvatarData(name: 'Mia'),
            const TdAvatarData(name: 'Tom'),
            const TdAvatarData(name: 'Eva'),
          ],
          size: 32,
        ),
      ],
    );
  }
}

class _ProgressDemo extends StatefulWidget {
  const _ProgressDemo();

  @override
  State<_ProgressDemo> createState() => _ProgressDemoState();
}

class _ProgressDemoState extends State<_ProgressDemo> {
  double _v = 0.6;
  int _count = 14;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            TdRingProgress(
              value: _v,
              child: TdAnimatedCounter(
                value: _v * 100,
                format: (v) => '${v.round()}%',
                style: context.text.labelLarge,
              ),
            ),
            const SizedBox(width: TdSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TdAnimatedCounter(
                    value: _count,
                    style: context.text.displaySmall,
                  ),
                  const SizedBox(height: TdSpace.sm),
                  TdProgressBar(value: _v),
                ],
              ),
            ),
            const SizedBox(width: TdSpace.md),
            TdIconButton(
              icon: Icons.shuffle_rounded,
              onPressed: () => setState(() {
                _v = (_v + 0.3) % 1.0;
                _count += 7;
              }),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.lg),
        TdFairnessBar(
          shares: [
            for (final p in DemoData.people)
              TdFairnessShare(person: p, value: DemoData.weekPoints[p.id] ?? 0),
          ],
        ),
      ],
    );
  }
}

class _EmptyDemo extends StatelessWidget {
  const _EmptyDemo();

  @override
  Widget build(BuildContext context) {
    return TdCard(
      padding: EdgeInsets.zero,
      child: TdEmptyState(
        compact: true,
        icon: Icons.shopping_basket_outlined,
        title: 'Noch nichts auf der Liste',
        message:
            'Füge den ersten Artikel hinzu – alle in der Liste sehen ihn sofort.',
        action: TdButton.primary(
          label: 'Artikel hinzufügen',
          icon: Icons.add_rounded,
          onPressed: () {},
        ),
      ),
    );
  }
}

class _OverlaysDemo extends StatelessWidget {
  const _OverlaysDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: TdSpace.md,
      runSpacing: TdSpace.md,
      children: [
        TdButton.secondary(
          label: 'Sheet',
          icon: Icons.vertical_align_top_rounded,
          onPressed: () => showTdSheet<void>(
            context,
            title: 'Beispiel-Sheet',
            builder: (ctx) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const TdTextField(label: 'Name', hint: 'Neue Liste'),
                const SizedBox(height: TdSpace.xl),
                TdButton.primary(
                  label: 'Fertig',
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
        TdButton.secondary(
          label: 'Toast',
          icon: Icons.notifications_active_outlined,
          onPressed: () => TdToast.show(
            context,
            'Anna hat „Bad putzen“ erledigt',
            variant: TdToastVariant.success,
            actionLabel: 'Danke',
            onAction: () {},
          ),
        ),
        Builder(
          builder: (ctx) => TdButton.secondary(
            label: 'Konfetti',
            icon: Icons.celebration_outlined,
            onPressed: () => TdConfetti.burstFrom(ctx, count: 40),
          ),
        ),
      ],
    );
  }
}

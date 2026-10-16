/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../services/avatar_service.dart' show DeviceCapabilities;
import '../../services/speech_service.dart';
import '../../services/voice_item_parser.dart';
import 'quantity_stepper.dart';
import 'shopping_item_sheet.dart';

/// Übersetzte Einheit zu einer erkannten [VoiceUnit]; ohne Einheit „Stück“.
String voiceUnitLabel(AppLocalizations l10n, VoiceUnit? unit) => switch (unit) {
  null || VoiceUnit.piece => l10n.unit_piece,
  VoiceUnit.kg => l10n.unit_kg,
  VoiceUnit.g => l10n.unit_g,
  VoiceUnit.l => l10n.unit_l,
  VoiceUnit.ml => l10n.unit_ml,
  VoiceUnit.pack => l10n.unit_pack,
  VoiceUnit.can => l10n.unit_can,
  VoiceUnit.bottle => l10n.unit_bottle,
  VoiceUnit.bag => l10n.unit_bag,
  VoiceUnit.bunch => l10n.unit_bunch,
  VoiceUnit.head => l10n.unit_head,
  VoiceUnit.cup => l10n.unit_cup,
  VoiceUnit.jar => l10n.unit_jar,
};

ShoppingItemDraft draftFromVoice(AppLocalizations l10n, VoiceParsedItem item) =>
    ShoppingItemDraft(
      name: item.name,
      quantity: item.quantity,
      unit: voiceUnitLabel(l10n, item.unit),
    );

/// Öffnet die Spracheingabe. Liefert die bestätigten Einträge oder `null`.
///
/// [confirmLabel] bestimmt den Text des Hauptknopfs: `true` = „Artikel
/// hinzufügen“ (aus der Liste), `false` = „Einträge übernehmen“ (ins Sheet).
Future<List<ShoppingItemDraft>?> showVoiceInputSheet(
  BuildContext context, {
  required SpeechService speech,
  bool addDirectly = false,
  bool singleEntry = false,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showTdSheet<List<ShoppingItemDraft>>(
    context,
    title: l10n.voiceInput,
    builder: (ctx) => VoiceInputPanel(
      speech: speech,
      addDirectly: addDirectly,
      singleEntry: singleEntry,
      onDone: (drafts) => Navigator.of(ctx).pop(drafts),
    ),
  );
}

enum _VoiceState { idle, listening, done, denied, unavailable }

class VoiceInputPanel extends StatefulWidget {
  const VoiceInputPanel({
    super.key,
    required this.speech,
    required this.onDone,
    this.addDirectly = false,
    this.singleEntry = false,
    this.autoStart = true,
  });

  final SpeechService speech;
  final ValueChanged<List<ShoppingItemDraft>> onDone;
  final bool addDirectly;

  /// Nur ein Eintrag wird gebraucht (Mikrofon im Bearbeiten-Sheet).
  final bool singleEntry;
  final bool autoStart;

  @override
  State<VoiceInputPanel> createState() => _VoiceInputPanelState();
}

class _VoiceInputPanelState extends State<VoiceInputPanel>
    with SingleTickerProviderStateMixin {
  _VoiceState _state = _VoiceState.idle;
  String _text = '';
  double _level = 0;
  List<VoiceParsedItem> _items = const [];
  late VoiceItemParser _parser;
  bool _started = false;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    _parser = VoiceItemParser.forLanguage(locale.languageCode);
    if (!_started && widget.autoStart) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _start());
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    widget.speech.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (!mounted) return;
    final locale = Localizations.localeOf(context);
    setState(() {
      _state = _VoiceState.listening;
      _text = '';
      _items = const [];
      _level = 0;
    });
    if (!TdMotion.reduced(context)) _pulse.repeat();
    HapticFeedback.selectionClick();

    final status = await widget.speech.start(
      localeId: locale.toString(),
      onText: _onText,
      onLevel: (l) {
        if (mounted && _state == _VoiceState.listening) {
          setState(() => _level = l);
        }
      },
      onDone: _onDone,
    );
    if (!mounted) return;
    switch (status) {
      case SpeechStartStatus.listening:
        break;
      case SpeechStartStatus.permissionDenied:
        _pulse.stop();
        setState(() => _state = _VoiceState.denied);
      case SpeechStartStatus.unavailable:
        _pulse.stop();
        setState(() => _state = _VoiceState.unavailable);
    }
  }

  void _onText(String text, bool isFinal) {
    if (!mounted) return;
    setState(() {
      _text = text;
      _items = _parser.parse(text);
      if (isFinal) _finish();
    });
  }

  void _onDone() {
    if (!mounted || _state != _VoiceState.listening) return;
    setState(_finish);
  }

  void _finish() {
    _state = _VoiceState.done;
    _pulse.stop();
    _level = 0;
    if (_items.isNotEmpty) HapticFeedback.mediumImpact();
  }

  Future<void> _stop() async {
    await widget.speech.stop();
    if (mounted && _state == _VoiceState.listening) setState(_finish);
  }

  void _remove(int index) => setState(() {
    _items = [..._items]..removeAt(index);
  });

  void _setQuantity(int index, double q) => setState(() {
    final it = _items[index];
    _items = [..._items]
      ..[index] = VoiceParsedItem(name: it.name, quantity: q, unit: it.unit);
  });

  void _confirm() {
    final l10n = AppLocalizations.of(context)!;
    final drafts = _items.map((i) => draftFromVoice(l10n, i)).toList();
    widget.onDone(widget.singleEntry ? drafts.take(1).toList() : drafts);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = context.colors;
    final td = context.td;

    if (_state == _VoiceState.denied || _state == _VoiceState.unavailable) {
      final denied = _state == _VoiceState.denied;
      const device = DeviceCapabilities();
      return TdEmptyState(
        compact: true,
        icon: denied ? Icons.mic_off_rounded : Icons.record_voice_over_outlined,
        title: denied ? l10n.voiceMicDenied : l10n.voiceUnavailable,
        message: denied
            ? l10n.voiceMicDeniedMessage
            : l10n.voiceUnavailableMessage,
        action: denied && device.canOpenSettings
            ? TdButton.primary(
                label: l10n.avatarOpenSettings,
                icon: Icons.settings_outlined,
                onPressed: () => device.openAppSettings(),
              )
            : null,
      );
    }

    final listening = _state == _VoiceState.listening;
    final hint = switch (_state) {
      _VoiceState.listening => _text.isEmpty ? l10n.voiceListening : _text,
      _VoiceState.done => _items.isEmpty ? l10n.voiceNothingUnderstood : _text,
      _ => l10n.voiceTapToSpeak,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Mikrofon mit Wellen.
        Center(
          child: Semantics(
            button: true,
            label: listening ? l10n.voiceStop : l10n.voiceInput,
            child: GestureDetector(
              onTap: listening ? _stop : _start,
              child: SizedBox(
                width: 168,
                height: 168,
                child: AnimatedBuilder(
                  animation: _pulse,
                  builder: (context, child) => CustomPaint(
                    painter: _WavesPainter(
                      progress: _pulse.value,
                      level: listening ? _level : 0,
                      color: listening ? scheme.primary : td.muted,
                      active: listening,
                      reduced: TdMotion.reduced(context),
                    ),
                    child: child,
                  ),
                  child: Center(
                    child: AnimatedContainer(
                      duration: TdMotion.of(context, TdMotion.base),
                      curve: TdMotion.spring,
                      width: 72 + (listening ? _level * 10 : 0),
                      height: 72 + (listening ? _level * 10 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: listening ? td.primaryGradient : null,
                        color: listening
                            ? null
                            : scheme.surfaceContainerHighest,
                        boxShadow: listening
                            ? TdShadows.glow(scheme.primary)
                            : null,
                      ),
                      child: Icon(
                        listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                        size: 32,
                        color: listening
                            ? td.palette.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: TdSpace.sm),
        // Live-Text.
        AnimatedSwitcher(
          duration: TdMotion.of(context, TdMotion.fast),
          child: Text(
            hint,
            key: ValueKey('$_state|$hint'),
            textAlign: TextAlign.center,
            style: _text.isEmpty
                ? context.text.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  )
                : context.text.titleMedium,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Erkannte Einträge.
        TdReveal(
          visible: _items.isNotEmpty,
          child: Padding(
            padding: const EdgeInsets.only(top: TdSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < _items.length; i++)
                  TdFadeSlideIn(
                    key: ValueKey('${_items[i].name}-$i'),
                    index: i,
                    offset: const Offset(-0.08, 0),
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: TdSpace.sm),
                      child: _EntryCard(
                        item: _items[i],
                        unitLabel: voiceUnitLabel(l10n, _items[i].unit),
                        editable: _state == _VoiceState.done,
                        onQuantity: (q) => _setQuantity(i, q),
                        onRemove: _items.length > 1 ? () => _remove(i) : null,
                        removeLabel: l10n.voiceRemoveEntry,
                        decreaseLabel: l10n.decreaseQuantity,
                        increaseLabel: l10n.increaseQuantity,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: TdSpace.xl),
        if (_state == _VoiceState.done && _items.isNotEmpty) ...[
          TdButton.primary(
            label: widget.addDirectly
                ? l10n.voiceAddAll(_items.length)
                : l10n.voiceUseResult(widget.singleEntry ? 1 : _items.length),
            icon: Icons.check_rounded,
            expanded: true,
            size: TdButtonSize.large,
            onPressed: _confirm,
          ),
          const SizedBox(height: TdSpace.sm),
          TdButton.ghost(
            label: l10n.voiceRetry,
            icon: Icons.mic_rounded,
            expanded: true,
            onPressed: _start,
          ),
        ] else if (_state == _VoiceState.done) ...[
          TdButton.primary(
            label: l10n.voiceRetry,
            icon: Icons.mic_rounded,
            expanded: true,
            size: TdButtonSize.large,
            onPressed: _start,
          ),
        ] else if (listening) ...[
          TdButton.secondary(
            label: l10n.voiceStop,
            icon: Icons.stop_rounded,
            expanded: true,
            onPressed: _stop,
          ),
        ],
      ],
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.item,
    required this.unitLabel,
    required this.editable,
    required this.onQuantity,
    required this.onRemove,
    required this.removeLabel,
    required this.decreaseLabel,
    required this.increaseLabel,
  });

  final VoiceParsedItem item;
  final String unitLabel;
  final bool editable;
  final ValueChanged<double> onQuantity;
  final VoidCallback? onRemove;
  final String removeLabel;
  final String decreaseLabel;
  final String increaseLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return TdCard(
      padding: const EdgeInsets.fromLTRB(
        TdSpace.lg,
        TdSpace.sm,
        TdSpace.sm,
        TdSpace.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              item.name,
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: TdSpace.sm),
          if (editable)
            QuantityStepper(
              value: item.quantity,
              unit: unitLabel,
              compact: true,
              min: 0.5,
              step: item.quantity < 1 ? 0.5 : 1,
              onChanged: onQuantity,
              decreaseLabel: decreaseLabel,
              increaseLabel: increaseLabel,
            )
          else
            TdChip(
              label: '${QuantityStepper.format(item.quantity)} $unitLabel',
              dense: true,
              selected: true,
            ),
          if (onRemove != null && editable) ...[
            const SizedBox(width: TdSpace.xs),
            TdIconButton(
              icon: Icons.close_rounded,
              tooltip: removeLabel,
              size: 36,
              color: scheme.onSurfaceVariant,
              onPressed: onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

/// Konzentrische Wellen um das Mikrofon. Beim Zuhören laufen sie nach außen
/// und werden mit dem Pegel kräftiger; unter „Bewegung reduzieren“ stehen sie
/// still und zeigen nur den Pegel.
class _WavesPainter extends CustomPainter {
  _WavesPainter({
    required this.progress,
    required this.level,
    required this.color,
    required this.active,
    required this.reduced,
  });

  final double progress;
  final double level;
  final Color color;
  final bool active;
  final bool reduced;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = 40.0;
    final maxR = size.shortestSide / 2;
    if (!active) {
      canvas.drawCircle(
        center,
        base + 10,
        Paint()
          ..color = color.withValues(alpha: 0.18)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      return;
    }
    const rings = 3;
    for (var i = 0; i < rings; i++) {
      final t = reduced
          ? (i + 1) / (rings + 1)
          : ((progress + i / rings) % 1.0);
      final r = base + (maxR - base) * t * (0.55 + 0.45 * level);
      final alpha = (1 - t) * (0.12 + 0.5 * level);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = color.withValues(alpha: alpha.clamp(0.0, 0.7))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 2 * level,
      );
    }
    // Weicher Pegel-Schein hinter dem Knopf.
    canvas.drawCircle(
      center,
      base + 6 + 18 * level,
      Paint()
        ..color = color.withValues(alpha: 0.10 + 0.25 * level)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 10 + 10 * level),
    );
    // Kleine Pegel-Punkte, damit auch leise Eingaben sichtbar reagieren.
    final dots = Paint()..color = color.withValues(alpha: 0.35 + 0.4 * level);
    for (var i = 0; i < 12; i++) {
      final a = i / 12 * 2 * math.pi;
      final r =
          base +
          14 +
          6 * level * (1 + math.sin(a * 3 + progress * 2 * math.pi));
      canvas.drawCircle(
        center + Offset(math.cos(a), math.sin(a)) * r,
        1.6,
        dots,
      );
    }
  }

  @override
  bool shouldRepaint(_WavesPainter old) =>
      old.progress != progress ||
      old.level != level ||
      old.color != color ||
      old.active != active ||
      old.reduced != reduced;
}

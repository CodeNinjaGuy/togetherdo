/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/td_theme.dart';
import '../tokens/td_tokens.dart';

/// Konfetti-Explosion ohne Fremdpaket: ein `CustomPainter` zeichnet
/// kleine Rechtecke, Kreise und Striche, die nach oben platzen, fallen,
/// sich drehen und verblassen. Läuft im `Overlay`, stört also kein Layout.
abstract final class TdConfetti {
  /// Platzt an `globalPosition` (Bildschirmkoordinaten). Mit „Bewegung
  /// reduzieren“ passiert nichts außer einer kurzen Haptik.
  static void burst(
    BuildContext context, {
    required Offset globalPosition,
    int count = 28,
    List<Color>? colors,
    bool haptic = true,
  }) {
    if (haptic) HapticFeedback.mediumImpact();
    if (TdMotion.reduced(context)) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final palette = colors ?? context.td.confettiColors;
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ConfettiBurst(
        origin: globalPosition,
        colors: palette,
        count: count,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  /// Bequem: platzt in der Mitte des Widgets hinter `context`.
  static void burstFrom(BuildContext context, {int count = 28}) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    burst(context, globalPosition: center, count: count);
  }
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({
    required this.origin,
    required this.colors,
    required this.count,
    required this.onDone,
  });

  final Offset origin;
  final List<Color> colors;
  final int count;
  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<ConfettiParticle> _particles;

  @override
  void initState() {
    super.initState();
    final rnd = math.Random();
    _particles = List.generate(
      widget.count,
      (i) => ConfettiParticle.random(rnd, widget.colors),
    );
    _controller = AnimationController(vsync: this, duration: TdMotion.celebrate)
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onDone();
      })
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: RepaintBoundary(
          child: CustomPaint(
            painter: ConfettiPainter(
              progress: _controller,
              origin: widget.origin,
              particles: _particles,
            ),
          ),
        ),
      ),
    );
  }
}

enum ConfettiShape { rect, circle, strip }

/// Ein Partikel mit Startgeschwindigkeit, Drehung und Form.
class ConfettiParticle {
  ConfettiParticle({
    required this.velocity,
    required this.color,
    required this.size,
    required this.spin,
    required this.shape,
    required this.drift,
  });

  factory ConfettiParticle.random(math.Random rnd, List<Color> colors) {
    // Nach oben gerichteter Kegel, etwas Streuung zu den Seiten.
    final angle = -math.pi / 2 + (rnd.nextDouble() - 0.5) * math.pi * 0.9;
    final speed = 260 + rnd.nextDouble() * 260;
    return ConfettiParticle(
      velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
      color: colors[rnd.nextInt(colors.length)],
      size: 5 + rnd.nextDouble() * 6,
      spin: (rnd.nextDouble() - 0.5) * 14,
      shape: ConfettiShape.values[rnd.nextInt(ConfettiShape.values.length)],
      drift: (rnd.nextDouble() - 0.5) * 60,
    );
  }

  final Offset velocity;
  final Color color;
  final double size;
  final double spin;
  final ConfettiShape shape;
  final double drift;

  static const double gravity = 900;

  Offset positionAt(double t) => Offset(
    velocity.dx * t + drift * t * t,
    velocity.dy * t + 0.5 * gravity * t * t,
  );
}

class ConfettiPainter extends CustomPainter {
  ConfettiPainter({
    required this.progress,
    required this.origin,
    required this.particles,
  }) : super(repaint: progress);

  final Animation<double> progress;
  final Offset origin;
  final List<ConfettiParticle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final p = progress.value;
    // Zeit in Sekunden über die Gesamtdauer; Ausblenden im letzten Drittel.
    final t = p * (TdMotion.celebrate.inMilliseconds / 1000);
    final alpha = p < 0.65 ? 1.0 : (1 - (p - 0.65) / 0.35).clamp(0.0, 1.0);
    final paint = Paint();

    for (final particle in particles) {
      final pos = origin + particle.positionAt(t);
      paint.color = particle.color.withValues(alpha: alpha);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(particle.spin * t);
      final s = particle.size;
      switch (particle.shape) {
        case ConfettiShape.rect:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s, height: s * 0.7),
              const Radius.circular(1.5),
            ),
            paint,
          );
        case ConfettiShape.circle:
          canvas.drawCircle(Offset.zero, s / 2, paint);
        case ConfettiShape.strip:
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s * 0.35),
              const Radius.circular(1),
            ),
            paint,
          );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(ConfettiPainter old) =>
      old.progress != progress || old.origin != origin;
}

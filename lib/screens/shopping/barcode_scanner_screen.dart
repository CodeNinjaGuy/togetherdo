/*
 * Copyright (c) 2026 Martin Bundschuh, SeeBubble Media FlexCo. All rights reserved.
 * Written by Martin Bundschuh.
 */

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:togetherdo/l10n/app_localizations.dart';

import '../../design/td_design.dart';
import '../../models/product_info.dart';
import '../../repositories/product_repository.dart';
import '../../services/avatar_service.dart' show DeviceCapabilities;
import '../../services/scanner_session.dart';
import '../../widgets/shopping/product_thumbnail.dart';
import '../../widgets/shopping/quantity_stepper.dart';

/// Ob der Strichcode-Scanner auf dieser Plattform angeboten wird.
bool get barcodeScannerSupported =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Vollbild-Scanner für Strichcodes (EAN/UPC).
///
/// - Normalmodus: mehrere Artikel nacheinander scannen, jeder Treffer
///   zeigt eine Karte von unten; „Hinzufügen“ legt ihn in die Liste und
///   scannt weiter. Zähler oben. `Navigator.pop` liefert die Anzahl.
/// - [pickMode]: ein einzelnes Produkt auswählen (z. B. „Neu scannen“ im
///   Bearbeiten-Sheet). `Navigator.pop` liefert das [ProductInfo].
/// - [demo]: kein Kamerazugriff, stattdessen Platzhalterbild und ein
///   Knopf, der einen Treffer simuliert (nur Debug, Simulator hat keine
///   Kamera).
class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({
    super.key,
    required this.session,
    this.pickMode = false,
    this.demo = false,
    this.demoCodes = const ['3017620422003', '8076800195057', '0000000000000'],
  });

  final ScannerSession session;
  final bool pickMode;
  final bool demo;

  /// Codes, die der Demo-Knopf nacheinander „scannt“.
  final List<String> demoCodes;

  /// Wartezeit, bis derselbe Code erneut zählt.
  static const Duration repeatCooldown = Duration(seconds: 2);

  static Future<T?> open<T>(
    BuildContext context, {
    required ScannerSession session,
    bool pickMode = false,
    bool demo = false,
  }) {
    return Navigator.of(context).push<T>(
      TdPageRoute<T>(
        builder: (_) => BarcodeScannerScreen(
          session: session,
          pickMode: pickMode,
          demo: demo,
        ),
      ),
    );
  }

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with TickerProviderStateMixin {
  MobileScannerController? _controller;
  late final AnimationController _scanLine = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  );
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: TdMotion.celebrate,
  );

  bool _busy = false;
  bool _lookingUp = false;
  int _count = 0;
  int _demoIndex = 0;
  String? _lastCode;
  DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    if (!widget.demo) {
      _controller = MobileScannerController(
        formats: const [
          BarcodeFormat.ean13,
          BarcodeFormat.ean8,
          BarcodeFormat.upcA,
          BarcodeFormat.upcE,
        ],
        detectionSpeed: DetectionSpeed.normal,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (TdMotion.reduced(context)) {
      _scanLine.stop();
      _scanLine.value = 0.5;
    } else if (!_scanLine.isAnimating) {
      _scanLine.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _scanLine.dispose();
    _flash.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------ Treffer

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final code = barcode.rawValue;
      if (code != null && code.isNotEmpty) {
        _handleCode(code);
        return;
      }
    }
  }

  void _demoHit() {
    if (widget.demoCodes.isEmpty) return;
    final code = widget.demoCodes[_demoIndex % widget.demoCodes.length];
    _demoIndex++;
    _lastCode = null;
    _handleCode(code);
  }

  Future<void> _handleCode(String code) async {
    if (_busy || !mounted) return;
    if (!ProductInfo.isValidEan(code)) return;
    final now = DateTime.now();
    if (code == _lastCode &&
        now.difference(_lastAt) < BarcodeScannerScreen.repeatCooldown) {
      return;
    }
    _lastCode = code;
    _lastAt = now;

    setState(() {
      _busy = true;
      _lookingUp = true;
    });
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    if (!TdMotion.reduced(context)) _flash.forward(from: 0);

    ProductLookupResult result;
    try {
      result = await widget.session.lookup(code);
    } catch (e) {
      debugPrint('Produktsuche fehlgeschlagen: $e');
      result = const ProductLookupResult.unknown();
    }
    if (!mounted) return;
    setState(() => _lookingUp = false);

    switch (result.status) {
      case ProductLookupStatus.found:
        await _showResult(result.product!);
      case ProductLookupStatus.unknown:
        await _showNaming(code, offline: false);
      case ProductLookupStatus.offline:
        await _showOffline(code);
    }
    if (!mounted) return;
    _lastAt = DateTime.now();
    setState(() => _busy = false);
  }

  Future<void> _showResult(ProductInfo product) async {
    final l10n = AppLocalizations.of(context)!;
    final quantity = await showTdSheet<double>(
      context,
      builder: (ctx) =>
          _ResultCard(product: product, pickMode: widget.pickMode, l10n: l10n),
    );
    if (quantity == null || !mounted) return;
    if (widget.pickMode) {
      Navigator.of(context).pop(product);
      return;
    }
    await _add(product, quantity);
  }

  Future<void> _showNaming(String code, {required bool offline}) async {
    final l10n = AppLocalizations.of(context)!;
    final draft = await showTdSheet<_NamedDraft>(
      context,
      title: l10n.scanUnknownTitle,
      builder: (ctx) =>
          _NamingCard(code: code, pickMode: widget.pickMode, l10n: l10n),
    );
    if (draft == null || !mounted) return;
    ProductInfo product;
    try {
      product = await widget.session.rememberProduct(
        ean: code,
        name: draft.name,
        brand: draft.brand,
        packageSize: draft.packageSize,
      );
    } catch (e) {
      debugPrint('Produkt konnte nicht gemerkt werden: $e');
      product = ProductInfo(
        ean: code,
        name: draft.name,
        brand: draft.brand,
        quantity: draft.packageSize,
        source: ProductSource.nutzer,
        updatedAt: DateTime.now(),
      );
    }
    if (!mounted) return;
    if (widget.pickMode) {
      Navigator.of(context).pop(product);
      return;
    }
    await _add(product, draft.quantity);
  }

  Future<void> _showOffline(String code) async {
    final l10n = AppLocalizations.of(context)!;
    final action = await showTdSheet<_OfflineAction>(
      context,
      title: l10n.scanOfflineTitle,
      builder: (ctx) => _OfflineCard(code: code, l10n: l10n),
    );
    if (action == null || !mounted) return;
    switch (action) {
      case _OfflineAction.retry:
        _lastCode = null;
        setState(() => _busy = false);
        await _handleCode(code);
      case _OfflineAction.name:
        await _showNaming(code, offline: true);
    }
  }

  Future<void> _add(ProductInfo product, double quantity) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final outcome = await widget.session.addToList(product, quantity);
      if (!mounted) return;
      setState(() => _count++);
      HapticFeedback.lightImpact();
      TdToast.show(
        context,
        outcome == ScanAddOutcome.incremented
            ? l10n.scanIncremented(product.name)
            : l10n.scanAdded(product.name),
        variant: TdToastVariant.success,
        icon: Icons.shopping_basket_rounded,
        duration: const Duration(milliseconds: 1800),
      );
    } catch (e) {
      if (!mounted) return;
      TdToast.show(
        context,
        '${l10n.loadError}: $e',
        variant: TdToastVariant.error,
      );
    }
  }

  void _close() => Navigator.of(context).pop(widget.pickMode ? null : _count);

  // -------------------------------------------------------------- Aufbau

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final size = Size(constraints.maxWidth, constraints.maxHeight);
          final window = _scanWindow(size);
          return Stack(
            fit: StackFit.expand,
            children: [
              if (controller != null)
                MobileScanner(
                  controller: controller,
                  onDetect: _onDetect,
                  scanWindow: window,
                  placeholderBuilder: (_) => const _FakeCamera(),
                  errorBuilder: (ctx, error) => _CameraError(
                    error: error,
                    l10n: l10n,
                    onClose: _close,
                    onDemo: kDebugMode ? _demoHit : null,
                  ),
                )
              else
                const _FakeCamera(),
              // Sucher: abgedunkelter Rand, Ecken, Scan-Linie, Treffer-Glühen.
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_scanLine, _flash]),
                  builder: (_, _) => CustomPaint(
                    painter: _ViewfinderPainter(
                      window: window,
                      lineProgress: _scanLine.value,
                      flash:
                          Curves.easeOut.transform(
                            1 - (_flash.value - 0.15).clamp(0, 1) / 0.85,
                          ) *
                          (_flash.value > 0 ? 1 : 0),
                      accent: context.td.success,
                      showLine: !_lookingUp,
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(TdSpace.lg),
                  child: Column(
                    children: [
                      _TopBar(
                        l10n: l10n,
                        controller: controller,
                        count: widget.pickMode ? null : _count,
                        onClose: _close,
                      ),
                      const Spacer(),
                      _BottomArea(
                        l10n: l10n,
                        lookingUp: _lookingUp,
                        count: _count,
                        pickMode: widget.pickMode,
                        showDemo:
                            kDebugMode && (widget.demo || controller == null),
                        onDemo: _demoHit,
                        onDone: _close,
                        attribution: l10n.scanDataAttribution,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Sucher-Rechteck: mittig, quer (Strichcodes sind breit), mit Rand.
  static Rect _scanWindow(Size size) {
    final width = (size.width - 2 * TdSpace.xxl).clamp(200.0, 420.0);
    final height = (width * 0.62).clamp(140.0, 260.0);
    final center = Offset(size.width / 2, size.height * 0.44);
    return Rect.fromCenter(center: center, width: width, height: height);
  }
}

// ------------------------------------------------------------------ Kopf

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.l10n,
    required this.controller,
    required this.count,
    required this.onClose,
  });

  final AppLocalizations l10n;
  final MobileScannerController? controller;
  final int? count;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final controller = this.controller;
    return Row(
      children: [
        _GlassButton(
          icon: Icons.close_rounded,
          tooltip: l10n.close,
          onTap: onClose,
        ),
        Expanded(
          child: Center(
            child: count == null
                ? _GlassPill(
                    child: Text(
                      l10n.scanBarcode,
                      style: context.text.labelLarge?.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  )
                : AnimatedSwitcher(
                    duration: TdMotion.of(context, TdMotion.base),
                    switchInCurve: TdMotion.spring,
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: ScaleTransition(
                        scale: Tween(begin: 0.85, end: 1.0).animate(anim),
                        child: child,
                      ),
                    ),
                    child: _GlassPill(
                      key: ValueKey(count),
                      accent: count! > 0 ? context.td.success : null,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            count! > 0
                                ? Icons.shopping_basket_rounded
                                : Icons.qr_code_scanner_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                          const SizedBox(width: TdSpace.sm),
                          Text(
                            l10n.scanCount(count!),
                            style: context.text.labelLarge?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
        ),
        if (controller != null)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: controller,
            builder: (_, state, _) {
              final on = state.torchState == TorchState.on;
              final available =
                  state.torchState != TorchState.unavailable && state.isRunning;
              return _GlassButton(
                icon: on
                    ? Icons.flashlight_on_rounded
                    : Icons.flashlight_off_rounded,
                tooltip: on ? l10n.torchOff : l10n.torchOn,
                active: on,
                onTap: available ? controller.toggleTorch : null,
              );
            },
          )
        else
          const SizedBox(width: 44),
      ],
    );
  }
}

// ------------------------------------------------------------------ Fuß

class _BottomArea extends StatelessWidget {
  const _BottomArea({
    required this.l10n,
    required this.lookingUp,
    required this.count,
    required this.pickMode,
    required this.showDemo,
    required this.onDemo,
    required this.onDone,
    required this.attribution,
  });

  final AppLocalizations l10n;
  final bool lookingUp;
  final int count;
  final bool pickMode;
  final bool showDemo;
  final VoidCallback onDemo;
  final VoidCallback onDone;
  final String attribution;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: TdMotion.of(context, TdMotion.base),
          child: _GlassPill(
            key: ValueKey(lookingUp),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (lookingUp) ...[
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: TdSpace.sm),
                ],
                Text(
                  lookingUp ? l10n.scanLookingUp : l10n.scanHint,
                  style: context.text.bodyMedium?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: TdSpace.sm),
        Text(
          attribution,
          style: context.text.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        if (showDemo) ...[
          const SizedBox(height: TdSpace.lg),
          TdButton.secondary(
            label: l10n.scanDemoHit,
            icon: Icons.science_outlined,
            size: TdButtonSize.small,
            onPressed: onDemo,
          ),
        ],
        TdReveal(
          visible: !pickMode && count > 0,
          child: Padding(
            padding: const EdgeInsets.only(top: TdSpace.lg),
            child: TdButton.primary(
              label: l10n.scanDone,
              icon: Icons.check_rounded,
              expanded: true,
              onPressed: onDone,
            ),
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------- Glas-Elemente

class _GlassButton extends StatelessWidget {
  const _GlassButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool active;

  @override
  Widget build(BuildContext context) {
    Widget button = TdPressable(
      onTap: onTap,
      enabled: onTap != null,
      scale: 0.9,
      haptic: true,
      semanticLabel: tooltip,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: AnimatedContainer(
            duration: TdMotion.of(context, TdMotion.base),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active
                  ? Colors.white.withValues(alpha: 0.92)
                  : Colors.white.withValues(alpha: onTap == null ? 0.08 : 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            alignment: Alignment.center,
            child: Icon(
              icon,
              size: 22,
              color: active
                  ? Colors.black87
                  : Colors.white.withValues(alpha: onTap == null ? 0.4 : 1),
            ),
          ),
        ),
      ),
    );
    if (tooltip != null) button = Tooltip(message: tooltip!, child: button);
    return button;
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({super.key, required this.child, this.accent});

  final Widget child;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(TdRadius.pill),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: TdSpace.lg,
            vertical: TdSpace.sm + 2,
          ),
          decoration: BoxDecoration(
            color: (accent ?? Colors.white).withValues(
              alpha: accent == null ? 0.16 : 0.45,
            ),
            borderRadius: BorderRadius.circular(TdRadius.pill),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Sucher-Maler

class _ViewfinderPainter extends CustomPainter {
  _ViewfinderPainter({
    required this.window,
    required this.lineProgress,
    required this.flash,
    required this.accent,
    required this.showLine,
  });

  final Rect window;
  final double lineProgress;

  /// 0 = Ruhe, 1 = eben getroffen (Rahmen leuchtet in [accent]).
  final double flash;
  final Color accent;
  final bool showLine;

  static const double radius = TdRadius.lg;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      window,
      const Radius.circular(radius),
    );
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()..addRRect(rrect);
    canvas.drawPath(
      Path.combine(PathOperation.difference, full, hole),
      Paint()..color = Colors.black.withValues(alpha: 0.55),
    );

    final frameColor = Color.lerp(Colors.white, accent, flash)!;

    // Treffer-Glühen um den Rahmen.
    if (flash > 0) {
      canvas.drawRRect(
        rrect.inflate(2),
        Paint()
          ..color = accent.withValues(alpha: 0.55 * flash)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    // Feine Kante plus vier kräftige Ecken.
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = frameColor.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    final corner = Paint()
      ..color = frameColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const len = 26.0;
    final r = radius;
    final l = window.left, t = window.top, rt = window.right, b = window.bottom;
    void arc(Offset center, double start) => canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      start,
      1.5708,
      false,
      corner,
    );
    // oben links
    canvas.drawLine(Offset(l, t + r), Offset(l, t + r + len), corner);
    canvas.drawLine(Offset(l + r, t), Offset(l + r + len, t), corner);
    arc(Offset(l + r, t + r), 3.1416);
    // oben rechts
    canvas.drawLine(Offset(rt, t + r), Offset(rt, t + r + len), corner);
    canvas.drawLine(Offset(rt - r, t), Offset(rt - r - len, t), corner);
    arc(Offset(rt - r, t + r), -1.5708);
    // unten links
    canvas.drawLine(Offset(l, b - r), Offset(l, b - r - len), corner);
    canvas.drawLine(Offset(l + r, b), Offset(l + r + len, b), corner);
    arc(Offset(l + r, b - r), 1.5708);
    // unten rechts
    canvas.drawLine(Offset(rt, b - r), Offset(rt, b - r - len), corner);
    canvas.drawLine(Offset(rt - r, b), Offset(rt - r - len, b), corner);
    arc(Offset(rt - r, b - r), 0);

    // Scan-Linie mit Leuchten.
    if (showLine) {
      final y = window.top + 14 + (window.height - 28) * lineProgress;
      final lineRect = Rect.fromLTRB(
        window.left + 18,
        y - 1.5,
        window.right - 18,
        y + 1.5,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(lineRect.inflate(3), const Radius.circular(4)),
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(lineRect, const Radius.circular(2)),
        Paint()
          ..shader = LinearGradient(
            colors: [
              accent.withValues(alpha: 0),
              Color.lerp(accent, Colors.white, 0.4)!,
              accent.withValues(alpha: 0),
            ],
          ).createShader(lineRect),
      );
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) =>
      old.window != window ||
      old.lineProgress != lineProgress ||
      old.flash != flash ||
      old.showLine != showLine ||
      old.accent != accent;
}

// ------------------------------------------------------ Platzhalter-Kamera

/// Ersatz für das Kamerabild, solange die Kamera startet oder in der Demo:
/// dunkler Verlauf, weiche Lichtflecken und ein angedeuteter Strichcode.
class _FakeCamera extends StatelessWidget {
  const _FakeCamera();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _FakeCameraPainter(), size: Size.infinite);
  }
}

class _FakeCameraPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF2B2E3A), Color(0xFF14151B), Color(0xFF1E2028)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ).createShader(Offset.zero & size),
    );
    final glow = Paint()
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 60);
    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.2),
      size.width * 0.3,
      glow..color = const Color(0xFF5B4BD6).withValues(alpha: 0.25),
    );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.75),
      size.width * 0.35,
      glow..color = const Color(0xFFFF7A59).withValues(alpha: 0.18),
    );

    // Produktpackung mit Strichcode im Sucher.
    final window = _BarcodeScannerScreenState._scanWindow(size);
    final pack = Rect.fromCenter(
      center: window.center.translate(0, 6),
      width: window.width * 0.72,
      height: window.height * 0.74,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(pack, const Radius.circular(10)),
      Paint()..color = const Color(0xFFF4EFE6),
    );
    final bars = Paint()..color = const Color(0xFF1C1B22);
    final barArea = Rect.fromLTWH(
      pack.left + pack.width * 0.14,
      pack.top + pack.height * 0.22,
      pack.width * 0.72,
      pack.height * 0.46,
    );
    const pattern = [
      3,
      1,
      2,
      1,
      1,
      3,
      1,
      2,
      2,
      1,
      1,
      1,
      3,
      2,
      1,
      1,
      2,
      3,
      1,
      1,
      2,
      1,
      3,
      1,
      1,
      2,
      1,
      1,
      3,
      2,
    ];
    final total = pattern.fold<int>(0, (a, b) => a + b) * 2;
    final unit = barArea.width / total;
    var x = barArea.left;
    for (var i = 0; i < pattern.length; i++) {
      final w = pattern[i] * unit;
      canvas.drawRect(Rect.fromLTWH(x, barArea.top, w, barArea.height), bars);
      x += w * 2;
    }
    // Ziffernreihe unter den Balken.
    final digits = Paint()
      ..color = const Color(0xFF1C1B22).withValues(alpha: 0.7);
    for (var i = 0; i < 12; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            barArea.left + i * (barArea.width / 12) + 2,
            barArea.bottom + 6,
            barArea.width / 12 - 5,
            7,
          ),
          const Radius.circular(1.5),
        ),
        digits,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ------------------------------------------------------------ Kamerafehler

class _CameraError extends StatelessWidget {
  const _CameraError({
    required this.error,
    required this.l10n,
    required this.onClose,
    this.onDemo,
  });

  final MobileScannerException error;
  final AppLocalizations l10n;
  final VoidCallback onClose;
  final VoidCallback? onDemo;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    const device = DeviceCapabilities();
    return Container(
      color: context.colors.surface,
      alignment: Alignment.center,
      child: SingleChildScrollView(
        child: TdEmptyState(
          icon: denied
              ? Icons.no_photography_outlined
              : Icons.videocam_off_outlined,
          title: denied ? l10n.scanCameraDenied : l10n.scanCameraUnavailable,
          message: denied
              ? l10n.scanCameraDeniedMessage
              : l10n.scanCameraUnavailableMessage,
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (denied && device.canOpenSettings)
                TdButton.primary(
                  label: l10n.avatarOpenSettings,
                  icon: Icons.settings_outlined,
                  onPressed: () => device.openAppSettings(),
                ),
              if (onDemo != null) ...[
                const SizedBox(height: TdSpace.sm),
                TdButton.tonal(
                  label: l10n.scanDemoHit,
                  icon: Icons.science_outlined,
                  onPressed: onDemo,
                ),
              ],
              const SizedBox(height: TdSpace.sm),
              TdButton.ghost(label: l10n.close, onPressed: onClose),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------- Ergebnis-Karte

class _ResultCard extends StatefulWidget {
  const _ResultCard({
    required this.product,
    required this.pickMode,
    required this.l10n,
  });

  final ProductInfo product;
  final bool pickMode;
  final AppLocalizations l10n;

  @override
  State<_ResultCard> createState() => _ResultCardState();
}

class _ResultCardState extends State<_ResultCard> {
  double _quantity = 1;

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final p = widget.product;
    final scheme = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TdFadeSlideIn(
          child: Row(
            children: [
              Hero(
                tag: 'produkt-${p.ean}',
                child: ProductThumbnail(
                  imageUrl: p.imageUrl,
                  size: 84,
                  radius: TdRadius.md,
                ),
              ),
              const SizedBox(width: TdSpace.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      style: context.text.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (p.detailLine.isNotEmpty) ...[
                      const SizedBox(height: TdSpace.xs),
                      Text(
                        p.detailLine,
                        style: context.text.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: TdSpace.sm),
                    TdChip(
                      label: l10n.scanCodeLabel(p.ean),
                      icon: Icons.qr_code_2_rounded,
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!widget.pickMode) ...[
          const SizedBox(height: TdSpace.xl),
          TdFadeSlideIn(
            index: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.quantity, style: context.text.titleSmall),
                QuantityStepper(
                  value: _quantity,
                  min: 1,
                  onChanged: (v) => setState(() => _quantity = v),
                  decreaseLabel: l10n.decreaseQuantity,
                  increaseLabel: l10n.increaseQuantity,
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: TdSpace.xl),
        TdFadeSlideIn(
          index: 2,
          child: TdButton.primary(
            label: widget.pickMode ? l10n.useProduct : l10n.add,
            icon: widget.pickMode
                ? Icons.check_rounded
                : Icons.add_shopping_cart_rounded,
            expanded: true,
            size: TdButtonSize.large,
            onPressed: () => Navigator.of(context).pop(_quantity),
          ),
        ),
        const SizedBox(height: TdSpace.sm),
        TdButton.ghost(
          label: l10n.scanContinue,
          icon: Icons.qr_code_scanner_rounded,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
        if (p.source.isOpenFacts) ...[
          const SizedBox(height: TdSpace.sm),
          Text(
            l10n.scanDataAttribution,
            textAlign: TextAlign.center,
            style: context.text.labelSmall?.copyWith(color: context.td.muted),
          ),
        ],
      ],
    );
  }
}

// --------------------------------------------------------- Benennen-Karte

class _NamedDraft {
  const _NamedDraft({
    required this.name,
    required this.quantity,
    this.brand,
    this.packageSize,
  });

  final String name;
  final double quantity;
  final String? brand;
  final String? packageSize;
}

class _NamingCard extends StatefulWidget {
  const _NamingCard({
    required this.code,
    required this.pickMode,
    required this.l10n,
  });

  final String code;
  final bool pickMode;
  final AppLocalizations l10n;

  @override
  State<_NamingCard> createState() => _NamingCardState();
}

class _NamingCardState extends State<_NamingCard> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _size = TextEditingController();
  double _quantity = 1;
  bool _showError = false;

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _size.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _showError = true);
      return;
    }
    Navigator.of(context).pop(
      _NamedDraft(
        name: name,
        quantity: _quantity,
        brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
        packageSize: _size.text.trim().isEmpty ? null : _size.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.scanUnknownMessage,
          style: context.text.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: TdSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TdChip(
            label: l10n.scanCodeLabel(widget.code),
            icon: Icons.qr_code_2_rounded,
            dense: true,
          ),
        ),
        const SizedBox(height: TdSpace.lg),
        TdTextField(
          controller: _name,
          label: l10n.itemLabel,
          hint: l10n.exampleItem,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) {
            if (_showError) setState(() => _showError = false);
          },
        ),
        TdReveal(
          visible: _showError,
          child: Padding(
            padding: const EdgeInsets.only(top: TdSpace.sm, left: TdSpace.xs),
            child: Text(
              l10n.itemNameRequired,
              style: context.text.bodySmall?.copyWith(color: context.td.danger),
            ),
          ),
        ),
        const SizedBox(height: TdSpace.lg),
        Row(
          children: [
            Expanded(
              child: TdTextField(
                controller: _brand,
                label: l10n.scanBrandOptional,
                textCapitalization: TextCapitalization.words,
              ),
            ),
            const SizedBox(width: TdSpace.md),
            Expanded(
              child: TdTextField(
                controller: _size,
                label: l10n.scanPackageSizeOptional,
                hint: l10n.scanPackageSizeExample,
              ),
            ),
          ],
        ),
        if (!widget.pickMode) ...[
          const SizedBox(height: TdSpace.xl),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.quantity, style: context.text.titleSmall),
              QuantityStepper(
                value: _quantity,
                min: 1,
                onChanged: (v) => setState(() => _quantity = v),
                decreaseLabel: l10n.decreaseQuantity,
                increaseLabel: l10n.increaseQuantity,
              ),
            ],
          ),
        ],
        const SizedBox(height: TdSpace.xl),
        TdButton.primary(
          label: widget.pickMode ? l10n.useProduct : l10n.scanAddAndRemember,
          icon: Icons.bookmark_add_outlined,
          expanded: true,
          size: TdButtonSize.large,
          onPressed: _submit,
        ),
        const SizedBox(height: TdSpace.sm),
        TdButton.ghost(
          label: l10n.scanContinue,
          icon: Icons.qr_code_scanner_rounded,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------- Offline-Karte

enum _OfflineAction { retry, name }

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.code, required this.l10n});

  final String code;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: context.td.warning.withValues(alpha: 0.15),
                borderRadius: TdRadius.control,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.wifi_off_rounded, color: context.td.warning),
            ),
            const SizedBox(width: TdSpace.lg),
            Expanded(
              child: Text(
                l10n.scanOfflineMessage,
                style: context.text.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: TdSpace.md),
        Align(
          alignment: Alignment.centerLeft,
          child: TdChip(
            label: l10n.scanCodeLabel(code),
            icon: Icons.qr_code_2_rounded,
            dense: true,
          ),
        ),
        const SizedBox(height: TdSpace.xl),
        TdButton.primary(
          label: l10n.retry,
          icon: Icons.refresh_rounded,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(_OfflineAction.retry),
        ),
        const SizedBox(height: TdSpace.sm),
        TdButton.secondary(
          label: l10n.scanUnknownTitle,
          icon: Icons.edit_outlined,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(_OfflineAction.name),
        ),
        const SizedBox(height: TdSpace.sm),
        TdButton.ghost(
          label: l10n.scanContinue,
          expanded: true,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}

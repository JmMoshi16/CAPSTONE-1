import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;
import 'package:flutter/services.dart';
import 'package:app_settings/app_settings.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../services/sound_service.dart';
import '../../models/models.dart';
import '../../widgets/eco_animations.dart';
import '../../widgets/ui.dart';
import '../../core/theme.dart' show wasteIcon, getRank;
import '../../widgets/notification_prompt.dart';
import 'scan_errors.dart';

/// Scanner accents sit on the camera image, so they use the bright brand mint in both themes.
const _kScanAccent = AppPalette.mint;

/// Shared points mapping — single source of truth in this file.
const _kPointsMap = {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5};

class QRScannerScreen extends StatefulWidget {
  final String userId;
  final String username;
  /// Lifetime points before this scan, to celebrate a rank-up (display only).
  final int lifetimeBefore;
  /// Spendable balance before this scan, for the success screen's counter (display only).
  final int pointsBefore;
  /// Long-pressing the Scan button opens the scanner with the flashlight already on.
  final bool startWithTorch;
  const QRScannerScreen({super.key, required this.userId, required this.username, this.lifetimeBefore = 0,
      this.pointsBefore = 0, this.startWithTorch = false});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with TickerProviderStateMixin {
  /// 0 -> 1 when a code is detected: the brackets tighten, thicken and turn white ("lock on").
  late final AnimationController _lockCtrl = AnimationController(vsync: this, duration: AppMotion.medium);
  late final MobileScannerController _controller = MobileScannerController(torchEnabled: widget.startWithTorch);
  bool _scanned = false;
  bool _processing = false;

  // FIX 4: Torch state
  late bool _torchOn = widget.startWithTorch;

  // FIX 7: Permission denied state
  bool _permissionDenied = false;

  // FIX 5: Scan line animation
  late AnimationController _scanLineCtrl;
  late Animation<double> _scanLineAnim;

  @override
  void initState() {
    super.initState();
    _scanLineCtrl = AnimationController(
      vsync: this,
      duration: AppMotion.ambient,
    )..repeat(reverse: true);
    _scanLineAnim = _scanLineCtrl;
    // FIX 7: Detect camera permission denial on start
    _controller.start().catchError((_) {
      if (mounted) setState(() => _permissionDenied = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) {
      _scanLineCtrl
        ..stop()
        ..value = 0.5;   // a still line across the middle of the frame
    }
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _lockCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String raw) async {
    if (_scanned || _processing) return;
    // Immediate feedback that the code was seen, before the network round trip.
    AppHaptics.primary();
    // Our soft blip when sounds are on; otherwise the system click (follows touch-sound settings).
    if (AppSounds.active) {
      AppSounds.play(AppSound.scan);
    } else {
      SystemSound.play(SystemSoundType.click);
    }
    setState(() => _processing = true);
    _lockCtrl.forward();
    await _controller.stop();

    final code = parseBinCode(raw);
    if (code.error != null) {
      _showError(code.error!);
      return;
    }
    final wasteType = code.wasteType;
    final token = code.token;

    try {
      final result = await FirebaseService.validateAndUseQRToken(token, widget.userId);
      final error = scanErrorFor(result);
      if (error != null) {
        _showError(error);
        return;
      }

      final basePoints = _kPointsMap[wasteType] ?? 5;
      final log = WasteLog(
        userId: widget.userId,
        wasteType: wasteType,
        pointsEarned: basePoints,
        timestamp: DateTime.now(),
        binId: token.substring(0, 8),
      );
      final credit = await FirebaseService.logWaste(log);
      final points = credit.pointsAwarded;   // what was credited, incl. streak bonus (audit M-11)
      final newBadges = credit.newBadges;
      setState(() => _scanned = true);

      // Fire local notifications
      await NotificationService.showPointsCredited(
          wasteType: wasteType, points: points, basePoints: basePoints, multiplier: credit.multiplier);
      for (final id in newBadges) {
        // A light tap for each badge unlocked (the success pulse follows)
        AppHaptics.primary();
        final info = FirebaseService.getBadgeInfo(id);
        await NotificationService.showBadgeUnlocked(
          info['icon'] as String, info['label'] as String);
      }

      // FIX 6: Haptic on successful scan just before navigation
      AppHaptics.success();

      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _SuccessScreen(
              wasteType: wasteType,
              points: points,
              basePoints: basePoints,
              multiplier: credit.multiplier,
              token: token,
              username: widget.username,
              newBadges: newBadges,
              lifetimeBefore: widget.lifetimeBefore,
              pointsBefore: widget.pointsBefore,
            ),
          ),
        );
      }
    } catch (_) {
      // Never show raw exception text to customers (audit M-17).
      _showError(ScanError.offline);
    }
  }

  void _showError(ScanError e) {
    if (!mounted) return;
    setState(() => _processing = false);
    _lockCtrl.reverse();
    AppHaptics.error();
    showScanErrorDialog(context, e,
        onScanAgain: () => _controller.start(),
        onBack: () => Navigator.pop(context));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.text;
    // FIX 7: Permission denied UI
    if (_permissionDenied) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: const Text('Scan QR Code'),
          leading: BackButton(onPressed: () => Navigator.pop(context)),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, color: Colors.white70, size: 40),
              ),
              const SizedBox(height: AppSpace.lg),
              Text('Camera Permission Required',
                  style: t.titleLarge!.copyWith(color: Colors.white),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.xs),
              Text('Please allow camera access to scan QR codes',
                  style: t.bodyMedium!.copyWith(color: Colors.white70),
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpace.xl + 4),
              FilledButton.icon(
                onPressed: () async {
                  setState(() => _permissionDenied = false);
                  try {
                    await _controller.start();
                  } catch (_) {
                    // Still blocked: stay on this screen instead of an unhandled error.
                    if (mounted) setState(() => _permissionDenied = true);
                  }
                },
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Retry Camera Access'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kScanAccent,
                  foregroundColor: AppPalette.forestDeep,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md - 2),
                ),
              ),
              const SizedBox(height: AppSpace.sm),
              // If access was denied with "Don't ask again", only the settings page can turn it on.
              TextButton.icon(
                onPressed: () => AppSettings.openAppSettings(),
                icon: const Icon(Icons.settings_rounded, color: Colors.white),
                label: const Text('Open settings', style: TextStyle(color: Colors.white)),
              ),
              Text('Then allow Camera and come back.',
                  style: t.bodySmall!.copyWith(color: Colors.white70), textAlign: TextAlign.center),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Semantics(
            label: 'Camera viewfinder. Point it at the QR code on the bin.',
            child: MobileScanner(
              controller: _controller,
              onDetect: (capture) {
                final barcode = capture.barcodes.firstOrNull;
                if (barcode?.rawValue != null) _handleScan(barcode!.rawValue!);
              },
            ),
          ),
          // FIX 5: Animated scan line via AnimatedBuilder
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: Listenable.merge([_scanLineAnim, _lockCtrl]),
              builder: (_, __) => CustomPaint(
                painter: _ScanOverlayPainter(
                    scanProgress: _scanLineAnim.value, lock: AppMotion.spring.transform(_lockCtrl.value)),
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Framing hint just above the scan window (the window is 65 % of the width, centred).
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(builder: (_, box) {
                final scan = box.maxWidth * 0.65;
                final top = (box.maxHeight - scan) / 2;
                return Padding(
                  padding: EdgeInsets.fromLTRB(AppSpace.xl, (top - 48).clamp(0.0, double.infinity), AppSpace.xl, 0),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Text(
                      _processing ? 'Code found' : "Fit the bin's QR code inside the frame",
                      textAlign: TextAlign.center,
                      style: t.titleSmall!.copyWith(color: Colors.white, shadows: const [Shadow(blurRadius: 6)]),
                    ),
                  ),
                );
              }),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpace.md),
              child: Row(
                children: [
                  Tap(label: 'Back', tooltip: true,
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: AppRadius.all(AppRadius.md)),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  Expanded(child: Text('Scan QR Code', style: t.titleLarge!.copyWith(color: Colors.white))),
                  // FIX 4: Torch toggle with visual on/off state
                  Tap(label: _torchOn ? 'Turn flashlight off' : 'Turn flashlight on', tooltip: true, selected: _torchOn,
                    onTap: () {
                      _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                    child: AnimatedContainer(
                      duration: AppMotion.of(context, AppMotion.medium),
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: _torchOn ? AppPalette.coin[1] : Colors.black54,
                        borderRadius: AppRadius.all(AppRadius.md),
                      ),
                      child: Icon(
                        _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: _torchOn ? Colors.black : Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              margin: const EdgeInsets.fromLTRB(AppSpace.xl, 0, AppSpace.xl, AppSpace.xxl * 2),
              padding: const EdgeInsets.all(AppSpace.lg),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: AppRadius.all(AppRadius.xl)),
              // The card morphs: it resizes smoothly while its content cross-fades and grows in.
              child: AnimatedSize(
                duration: AppMotion.of(context, AppMotion.medium),
                curve: AppMotion.standard,
                child: AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.medium),
                  transitionBuilder: (child, a) => FadeTransition(
                    opacity: a,
                    child: ScaleTransition(scale: Tween<double>(begin: 0.9, end: 1).animate(a), child: child),
                  ),
                  child: _processing
                      ? Column(key: const ValueKey('verifying'), mainAxisSize: MainAxisSize.min, children: [
                          const EcoLoader(size: 56, semanticLabel: 'Verifying your code'),
                          const SizedBox(height: AppSpace.xs),
                          Semantics(
                            liveRegion: true,
                            child: Text('Verifying your code…',
                                style: t.titleSmall!.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
                                textAlign: TextAlign.center),
                          ),
                        ])
                      : Column(key: const ValueKey('aim'), mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.recycling_rounded, color: _kScanAccent, size: 28),
                          const SizedBox(height: AppSpace.xs),
                          Text('Point your camera at the code on the ECOReward bin',
                              style: t.bodyMedium!.copyWith(color: Colors.white), textAlign: TextAlign.center),
                          const SizedBox(height: AppSpace.xxs),
                          Text('Tap the flash icon if it is dark', style: t.labelSmall!.copyWith(color: Colors.white70)),
                        ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The success screen, for layout tests.
@visibleForTesting
Widget successScreenPreview({
  String wasteType = 'Recyclable',
  int points = 15,
  int basePoints = 10,
  double multiplier = 1.5,
  List<String> newBadges = const [],
  int lifetimeBefore = 0,
  int pointsBefore = 120,
}) =>
    _SuccessScreen(
      wasteType: wasteType, points: points, basePoints: basePoints, multiplier: multiplier,
      token: 'test-token', username: 'tester', newBadges: newBadges, lifetimeBefore: lifetimeBefore,
      pointsBefore: pointsBefore,
    );

// ── Full-screen Success Screen ────────────────────────────────────────────────
class _SuccessScreen extends StatefulWidget {
  final String wasteType;
  final int points;
  final int basePoints;
  final double multiplier;
  final String token;
  final String username;
  final List<String> newBadges;
  final int lifetimeBefore;
  final int pointsBefore;
  const _SuccessScreen({
    this.pointsBefore = 0,
    required this.wasteType,
    required this.points,
    required this.basePoints,
    this.multiplier = 1.0,
    required this.token,
    required this.username,
    this.newBadges = const [],
    this.lifetimeBefore = 0,
  });
  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen> with TickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  // "+N" flies from the points card into the balance counter, which then counts up.
  late final AnimationController _flyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  final _stackKey = GlobalKey();
  final _cardKey = GlobalKey();
  final _balanceKey = GlobalKey();
  (Offset, Offset)? _flight;
  bool _landed = false;

  Offset? _centreOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final stack = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || stack == null || !box.hasSize) return null;
    return stack.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  void _startFlight() {
    if (!mounted) return;
    if (AppMotion.reduced(context)) {
      setState(() => _landed = true);
      return;
    }
    final from = _centreOf(_cardKey), to = _centreOf(_balanceKey);
    if (from == null || to == null) {
      setState(() => _landed = true);
      return;
    }
    setState(() => _flight = (from, to));
    _flyCtrl.forward().then((_) {
      if (!mounted) return;
      AppHaptics.tap();
      setState(() => _landed = true);
    });
  }
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: AppMotion.standard);
    _animCtrl.forward();
    if (_rankedUp) AppHaptics.success(); // heavy is kept for errors
    AppSounds.play(AppSound.success);
    if (_rankedUp || widget.newBadges.isNotEmpty) {
      Future.delayed(const Duration(milliseconds: 700), () => AppSounds.play(AppSound.badge));
    }
    // Let the screen settle (fade-in, Lottie) before the points take off.
    Future.delayed(const Duration(milliseconds: 650), _startFlight);
    // Once per device, after the celebration: explain notifications, then ask (Android 13+).
    Future.delayed(AppMotion.celebration, () {
      if (mounted) askForNotificationsOnce(context);
    });
  }

  /// Rank before and after this scan's credited points (lifetime points drive rank).
  late final _rankBefore = getRank(widget.lifetimeBefore);
  late final _rankAfter = getRank(widget.lifetimeBefore + widget.points);
  bool get _rankedUp => widget.lifetimeBefore > 0 && _rankAfter.minPts > _rankBefore.minPts;

  @override
  void dispose() { _animCtrl.dispose(); _flyCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final fill = c.wasteFill(widget.wasteType);
    return Scaffold(
      body: Stack(key: _stackKey, children: [
      SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.lg),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // Balance counter: the earned points fly into it, then it counts up.
                Container(
                  key: _balanceKey,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.xs),
                  decoration: cardDecoration(context, radius: AppRadius.pill, borderColor: c.gold.withValues(alpha: 0.5)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.stars_rounded, color: AppPalette.coin[1], size: 20),
                    const SizedBox(width: AppSpace.xs - 2),
                    AnimatedCount(
                      _landed ? widget.pointsBefore + widget.points : widget.pointsBefore,
                      format: NumberFormat('#,###').format,
                      suffix: ' pts',
                      duration: const Duration(milliseconds: 600),   // part of the celebration
                      style: t.titleMedium!.copyWith(fontFamily: AppType.displayFamily),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpace.xs),
                // Brand success animation (plays once)
                const EcoSuccess(size: 140),
                const SizedBox(height: AppSpace.xs),
                Text('Waste Verified!', style: t.headlineMedium!.copyWith(color: c.primary)),
                const SizedBox(height: AppSpace.xxs),
                Text('Thank you for recycling responsibly 🌿', style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.xl),

                // ── Rank-up (wired from the old, unused showRankUp idea) ──
                if (_rankedUp) ...[
                  FlipReveal(
                    delay: const Duration(milliseconds: 300),
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpace.md),
                        decoration: cardDecoration(context, color: c.primaryContainer,
                            borderColor: c.ink(_rankAfter.color).withValues(alpha: 0.6)),
                        child: Row(children: [
                          ExcludeSemantics(child: Text(_rankAfter.icon, style: const TextStyle(fontSize: 34))),
                          const SizedBox(width: AppSpace.sm),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('Rank up!', style: t.titleMedium!.copyWith(color: c.onPrimaryContainer)),
                            Text('${_rankBefore.label} → ${_rankAfter.label}',
                                style: t.titleSmall!.copyWith(color: c.ink(_rankAfter.color), fontWeight: FontWeight.w800)),
                          ])),
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],

                // ── New badges notification ──
                if (widget.newBadges.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: cardDecoration(context, color: c.isDark ? c.surface : AppPalette.goldWash,
                        borderColor: c.gold.withValues(alpha: 0.5)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.emoji_events_rounded, color: c.gold, size: 20),
                          const SizedBox(width: AppSpace.xs),
                          Text('Badge Unlocked!', style: t.titleSmall!.copyWith(color: c.gold, fontWeight: FontWeight.w700)),
                        ]),
                        const SizedBox(height: AppSpace.sm - 2),
                        ...widget.newBadges.indexed.map((e) {
                          final (i, id) = e;
                          final info = FirebaseService.getBadgeInfo(id);
                          // Each new badge flips into view, one after another.
                          return FlipReveal(
                            delay: const Duration(milliseconds: 500) + AppMotion.slow * i,
                            child: Container(
                            margin: const EdgeInsets.only(bottom: AppSpace.xs),
                            padding: const EdgeInsets.all(AppSpace.xs),
                            decoration: BoxDecoration(
                              color: c.surface.withValues(alpha: c.isDark ? 1 : 0.8),
                              borderRadius: AppRadius.all(AppRadius.md),
                              boxShadow: AppShadows.glow(AppPalette.medalGold, strength: 0.55),
                            ),
                            child: Row(children: [
                              Text(info['icon'] as String, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: AppSpace.sm - 2),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(info['label'] as String, style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                                Text(info['desc'] as String, style: t.bodySmall),
                              ])),
                            ]),
                          ));
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],

                // Points card (white text on a deep waste-type fill: at least 5.6:1)
                Container(
                  key: _cardKey,
                  padding: const EdgeInsets.all(AppSpace.lg),
                  decoration: BoxDecoration(
                    color: fill,
                    borderRadius: AppRadius.all(AppRadius.xl + 4),
                    boxShadow: AppShadows.of(context,
                        [BoxShadow(color: fill.withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 6))]),
                  ),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: AppRadius.all(AppRadius.lg)),
                      child: Icon(wasteIcon(widget.wasteType), color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: AppSpace.md),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Category: ${widget.wasteType}',
                          style: t.labelMedium!.copyWith(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      AnimatedCount(widget.points, fromZero: true, prefix: '+', suffix: ' Points Earned',
                          duration: const Duration(milliseconds: 700),   // part of the celebration
                          style: t.titleLarge!.copyWith(color: Colors.white, fontSize: 20)),
                      if (widget.multiplier > 1.0)
                        // Display only: what was credited, broken down (+15 × 1.5 streak bonus = +23).
                        Text('+${widget.basePoints} × ${_fmtMultiplier(widget.multiplier)} streak bonus = +${widget.points} 🔥',
                            style: t.labelMedium!.copyWith(color: Colors.white.withValues(alpha: 0.95))),
                    ])),
                    Container(
                      padding: const EdgeInsets.all(AppSpace.sm - 2),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: Icon(Icons.stars_rounded, color: AppPalette.coin[1], size: 24),
                    ),
                  ]),
                ),
                const SizedBox(height: AppSpace.lg),

                // Done button
                AppButton(
                  label: 'Awesome! Back to Home',
                  height: 56,
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(height: AppSpace.lg),
              ],
            ),
          ),
        ),
      ),
      // Celebration: a confetti burst, stronger (gold, side cannons) when a badge unlocked.
      Positioned.fill(child: ConfettiBurst(strong: widget.newBadges.isNotEmpty || _rankedUp)),
      if (_flight != null && !_landed)
        AnimatedBuilder(
          animation: _flyCtrl,
          builder: (_, __) {
            final t = Curves.easeInOutCubic.transform(_flyCtrl.value);
            final (from, to) = _flight!;
            final p = Offset.lerp(from, to, t)!;
            return Positioned(
              left: p.dx,
              top: p.dy - 60 * math.sin(math.pi * t),   // a gentle arc
              child: FractionalTranslation(
                translation: const Offset(-0.5, -0.5),
                child: IgnorePointer(
                  child: Transform.scale(
                    scale: 1.2 - 0.4 * t,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xxs + 2),
                      decoration: BoxDecoration(
                        // Light gold only: the dark text stays >= 9.9:1 across the chip.
                        gradient: LinearGradient(colors: [AppPalette.coin[0], AppPalette.coin[1]]),
                        borderRadius: AppRadius.all(AppRadius.pill),
                        boxShadow: AppShadows.glow(AppPalette.coin[1], strength: 0.8),
                      ),
                      child: Text('+${widget.points}',
                          style: context.text.titleMedium!.copyWith(color: const Color(0xFF3A2A00), fontWeight: FontWeight.w800)),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
    ]),
    );
  }
} // end _SuccessScreenState

String _fmtMultiplier(double m) => m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toString();


// ── Scan Overlay ──────────────────────────────────────────────────────────────
// FIX 5: Accepts scanProgress (0.0–1.0) to animate the scan line
class _ScanOverlayPainter extends CustomPainter {
  final double scanProgress;
  /// 0 = searching, 1 = locked on a code.
  final double lock;
  const _ScanOverlayPainter({required this.scanProgress, this.lock = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withValues(alpha: 0.55);
    final scanSize = size.width * 0.65;
    final left = (size.width - scanSize) / 2;
    final top = (size.height - scanSize) / 2;
    final scanRect = Rect.fromLTWH(left, top, scanSize, scanSize);
    canvas.drawPath(
      Path.combine(PathOperation.difference,
        Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height)),
        Path()..addRRect(RRect.fromRectAndRadius(scanRect, const Radius.circular(16))),
      ),
      paint,
    );
    final cp = Paint()
      ..color = Color.lerp(_kScanAccent, Colors.white, lock.clamp(0.0, 1.0))!
      ..strokeWidth = 3.5 + 2 * lock
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final c = 28.0 + 16 * lock;
    // Locking on: the brackets close in by 6 % of the window.
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1 - 0.12 * lock);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.drawLine(Offset(left, top + c), Offset(left, top), cp);
    canvas.drawLine(Offset(left, top), Offset(left + c, top), cp);
    canvas.drawLine(Offset(left + scanSize - c, top), Offset(left + scanSize, top), cp);
    canvas.drawLine(Offset(left + scanSize, top), Offset(left + scanSize, top + c), cp);
    canvas.drawLine(Offset(left, top + scanSize - c), Offset(left, top + scanSize), cp);
    canvas.drawLine(Offset(left, top + scanSize), Offset(left + c, top + scanSize), cp);
    canvas.drawLine(Offset(left + scanSize - c, top + scanSize), Offset(left + scanSize, top + scanSize), cp);
    canvas.drawLine(Offset(left + scanSize, top + scanSize), Offset(left + scanSize, top + scanSize - c), cp);
    canvas.restore();

    // Animated scan line moves from top to bottom of scan zone (fades out once locked)
    if (lock < 1) {
      final lineY = top + scanSize * scanProgress;
      final a = 0.8 * (1 - lock.clamp(0.0, 1.0));
      final linePaint = Paint()
        ..shader = LinearGradient(colors: [Colors.transparent, _kScanAccent.withValues(alpha: a), Colors.transparent])
            .createShader(Rect.fromLTWH(left, lineY, scanSize, 2));
      canvas.drawLine(Offset(left, lineY), Offset(left + scanSize, lineY), linePaint..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.scanProgress != scanProgress || old.lock != lock;
}

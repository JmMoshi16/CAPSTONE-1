import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../models/models.dart';
import '../../widgets/eco_animations.dart';
import '../../widgets/ui.dart';
import '../../core/theme.dart' show wasteIcon;

/// Scanner accents sit on the camera image, so they use the bright brand mint in both themes.
const _kScanAccent = AppPalette.mint;

/// Shared points mapping — single source of truth in this file.
const _kPointsMap = {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5};

class QRScannerScreen extends StatefulWidget {
  final String userId;
  final String username;
  const QRScannerScreen({super.key, required this.userId, required this.username});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _processing = false;

  // FIX 4: Torch state
  bool _torchOn = false;

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
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String raw) async {
    if (_scanned || _processing) return;
    // Immediate feedback that the code was seen, before the network round trip.
    HapticFeedback.mediumImpact();
    SystemSound.play(SystemSoundType.click);
    setState(() => _processing = true);
    await _controller.stop();

    // Limit to 3 parts so colons inside the UUID token are preserved
    final parts = raw.split(':').take(3).toList();
    if (parts.length < 3 || parts[0] != 'ECOBIN') {
      _showError('Not an ECOReward code',
          "This QR code isn't from an ECOReward bin. Scan the code shown on the bin's screen.");
      return;
    }

    final wasteType = parts[1];
    final token = parts[2];
    final validTypes = ['Biodegradable', 'Recyclable', 'Residual'];
    if (!validTypes.contains(wasteType)) {
      _showError('Code not recognised',
          "We couldn't read the waste type from this code. Scan the bin's code again, or ask staff for a new one.");
      return;
    }

    try {
      final result = await FirebaseService.validateAndUseQRToken(token, widget.userId);
      if (result == QRValidationResult.expired) {
        _showError('Code expired',
            'Bin codes work for 20 minutes. Your next disposal at the bin gives you a new code, or staff can make one for you.',
            kind: _ErrorKind.warning, icon: Icons.timer_off_rounded);
        return;
      }
      if (result == QRValidationResult.alreadyUsed) {
        _showError('Already claimed',
            'Each bin code can be claimed once, and this one has been. Your next disposal will give you a new code.',
            kind: _ErrorKind.warning, icon: Icons.check_circle_outline_rounded);
        return;
      }
      if (result == QRValidationResult.invalid) {
        _showError('Code not found',
            "We couldn't find this code. Make sure you're scanning the code on the bin's screen right now.");
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
        // FIX 6: Haptic for each badge unlocked
        HapticFeedback.lightImpact();
        final info = FirebaseService.getBadgeInfo(id);
        await NotificationService.showBadgeUnlocked(
          info['icon'] as String, info['label'] as String);
      }

      // FIX 6: Haptic on successful scan just before navigation
      HapticFeedback.lightImpact();

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
            ),
          ),
        );
      }
    } catch (_) {
      // Never show raw exception text to customers (audit M-17).
      _showError("Couldn't reach ECOReward",
          'We could not finish this scan. Check your internet connection and scan the code again.',
          icon: Icons.wifi_off_rounded);
    }
  }

  void _showError(String title, String message,
      {_ErrorKind kind = _ErrorKind.error, IconData icon = Icons.error_rounded}) {
    if (!mounted) return;
    setState(() => _processing = false);
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) {
        final c = ctx.colors;
        final warn = kind == _ErrorKind.warning;
        return AlertDialog(
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(color: warn ? c.warningContainer : c.dangerContainer, shape: BoxShape.circle),
              child: Icon(icon, color: warn ? c.warning : c.danger, size: 36),
            ),
            const SizedBox(height: AppSpace.md - 2),
            Text(title, style: ctx.text.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: AppSpace.xs - 2),
            Text(message, style: ctx.text.bodyMedium!.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
          ]),
          actions: [
            Column(mainAxisSize: MainAxisSize.min, children: [
              AppButton(
                label: 'Scan again',
                icon: Icons.qr_code_scanner_rounded,
                height: 48,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _controller.start();
                },
              ),
              const SizedBox(height: AppSpace.xs),
              AppButton.secondary(
                label: 'Back to Home',
                height: 48,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
              ),
            ]),
          ],
        );
      },
    );
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
                  await _controller.start();
                },
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Retry Camera Access'),
                style: FilledButton.styleFrom(
                  backgroundColor: _kScanAccent,
                  foregroundColor: AppPalette.forestDeep,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.md - 2),
                ),
              ),
            ]),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final barcode = capture.barcodes.firstOrNull;
              if (barcode?.rawValue != null) _handleScan(barcode!.rawValue!);
            },
          ),
          // FIX 5: Animated scan line via AnimatedBuilder
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _scanLineAnim,
              builder: (_, __) => CustomPaint(
                painter: _ScanOverlayPainter(scanProgress: _scanLineAnim.value),
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
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                if (_processing)
                  const EcoLoader(size: 56, semanticLabel: 'Verifying your code')
                else
                  const Icon(Icons.recycling_rounded, color: _kScanAccent, size: 28),
                const SizedBox(height: AppSpace.xs),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _processing ? 'Verifying your code…' : 'Point your camera at the code on the ECOReward bin',
                    style: t.bodyMedium!.copyWith(color: Colors.white, fontWeight: _processing ? FontWeight.w700 : null),
                    textAlign: TextAlign.center),
                ),
                if (!_processing) ...[
                  const SizedBox(height: AppSpace.xxs),
                  Text('Tap the flash icon if it is dark', style: t.labelSmall!.copyWith(color: Colors.white70)),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full-screen Success Screen ────────────────────────────────────────────────
class _SuccessScreen extends StatefulWidget {
  final String wasteType;
  final int points;
  final int basePoints;
  final double multiplier;
  final String token;
  final String username;
  final List<String> newBadges;
  const _SuccessScreen({
    required this.wasteType,
    required this.points,
    required this.basePoints,
    this.multiplier = 1.0,
    required this.token,
    required this.username,
    this.newBadges = const [],
  });
  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: AppMotion.standard);
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    final fill = c.wasteFill(widget.wasteType);
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.xl, vertical: AppSpace.lg),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // Brand success animation (plays once)
                const EcoSuccess(size: 140),
                const SizedBox(height: AppSpace.xs),
                Text('Waste Verified!', style: t.headlineMedium!.copyWith(color: c.primary)),
                const SizedBox(height: AppSpace.xxs),
                Text('Thank you for recycling responsibly 🌿', style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                const SizedBox(height: AppSpace.xl),

                // ── New badges notification ──
                if (widget.newBadges.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpace.md),
                    decoration: cardDecoration(context, color: c.isDark ? c.surface : const Color(0xFFFFF8E1),
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
                        ...widget.newBadges.map((id) {
                          final info = FirebaseService.getBadgeInfo(id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpace.xs - 2),
                            child: Row(children: [
                              Text(info['icon'] as String, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: AppSpace.sm - 2),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(info['label'] as String, style: t.titleSmall!.copyWith(fontWeight: FontWeight.w700)),
                                Text(info['desc'] as String, style: t.bodySmall),
                              ])),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpace.md),
                ],

                // Points card (white text on a deep waste-type fill: at least 5.6:1)
                Container(
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
                      Text('+${widget.points} Points Earned',
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
    );
  }
} // end _SuccessScreenState

String _fmtMultiplier(double m) => m == m.roundToDouble() ? m.toStringAsFixed(0) : m.toString();

enum _ErrorKind { error, warning }

// ── Scan Overlay ──────────────────────────────────────────────────────────────
// FIX 5: Accepts scanProgress (0.0–1.0) to animate the scan line
class _ScanOverlayPainter extends CustomPainter {
  final double scanProgress;
  const _ScanOverlayPainter({required this.scanProgress});

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
    final cp = Paint()..color = _kScanAccent..strokeWidth = 3.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const c = 28.0;
    canvas.drawLine(Offset(left, top + c), Offset(left, top), cp);
    canvas.drawLine(Offset(left, top), Offset(left + c, top), cp);
    canvas.drawLine(Offset(left + scanSize - c, top), Offset(left + scanSize, top), cp);
    canvas.drawLine(Offset(left + scanSize, top), Offset(left + scanSize, top + c), cp);
    canvas.drawLine(Offset(left, top + scanSize - c), Offset(left, top + scanSize), cp);
    canvas.drawLine(Offset(left, top + scanSize), Offset(left + c, top + scanSize), cp);
    canvas.drawLine(Offset(left + scanSize - c, top + scanSize), Offset(left + scanSize, top + scanSize), cp);
    canvas.drawLine(Offset(left + scanSize, top + scanSize), Offset(left + scanSize, top + scanSize - c), cp);

    // Animated scan line moves from top to bottom of scan zone
    final lineY = top + scanSize * scanProgress;
    final linePaint = Paint()
      ..shader = LinearGradient(colors: [Colors.transparent, _kScanAccent.withValues(alpha: 0.8), Colors.transparent])
          .createShader(Rect.fromLTWH(left, lineY, scanSize, 2));
    canvas.drawLine(Offset(left, lineY), Offset(left + scanSize, lineY), linePaint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.scanProgress != scanProgress;
}

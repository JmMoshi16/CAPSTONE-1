import 'package:flutter/material.dart';
import '../../core/tap.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/firebase_service.dart';
import '../../services/notification_service.dart';
import '../../models/models.dart';

const _kGreen = Color(0xFF2ECC71);
const _kDarkGreen = Color(0xFF1A8A4A);
const _kEmerald = Color(0xFF00B894);

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
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _scanLineAnim = _scanLineCtrl;
    // FIX 7: Detect camera permission denial on start
    _controller.start().catchError((_) {
      if (mounted) setState(() => _permissionDenied = true);
    });
  }

  @override
  void dispose() {
    _scanLineCtrl.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String raw) async {
    if (_scanned || _processing) return;
    setState(() => _processing = true);
    await _controller.stop();

    // Limit to 3 parts so colons inside the UUID token are preserved
    final parts = raw.split(':').take(3).toList();
    if (parts.length < 3 || parts[0] != 'ECOBIN') {
      _showError('Invalid QR Code', 'This QR code is not from an ECOReward Bin.');
      return;
    }

    final wasteType = parts[1];
    final token = parts[2];
    final validTypes = ['Biodegradable', 'Recyclable', 'Residual'];
    if (!validTypes.contains(wasteType)) {
      _showError('Invalid Waste Type', 'Unrecognized waste category.');
      return;
    }

    try {
      final result = await FirebaseService.validateAndUseQRToken(token, widget.userId);
      if (result == QRValidationResult.expired) {
        _showError('QR Expired', 'This QR code has expired. Ask admin to generate a new one.');
        return;
      }
      if (result == QRValidationResult.alreadyUsed) {
        _showError('Already Used', 'You have already scanned this QR code.');
        return;
      }
      if (result == QRValidationResult.invalid) {
        _showError('Invalid QR Code', 'This QR code is not recognized.');
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
      await NotificationService.showPointsCredited(wasteType: wasteType, points: points);
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
      _showError('Something went wrong',
          'We could not process this QR code. Check your connection and try again.');
    }
  }

  void _showError(String title, String message) {
    if (!mounted) return;
    setState(() => _processing = false);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.error_rounded, color: Colors.red, size: 36),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: const TextStyle(color: Colors.grey, fontSize: 13), textAlign: TextAlign.center),
        ]),
        actions: [
          SizedBox(width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _controller.start();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
              child: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.08), shape: BoxShape.circle),
                child: const Icon(Icons.lock_rounded, color: Colors.white54, size: 40),
              ),
              const SizedBox(height: 20),
              const Text('Camera Permission Required',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Please allow camera access to scan QR codes',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                  textAlign: TextAlign.center),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () async {
                  setState(() => _permissionDenied = false);
                  await _controller.start();
                },
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Retry Camera Access'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
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
          AnimatedBuilder(
            animation: _scanLineAnim,
            builder: (_, __) => CustomPaint(
              painter: _ScanOverlayPainter(scanProgress: _scanLineAnim.value),
              child: const SizedBox.expand(),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Tap(label: 'Back', tooltip: true, 
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text('Scan QR Code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  // FIX 4: Torch toggle with visual on/off state
                  Tap(label: _torchOn ? 'Turn flashlight off' : 'Turn flashlight on', tooltip: true, selected: _torchOn, 
                    onTap: () {
                      _controller.toggleTorch();
                      setState(() => _torchOn = !_torchOn);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _torchOn ? Colors.amber : Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _torchOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
                        color: Colors.white,
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
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 60),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(20)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.recycling_rounded, color: _kGreen, size: 28),
                const SizedBox(height: 8),
                const Text('Point camera at the ECOReward Bin QR code',
                    style: TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center),
                if (_processing) ...[
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(color: _kGreen, strokeWidth: 2),
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
  final double multiplier;
  final String token;
  final String username;
  final List<String> newBadges;
  const _SuccessScreen({
    required this.wasteType,
    required this.points,
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
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _scaleAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeIn);
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Color get _wasteColor {
    switch (widget.wasteType) {
      case 'Biodegradable': return const Color(0xFF8BC34A);
      case 'Recyclable': return const Color(0xFF29B6F6);
      default: return const Color(0xFFEF5350);
    }
  }

  IconData get _wasteIcon {
    switch (widget.wasteType) {
      case 'Biodegradable': return Icons.compost_rounded;
      case 'Recyclable': return Icons.recycling_rounded;
      default: return Icons.delete_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0FFF4),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: FadeTransition(
            opacity: _fadeAnim,
            child: Column(
              children: [
                // Check animation
                ScaleTransition(
                  scale: _scaleAnim,
                  child: Container(
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [_kGreen, _kEmerald],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: _kGreen.withValues(alpha: 0.4), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Waste Verified!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                const SizedBox(height: 4),
                Text('Thank you for recycling responsibly 🌿', style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                const SizedBox(height: 24),

                // ── New badges notification ──
                if (widget.newBadges.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFF8E1), Color(0xFFFFF3CD)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(children: [
                          Icon(Icons.emoji_events_rounded, color: Colors.amber, size: 20),
                          SizedBox(width: 8),
                          Text('Badge Unlocked!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF7B5800))),
                        ]),
                        const SizedBox(height: 10),
                        ...widget.newBadges.map((id) {
                          final info = FirebaseService.getBadgeInfo(id);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Text(info['icon'] as String, style: const TextStyle(fontSize: 22)),
                              const SizedBox(width: 10),
                              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(info['label'] as String, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF5D4037))),
                                Text(info['desc'] as String, style: const TextStyle(color: Colors.brown, fontSize: 11)),
                              ]),
                            ]),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Points card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_wasteColor.withValues(alpha: 0.9), _wasteColor],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: _wasteColor.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
                      child: Icon(_wasteIcon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Category: ${widget.wasteType}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('+${widget.points} Points Earned',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                      if (widget.multiplier > 1.0)
                        Text('Includes ${widget.multiplier == 2.0 ? '2' : '1.5'}× streak bonus 🔥',
                            style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    ])),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                // Done button
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kDarkGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      elevation: 0,
                    ),
                    child: const Text('Awesome! Back to Home',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // end _SuccessScreenState

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
    final cp = Paint()..color = _kGreen..strokeWidth = 3.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
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
      ..shader = LinearGradient(colors: [Colors.transparent, _kGreen.withValues(alpha: 0.8), Colors.transparent])
          .createShader(Rect.fromLTWH(left, lineY, scanSize, 2));
    canvas.drawLine(Offset(left, lineY), Offset(left + scanSize, lineY), linePaint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_ScanOverlayPainter old) => old.scanProgress != scanProgress;
}

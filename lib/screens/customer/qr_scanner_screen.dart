import 'dart:math';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../services/firebase_service.dart';
import '../../models/models.dart';

const kGreen = Color(0xFF2ECC71);
const kDarkGreen = Color(0xFF1A8A4A);
const kEmerald = Color(0xFF00B894);

class QRScannerScreen extends StatefulWidget {
  final String userId;
  final String username;
  const QRScannerScreen({super.key, required this.userId, required this.username});
  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController _controller = MobileScannerController();
  bool _scanned = false;
  bool _processing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleScan(String raw) async {
    if (_scanned || _processing) return;
    setState(() => _processing = true);
    await _controller.stop();

    final parts = raw.split(':');
    if (parts.length != 3 || parts[0] != 'ECOBIN') {
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

      final pointsMap = {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5};
      final points = pointsMap[wasteType]!;
      final log = WasteLog(
        userId: widget.userId,
        wasteType: wasteType,
        pointsEarned: points,
        timestamp: DateTime.now(),
        binId: token.substring(0, 8),
      );
      await FirebaseService.logWaste(log);
      setState(() => _scanned = true);

      if (mounted) {
        await Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _SuccessScreen(
              wasteType: wasteType,
              points: points,
              token: token,
              username: widget.username,
            ),
          ),
        );
      }
    } catch (e) {
      _showError('Error', 'Failed to process QR: $e');
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
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
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
          CustomPaint(painter: _ScanOverlayPainter(), child: const SizedBox.expand()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  GestureDetector(
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
                  GestureDetector(
                    onTap: () => _controller.toggleTorch(),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 20),
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
              decoration: BoxDecoration(color: Colors.black.withOpacity(0.7), borderRadius: BorderRadius.circular(20)),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.recycling_rounded, color: kGreen, size: 28),
                const SizedBox(height: 8),
                const Text('Point camera at the ECOReward Bin QR code',
                    style: TextStyle(color: Colors.white, fontSize: 13), textAlign: TextAlign.center),
                if (_processing) ...[
                  const SizedBox(height: 10),
                  const CircularProgressIndicator(color: kGreen, strokeWidth: 2),
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
  final String token;
  final String username;
  const _SuccessScreen({required this.wasteType, required this.points, required this.token, required this.username});
  @override
  State<_SuccessScreen> createState() => _SuccessScreenState();
}

class _SuccessScreenState extends State<_SuccessScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;
  bool _showReceipt = false;

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

  String get _formattedDate {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    final h = now.hour > 12 ? now.hour - 12 : now.hour == 0 ? 12 : now.hour;
    final ampm = now.hour >= 12 ? 'PM' : 'AM';
    final m = now.minute.toString().padLeft(2, '0');
    return '${months[now.month-1]} ${now.day}, ${now.year}  $h:$m $ampm';
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
                      gradient: const LinearGradient(colors: [kGreen, kEmerald],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      boxShadow: [BoxShadow(color: kGreen.withOpacity(0.4), blurRadius: 24, offset: const Offset(0, 8))],
                    ),
                    child: const Icon(Icons.check_rounded, color: Colors.white, size: 52),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Waste Verified!', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF1B5E20))),
                const SizedBox(height: 4),
                Text('Thank you for recycling responsibly 🌿', style: TextStyle(color: Colors.green.shade700, fontSize: 13)),
                const SizedBox(height: 24),

                // Points card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_wasteColor.withOpacity(0.9), _wasteColor],
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [BoxShadow(color: _wasteColor.withOpacity(0.4), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(16)),
                      child: Icon(_wasteIcon, color: Colors.white, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Category: ${widget.wasteType}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 2),
                      Text('+${widget.points} Points Earned',
                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    ])),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.stars_rounded, color: Colors.amber, size: 24),
                    ),
                  ]),
                ),
                const SizedBox(height: 16),

                // Receipt toggle button
                GestureDetector(
                  onTap: () => setState(() => _showReceipt = !_showReceipt),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kGreen.withOpacity(0.3)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 3))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.receipt_long_rounded, color: kDarkGreen, size: 20),
                      const SizedBox(width: 8),
                      Text(_showReceipt ? 'Hide Receipt' : 'View Receipt (Claim Later)',
                          style: const TextStyle(color: kDarkGreen, fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(width: 6),
                      Icon(_showReceipt ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: kDarkGreen, size: 20),
                    ]),
                  ),
                ),

                // Receipt
                if (_showReceipt) ...[
                  const SizedBox(height: 16),
                  _buildReceipt(),
                ],

                const SizedBox(height: 20),

                // Done button
                SizedBox(
                  width: double.infinity, height: 56,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kDarkGreen,
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

  Widget _buildReceipt() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // Receipt header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
            ),
            child: Column(children: [
              const Icon(Icons.recycling_rounded, color: Colors.white, size: 32),
              const SizedBox(height: 8),
              const Text('ECOReward Bin', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const Text('Smart Waste Recycling', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text(_formattedDate, style: const TextStyle(color: Colors.white60, fontSize: 11)),
            ]),
          ),

          // Dashed divider
          _dashedDivider(),

          // Receipt body
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(children: [
              _receiptRow('Customer', widget.username),
              const SizedBox(height: 10),
              _receiptRow('Waste Type', widget.wasteType),
              const SizedBox(height: 10),
              _receiptRow('Points Earned', '+${widget.points} pts'),
              const SizedBox(height: 10),
              _receiptRow('Status', 'Verified ✓'),
            ]),
          ),

          _dashedDivider(),

          // QR code
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(children: [
              const Text('Scan to Claim Points Later',
                  style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)],
                ),
                child: QrImageView(
                  data: 'ECOBIN:${widget.wasteType}:${widget.token}',
                  version: QrVersions.auto,
                  size: 150,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF2ECC71)),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FFF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kGreen.withOpacity(0.2)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline_rounded, color: kDarkGreen, size: 16),
                  SizedBox(width: 8),
                  Expanded(child: Text(
                    'No internet? Show this receipt to staff to claim your points manually.',
                    style: TextStyle(color: kDarkGreen, fontSize: 11),
                  )),
                ]),
              ),
            ]),
          ),

          // Footer
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            ),
            child: const Text('Thank you for helping the environment! 🌍',
                style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }

  Widget _receiptRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1B5E20))),
        ],
      );

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: List.generate(30, (_) => Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              height: 1,
              color: Colors.grey.shade200,
            ),
          )),
        ),
      );
}

// ── Scan Overlay ──────────────────────────────────────────────────────────────
class _ScanOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.55);
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
    final cp = Paint()..color = kGreen..strokeWidth = 3.5..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    const c = 28.0;
    canvas.drawLine(Offset(left, top + c), Offset(left, top), cp);
    canvas.drawLine(Offset(left, top), Offset(left + c, top), cp);
    canvas.drawLine(Offset(left + scanSize - c, top), Offset(left + scanSize, top), cp);
    canvas.drawLine(Offset(left + scanSize, top), Offset(left + scanSize, top + c), cp);
    canvas.drawLine(Offset(left, top + scanSize - c), Offset(left, top + scanSize), cp);
    canvas.drawLine(Offset(left, top + scanSize), Offset(left + c, top + scanSize), cp);
    canvas.drawLine(Offset(left + scanSize - c, top + scanSize), Offset(left + scanSize, top + scanSize), cp);
    canvas.drawLine(Offset(left + scanSize, top + scanSize), Offset(left + scanSize, top + scanSize - c), cp);

    // Animated scan line
    final linePaint = Paint()
      ..shader = LinearGradient(colors: [Colors.transparent, kGreen.withOpacity(0.8), Colors.transparent])
          .createShader(Rect.fromLTWH(left, top, scanSize, 2));
    canvas.drawLine(Offset(left, top + scanSize / 2), Offset(left + scanSize, top + scanSize / 2), linePaint..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ignore: unused_element
double _degToRad(double deg) => deg * pi / 180;

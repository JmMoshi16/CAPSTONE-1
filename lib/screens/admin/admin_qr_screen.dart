import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../core/admin_theme.dart';
import '../../widgets/ui.dart';

const kGreen = kAdminGreen;
const kDark = kAdminDark;
const kCard = kAdminCard;
const kBorder = kAdminBorder;

// The receipt is printed paper, so it stays light in every theme (secondary text 6.2:1 on white).
const _kReceiptInk = Color(0xFF5B635D);
const _kReceiptRule = Color(0xFFE2E0D8);


class AdminQRScreen extends StatefulWidget {
  const AdminQRScreen({super.key});
  @override
  State<AdminQRScreen> createState() => _AdminQRScreenState();
}

class _AdminQRScreenState extends State<AdminQRScreen> {
  final _types = ['Biodegradable', 'Recyclable', 'Residual'];
  String _selectedType = 'Recyclable';
  String? _currentToken;
  DateTime? _expiresAt;
  String _mode = 'qr'; // 'qr' or 'receipt'
  bool _generating = false;
  bool _generateFailed = false;

  static const _validFor = Duration(minutes: 20);

  bool get _isExpired => _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  /// Shows the code only after Firestore has saved it, so staff never hand out a code
  /// that cannot be claimed.
  Future<void> _generate() async {
    if (_generating) return;
    final token = const Uuid().v4();
    final expiry = DateTime.now().add(_validFor);
    setState(() { _generating = true; _generateFailed = false; _currentToken = null; _expiresAt = null; });
    try {
      await FirebaseService.createQRToken(token, _selectedType, expiry).timeout(const Duration(seconds: 10));
      if (mounted) setState(() { _currentToken = token; _expiresAt = expiry; });
    } catch (_) {
      if (mounted) setState(() => _generateFailed = true);
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  String get _qrData => 'ECOBIN:$_selectedType:$_currentToken';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      appBar: AppBar(
        backgroundColor: kCard,
        automaticallyImplyLeading: false,
        title: const Text('Generate for Customer', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpace.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Mode selector
            const Text('Customer Preference', style: TextStyle(color: AdminColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _modeCard('qr', Icons.qr_code_rounded, 'QR Code', 'Customer scans with phone')),
              const SizedBox(width: AppSpace.sm),
              Expanded(child: _modeCard('receipt', Icons.receipt_long_rounded, 'Paper Receipt', 'Print it; scan in the app within 20 min')),
            ]),
            const SizedBox(height: AppSpace.xl),

            // Waste type
            const Text('Waste Type', style: TextStyle(color: AdminColors.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: _types.map((t) {
                final selected = _selectedType == t;
                final colors = {
                  'Biodegradable': AdminColors.bio,
                  'Recyclable': AdminColors.rec,
                  'Residual': AdminColors.res,
                };
                final color = colors[t]!;
                return Expanded(
                  child: Tap(
                    label: '$t waste',
                    selected: selected,
                    onTap: () => setState(() {
                      _selectedType = t;
                      _currentToken = null;
                      _expiresAt = null;
                    }),
                    child: AnimatedContainer(
                      duration: AppMotion.medium,
                      margin: const EdgeInsets.only(right: AppSpace.xs),
                      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
                      decoration: BoxDecoration(
                        color: selected ? color.withValues(alpha: 0.15) : kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? color : kBorder),
                      ),
                      child: Text(t,
                          style: TextStyle(color: selected ? color : AdminColors.textTertiary,
                              fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpace.xl),

            // Generate button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _generating ? null : _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: _generating
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: AdminColors.onAccent))
                    : Icon(_mode == 'qr' ? Icons.qr_code_rounded : Icons.receipt_long_rounded, color: AdminColors.onAccent),
                label: Text(_generating ? 'Saving code…' : (_mode == 'qr' ? 'Generate QR Code' : 'Generate Receipt'),
                    style: const TextStyle(color: AdminColors.onAccent, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 28),

            if (_generateFailed) ...[
              Container(
                padding: const EdgeInsets.all(AppSpace.md),
                decoration: BoxDecoration(
                  color: AdminColors.danger.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AdminColors.danger.withValues(alpha: 0.5)),
                ),
                child: Row(children: [
                  const Icon(Icons.wifi_off_rounded, color: AdminColors.danger),
                  const SizedBox(width: AppSpace.sm),
                  const Expanded(child: Text(
                    "Couldn't save the code, so it was not shown. Check the connection and try again.",
                    style: TextStyle(color: AdminColors.textPrimary, fontSize: 13))),
                  TextButton(onPressed: _generate, child: const Text('Retry')),
                ]),
              ),
              const SizedBox(height: AppSpace.md),
            ],

            // Output
            if (_currentToken != null)
              _mode == 'qr' ? _buildQRDisplay() : _buildReceiptDisplay()
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.all(AppSpace.xxl),
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorder)),
                  child: Column(children: [
                    Icon(_mode == 'qr' ? Icons.qr_code_rounded : Icons.receipt_long_rounded,
                        color: AdminColors.textTertiary, size: 64),
                    const SizedBox(height: AppSpace.sm),
                    Text(_mode == 'qr' ? 'No QR generated yet' : 'No receipt generated yet',
                        style: const TextStyle(color: AdminColors.textTertiary, fontSize: 14)),
                    const Text('Tap the button above to generate',
                        style: TextStyle(color: AdminColors.textTertiary, fontSize: 12)),
                  ]),
                ),
              ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _modeCard(String mode, IconData icon, String title, String subtitle) {
    final selected = _mode == mode;
    return Tap(
      label: '$title: $subtitle',
      selected: selected,
      onTap: () => setState(() {
        _mode = mode;
        _currentToken = null;
        _expiresAt = null;
      }),
      child: AnimatedContainer(
        duration: AppMotion.medium,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kGreen.withValues(alpha: 0.1) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? kGreen : kBorder, width: selected ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? kGreen : AdminColors.textTertiary, size: 28),
          const SizedBox(height: AppSpace.xs),
          Text(title, style: TextStyle(color: selected ? kGreen : AdminColors.textSecondary,
              fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AdminColors.textTertiary, fontSize: 11),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _qrBox() => Container(
        padding: const EdgeInsets.all(AppSpace.sm),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
        child: QrImageView(data: _qrData, version: QrVersions.auto, size: 180,
            semanticsLabel: 'QR code for $_selectedType waste'),
      );

  Widget _buildQRDisplay() {
    return Center(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(AppSpace.xl),
          decoration: BoxDecoration(
            color: _isExpired ? Colors.grey.shade800 : kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _isExpired ? kBorder : kGreen.withValues(alpha: 0.4)),
            boxShadow: [BoxShadow(color: (_isExpired ? Colors.grey : kGreen).withValues(alpha: 0.2),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            if (_isExpired)
              const Padding(
                padding: EdgeInsets.only(bottom: AppSpace.sm),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.timer_off_rounded, color: AdminColors.danger, size: 20),
                  SizedBox(width: 6),
                  Text('QR Expired', style: TextStyle(color: AdminColors.danger, fontWeight: FontWeight.bold)),
                ]),
              ),
            if (!_isExpired)
              _ExpiryRing(
                expiresAt: _expiresAt!,
                total: _validFor,
                onExpired: () => setState(() {}),
                child: _qrBox(),
              )
            else
              ColorFiltered(
              colorFilter: _isExpired
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.color),
              child: _qrBox(),
            ),
            const SizedBox(height: AppSpace.sm),
            Text(_selectedType, style: const TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: AppSpace.xxs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: AppSpace.xxs),
              decoration: BoxDecoration(color: kGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('Single-use · 20 min expiry',
                  style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        if (_isExpired) ...[
          const SizedBox(height: AppSpace.md),
          TextButton.icon(
            onPressed: _generate,
            icon: const Icon(Icons.refresh_rounded, color: kGreen),
            label: const Text('Generate New QR', style: TextStyle(color: kGreen, fontWeight: FontWeight.bold)),
          ),
        ],
      ]),
    );
  }

  Widget _buildReceiptDisplay() {
    final now = DateTime.now();
    final dateStr = DateFormat('MMM d, yyyy  h:mm a').format(now);
    final pointsMap = {'Biodegradable': 15, 'Recyclable': 10, 'Residual': 5};
    final points = pointsMap[_selectedType]!;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
        // Receipt header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg, horizontal: AppSpace.lg),
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [AppPalette.forestLight, AppPalette.forestDeep],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
          ),
          child: Column(children: [
            const Icon(Icons.recycling_rounded, color: Colors.white, size: 32),
            const SizedBox(height: AppSpace.xs),
            const Text('ECOReward Bin', style: TextStyle(color: AdminColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
            const Text('Smart Waste Recycling System', style: TextStyle(color: AdminColors.textSecondary, fontSize: 11)),
            const SizedBox(height: AppSpace.xxs),
            Text(dateStr, style: const TextStyle(color: AdminColors.textSecondary, fontSize: 11)),
          ]),
        ),

        _dashedDivider(),

        // Receipt details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.md),
          child: Column(children: [
            _receiptRow('Waste Type', _selectedType),
            const SizedBox(height: 10),
            _receiptRow('Points to Earn', '+$points pts'),
            const SizedBox(height: 10),
            _receiptRow('Status', 'Pending Claim'),
            const SizedBox(height: 10),
            _receiptRow('Valid For', '20 min · until ${DateFormat('h:mm a').format(_expiresAt ?? now)}'),
          ]),
        ),

        _dashedDivider(),

        // QR code
        Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(children: [
            const Text('Scan QR to Claim Points',
                style: TextStyle(color: _kReceiptInk, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: kGreen.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 1)],
              ),
              child: QrImageView(
                semanticsLabel: 'Receipt QR code for $_selectedType waste',
                data: _qrData,
                version: QrVersions.auto,
                size: 160,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: AppPalette.forestDeep),
                // Dark modules: light green (2.8:1 on white) scanned poorly on cheap cameras and thermal paper.
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: AppPalette.forestDeep),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Container(
              padding: const EdgeInsets.all(AppSpace.sm),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FFF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kGreen.withValues(alpha: 0.2)),
              ),
              child: const Row(children: [
                Icon(Icons.info_outline_rounded, color: AppPalette.forest, size: 16),
                SizedBox(width: AppSpace.xs),
                Expanded(child: Text(
                  'Customer can scan this QR with the ECOReward app to claim their points. Valid for 20 minutes.',
                  style: TextStyle(color: AppPalette.forest, fontSize: 11),
                )),
              ]),
            ),
          ]),
        ),

        _dashedDivider(),

        // Footer
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xFFF9F9F9),
            borderRadius: BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
          ),
          child: const Text('Thank you for helping the environment! 🌍',
              style: TextStyle(color: _kReceiptInk, fontSize: 11), textAlign: TextAlign.center),
        ),
      ]),
    );
  }

  Widget _receiptRow(String label, String value) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _kReceiptInk, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppPalette.forestDeep)),
        ],
      );

  Widget _dashedDivider() => Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
        child: Row(
          children: List.generate(28, (_) => Expanded(
            child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 1, color: _kReceiptRule),
          )),
        ),
      );
}

// Countdown ring: a progress ring around the QR that drains over the 20 minutes,
// green → orange (under 5 min) → red (under 1 min), with a large mm:ss readout.
class _ExpiryRing extends StatefulWidget {
  final DateTime expiresAt;
  final Duration total;
  final VoidCallback onExpired;
  final Widget child;
  const _ExpiryRing({required this.expiresAt, required this.total, required this.onExpired, required this.child});
  @override
  State<_ExpiryRing> createState() => _ExpiryRingState();
}

class _ExpiryRingState extends State<_ExpiryRing> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) {
      _timer?.cancel();
      widget.onExpired();
      return;
    }
    setState(() => _remaining = remaining);
  }

  @override
  Widget build(BuildContext context) {
    final secs = _remaining.inSeconds;
    final color = secs < 60 ? AdminColors.danger : (secs < 300 ? AdminColors.orange : kGreen);
    final fraction = (_remaining.inMilliseconds / widget.total.inMilliseconds).clamp(0.0, 1.0);
    final mm = _remaining.inMinutes.toString().padLeft(2, '0');
    final ss = (secs % 60).toString().padLeft(2, '0');
    return Column(mainAxisSize: MainAxisSize.min, children: [
      CustomPaint(
        foregroundPainter: _RingPainter(fraction: fraction, color: color),
        child: Padding(padding: const EdgeInsets.all(AppSpace.md), child: widget.child),
      ),
      const SizedBox(height: AppSpace.sm),
      Semantics(
        label: 'Expires in ${_remaining.inMinutes} minutes ${secs % 60} seconds',
        excludeSemantics: true,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.timer_rounded, color: color, size: 22),
          const SizedBox(width: AppSpace.xs - 2),
          Text('$mm:$ss', style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 28,
              fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(width: AppSpace.xs),
          const Text('left', style: TextStyle(color: AdminColors.textSecondary, fontSize: 13)),
        ]),
      ),
    ]);
  }
}

class _RingPainter extends CustomPainter {
  final double fraction;
  final Color color;
  const _RingPainter({required this.fraction, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 6.0;
    final rect = RRect.fromRectAndRadius(
        (Offset.zero & size).deflate(stroke / 2), const Radius.circular(AppRadius.xl));
    final track = Paint()
      ..color = AdminColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawRRect(rect, track);

    // Remaining time drawn clockwise from the top centre along the rounded square.
    final path = Path()..addRRect(rect);
    final metric = path.computeMetrics().first;
    final len = metric.length;
    // addRRect starts at the top-left corner's end; shift so the bar starts top-centre.
    final start = (rect.width / 2 - rect.tlRadiusX).clamp(0.0, len);
    final sweep = len * fraction;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final end = start + sweep;
    canvas.drawPath(metric.extractPath(start, math.min(end, len)), paint);
    if (end > len) canvas.drawPath(metric.extractPath(0, end - len), paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.fraction != fraction || old.color != color;
}

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';

const kGreen = Color(0xFF4CAF50);
const kDark = Color(0xFF0D1117);
const kCard = Color(0xFF161B22);
const kBorder = Color(0xFF30363D);

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

  bool get _isExpired => _expiresAt != null && DateTime.now().isAfter(_expiresAt!);

  void _generate() {
    final token = const Uuid().v4();
    final expiry = DateTime.now().add(const Duration(minutes: 20));
    setState(() {
      _currentToken = token;
      _expiresAt = expiry;
    });
    FirebaseService.createQRToken(token, _selectedType, expiry);
  }

  String get _qrData => 'ECOBIN:$_selectedType:$_currentToken';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDark,
      appBar: AppBar(
        backgroundColor: kCard,
        automaticallyImplyLeading: false,
        title: const Text('Generate for Customer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // Mode selector
            const Text('Customer Preference', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _modeCard('qr', Icons.qr_code_rounded, 'QR Code', 'Customer scans with phone')),
              const SizedBox(width: 12),
              Expanded(child: _modeCard('receipt', Icons.receipt_long_rounded, 'Paper Receipt', 'No phone / no internet')),
            ]),
            const SizedBox(height: 24),

            // Waste type
            const Text('Waste Type', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 10),
            Row(
              children: _types.map((t) {
                final selected = _selectedType == t;
                final colors = {
                  'Biodegradable': const Color(0xFF8BC34A),
                  'Recyclable': const Color(0xFF29B6F6),
                  'Residual': const Color(0xFFEF5350),
                };
                final color = colors[t]!;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() {
                      _selectedType = t;
                      _currentToken = null;
                      _expiresAt = null;
                    }),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: selected ? color.withOpacity(0.15) : kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? color : kBorder),
                      ),
                      child: Text(t,
                          style: TextStyle(color: selected ? color : Colors.white38,
                              fontSize: 11, fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 24),

            // Generate button
            SizedBox(
              width: double.infinity, height: 52,
              child: ElevatedButton.icon(
                onPressed: _generate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
                icon: Icon(_mode == 'qr' ? Icons.qr_code_rounded : Icons.receipt_long_rounded, color: Colors.white),
                label: Text(_mode == 'qr' ? 'Generate QR Code' : 'Generate Receipt',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 28),

            // Output
            if (_currentToken != null)
              _mode == 'qr' ? _buildQRDisplay() : _buildReceiptDisplay()
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(color: kCard, borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: kBorder)),
                  child: Column(children: [
                    Icon(_mode == 'qr' ? Icons.qr_code_rounded : Icons.receipt_long_rounded,
                        color: Colors.white24, size: 64),
                    const SizedBox(height: 12),
                    Text(_mode == 'qr' ? 'No QR generated yet' : 'No receipt generated yet',
                        style: const TextStyle(color: Colors.white38, fontSize: 14)),
                    const Text('Tap the button above to generate',
                        style: TextStyle(color: Colors.white24, fontSize: 12)),
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
    return GestureDetector(
      onTap: () => setState(() {
        _mode = mode;
        _currentToken = null;
        _expiresAt = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kGreen.withOpacity(0.1) : kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: selected ? kGreen : kBorder, width: selected ? 1.5 : 1),
        ),
        child: Column(children: [
          Icon(icon, color: selected ? kGreen : Colors.white38, size: 28),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(color: selected ? kGreen : Colors.white54,
              fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: Colors.white24, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _buildQRDisplay() {
    return Center(
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _isExpired ? Colors.grey.shade800 : kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: _isExpired ? kBorder : kGreen.withOpacity(0.4)),
            boxShadow: [BoxShadow(color: (_isExpired ? Colors.grey : kGreen).withOpacity(0.2),
                blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Column(children: [
            if (_isExpired)
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.timer_off_rounded, color: Colors.red, size: 20),
                  SizedBox(width: 6),
                  Text('QR Expired', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ]),
              )
            else
              _ExpiryTimer(expiresAt: _expiresAt!, onExpired: () => setState(() {})),
            const SizedBox(height: 12),
            ColorFiltered(
              colorFilter: _isExpired
                  ? const ColorFilter.matrix([
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ])
                  : const ColorFilter.mode(Colors.transparent, BlendMode.color),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: QrImageView(data: _qrData, version: QrVersions.auto, size: 180),
              ),
            ),
            const SizedBox(height: 12),
            Text(_selectedType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: kGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
              child: const Text('Single-use · 20 min expiry',
                  style: TextStyle(color: kGreen, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ]),
        ),
        if (_isExpired) ...[
          const SizedBox(height: 16),
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
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: Column(children: [
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
            const Text('Smart Waste Recycling System', style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 4),
            Text(dateStr, style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ),

        _dashedDivider(),

        // Receipt details
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(children: [
            _receiptRow('Waste Type', _selectedType),
            const SizedBox(height: 10),
            _receiptRow('Points to Earn', '+$points pts'),
            const SizedBox(height: 10),
            _receiptRow('Status', 'Pending Claim'),
            const SizedBox(height: 10),
            _receiptRow('Valid For', '20 minutes'),
          ]),
        ),

        _dashedDivider(),

        // QR code
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            const Text('Scan QR to Claim Points',
                style: TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: kGreen.withOpacity(0.2), blurRadius: 12, spreadRadius: 1)],
              ),
              child: QrImageView(
                data: _qrData,
                version: QrVersions.auto,
                size: 160,
                eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Color(0xFF1B5E20)),
                dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Color(0xFF4CAF50)),
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
                Icon(Icons.info_outline_rounded, color: Color(0xFF2E7D32), size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                  'Customer can scan this QR with the ECOReward app to claim their points. Valid for 20 minutes.',
                  style: TextStyle(color: Color(0xFF2E7D32), fontSize: 11),
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
              style: TextStyle(color: Colors.grey, fontSize: 11), textAlign: TextAlign.center),
        ),
      ]),
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
          children: List.generate(28, (_) => Expanded(
            child: Container(margin: const EdgeInsets.symmetric(horizontal: 2), height: 1, color: Colors.grey.shade200),
          )),
        ),
      );
}

// Countdown timer
class _ExpiryTimer extends StatefulWidget {
  final DateTime expiresAt;
  final VoidCallback onExpired;
  const _ExpiryTimer({required this.expiresAt, required this.onExpired});
  @override
  State<_ExpiryTimer> createState() => _ExpiryTimerState();
}

class _ExpiryTimerState extends State<_ExpiryTimer> {
  late Duration _remaining;

  @override
  void initState() { super.initState(); _tick(); }

  void _tick() {
    if (!mounted) return;
    final remaining = widget.expiresAt.difference(DateTime.now());
    if (remaining.isNegative) { widget.onExpired(); return; }
    setState(() => _remaining = remaining);
    Future.delayed(const Duration(seconds: 1), _tick);
  }

  @override
  Widget build(BuildContext context) {
    final mins = _remaining.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = _remaining.inSeconds.remainder(60).toString().padLeft(2, '0');
    final isLow = _remaining.inSeconds < 60;
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(Icons.timer_rounded, color: isLow ? Colors.red : kGreen, size: 16),
      const SizedBox(width: 4),
      Text('Expires in $mins:$secs',
          style: TextStyle(color: isLow ? Colors.red : kGreen, fontWeight: FontWeight.bold, fontSize: 13)),
    ]);
  }
}

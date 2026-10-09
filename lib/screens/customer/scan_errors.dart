// What can go wrong with a bin scan, the words the customer sees, and the dialog that
// shows them. Kept apart from the camera screen so the rules can be tested on their own.

import 'package:flutter/material.dart';
import '../../services/firebase_service.dart' show QRValidationResult;
import '../../widgets/ui.dart';

/// The waste types a bin code can carry (`ECOBIN:<Type>:<uuid>`).
const kBinWasteTypes = ['Biodegradable', 'Recyclable', 'Residual'];

enum ScanError {
  notOurs('Not an ECOReward code',
      "This QR code isn't from an ECOReward bin. Scan the code shown on the bin's screen."),
  badType('Code not recognised',
      "We couldn't read the waste type from this code. Scan the bin's code again, or ask staff for a new one."),
  expired('Code expired',
      'Bin codes work for 20 minutes. Your next disposal at the bin gives you a new code, or staff can make one for you.',
      warning: true, icon: Icons.timer_off_rounded),
  alreadyClaimed('Already claimed',
      'Each bin code can be claimed once, and this one has been. Your next disposal will give you a new code.',
      warning: true, icon: Icons.check_circle_outline_rounded),
  notFound('Code not found',
      "We couldn't find this code. Make sure you're scanning the code on the bin's screen right now."),
  offline("Couldn't reach ECOReward",
      'We could not finish this scan. Check your internet connection and scan the code again.',
      icon: Icons.wifi_off_rounded);

  const ScanError(this.title, this.message, {this.warning = false, this.icon = Icons.error_rounded});

  final String title;
  final String message;
  /// Amber "nothing is wrong with you" styling (expired / already claimed) instead of red.
  final bool warning;
  final IconData icon;
}

/// A bin code read from the camera: either an [error], or the [wasteType] and [token].
typedef BinCode = ({ScanError? error, String wasteType, String token});

/// Reads `ECOBIN:<Type>:<token>` exactly as the scanner always has: the token is the third
/// colon-separated part (a UUID has no colons; anything after a further colon is ignored).
BinCode parseBinCode(String raw) {
  final parts = raw.split(':').take(3).toList();
  if (parts.length < 3 || parts[0] != 'ECOBIN') return (error: ScanError.notOurs, wasteType: '', token: '');
  final wasteType = parts[1];
  final token = parts[2];
  if (!kBinWasteTypes.contains(wasteType)) return (error: ScanError.badType, wasteType: wasteType, token: token);
  return (error: null, wasteType: wasteType, token: token);
}

/// The error for a server check, or null when the code is valid.
ScanError? scanErrorFor(QRValidationResult result) => switch (result) {
      QRValidationResult.valid => null,
      QRValidationResult.expired => ScanError.expired,
      QRValidationResult.alreadyUsed => ScanError.alreadyClaimed,
      QRValidationResult.invalid => ScanError.notFound,
    };

/// The scan error dialog: what happened, then "Scan again" or "Back to Home".
Future<void> showScanErrorDialog(BuildContext context, ScanError e,
    {required VoidCallback onScanAgain, required VoidCallback onBack}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return AlertDialog(
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: e.warning ? c.warningContainer : c.dangerContainer, shape: BoxShape.circle),
            child: Icon(e.icon, color: e.warning ? c.warning : c.danger, size: 36),
          ),
          const SizedBox(height: AppSpace.md - 2),
          Text(e.title, style: ctx.text.titleLarge, textAlign: TextAlign.center),
          const SizedBox(height: AppSpace.xs - 2),
          Text(e.message, style: ctx.text.bodyMedium!.copyWith(color: c.textSecondary), textAlign: TextAlign.center),
        ]),
        actions: [
          Column(mainAxisSize: MainAxisSize.min, children: [
            AppButton(
              label: 'Scan again',
              icon: Icons.qr_code_scanner_rounded,
              height: 48,
              onPressed: () {
                Navigator.pop(ctx);
                onScanAgain();
              },
            ),
            const SizedBox(height: AppSpace.xs),
            AppButton.secondary(
              label: 'Back to Home',
              height: 48,
              onPressed: () {
                Navigator.pop(ctx);
                onBack();
              },
            ),
          ]),
        ],
      );
    },
  );
}

// What can go wrong with a bin scan, the words the customer sees, and the dialog that
// shows them. Kept apart from the camera screen so the rules can be tested on their own.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseException;
import '../../services/firebase_service.dart' show QRValidationResult;
import '../../widgets/ui.dart';

/// How long "Verifying your code…" may take before the scan is reported as a connection problem.
/// The claim is one transaction, so a late success is still safe: scanning again then says
/// "Points already added".
const kScanClaimTimeout = Duration(seconds: 15);

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
  claimedByYou('Points already added',
      'You claimed this code already, so its points are already in your balance. You can see the scan in Scan History.',
      warning: true, icon: Icons.check_circle_rounded),
  // The rules check expiry by server time, so a phone whose clock is behind can see a code as still valid.
  rejected('Code not accepted',
      'ECOReward did not accept this code. It has most likely just expired. Scan the code on the bin again, '
          'or ask staff for a new one.',
      warning: true, icon: Icons.block_rounded),
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
      QRValidationResult.claimedByYou => ScanError.claimedByYou,
      QRValidationResult.invalid => ScanError.notFound,
    };

/// A failed claim: a server refusal (rules) is not a connection problem; anything else is.
ScanError scanErrorForException(Object e) =>
    e is FirebaseException && e.code == 'permission-denied' ? ScanError.rejected : ScanError.offline;

/// The scan error dialog: what happened, then "Scan again" or "Back to Home".
/// Closing it any other way (tapping outside, system back) also scans again, so the camera
/// is never left stopped behind a closed dialog.
Future<void> showScanErrorDialog(BuildContext context, ScanError e,
    {required VoidCallback onScanAgain, required VoidCallback onBack}) async {
  final c = context.colors;
  final scanAgain = await showAppDialog(context,
      icon: e.icon,
      iconColor: e.warning ? c.warning : c.danger,
      iconBackground: e.warning ? c.warningContainer : c.dangerContainer,
      title: e.title,
      message: e.message,
      confirmLabel: 'Scan again',
      confirmIcon: Icons.qr_code_scanner_rounded,
      cancelLabel: 'Back to Home');
  if (scanAgain == false) {
    onBack();
  } else {
    onScanAgain();
  }
}

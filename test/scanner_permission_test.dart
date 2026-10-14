// Audit I: mobile_scanner 5.2.3 reports a denied camera through controller.value.error, not by
// throwing from start(), so the screen must read that state, and Retry must get a fresh controller.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
// The platform start() types are not exported; the fake camera needs them.
// ignore: implementation_imports
import 'package:mobile_scanner/src/mobile_scanner_view_attributes.dart';
// ignore: implementation_imports
import 'package:mobile_scanner/src/objects/start_options.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/screens/customer/qr_scanner_screen.dart';

class _FakeCamera extends MobileScannerPlatform {
  MobileScannerErrorCode? failWith;
  int starts = 0;
  _FakeCamera(this.failWith);

  @override
  Future<MobileScannerViewAttributes> start(StartOptions startOptions) async {
    starts++;
    if (failWith != null) throw MobileScannerException(errorCode: failWith!);
    return const MobileScannerViewAttributes(currentTorchMode: TorchState.off, numberOfCameras: 1, size: Size(640, 480));
  }

  @override
  Stream<BarcodeCapture?> get barcodesStream => const Stream.empty();
  @override
  Stream<TorchState> get torchStateStream => const Stream.empty();
  @override
  Stream<double> get zoomScaleStateStream => const Stream.empty();
  @override
  Widget buildCameraView() => const ColoredBox(color: Colors.black);
  @override
  Future<void> stop() async {}
  @override
  Future<void> updateScanWindow(Rect? window) async {}
  @override
  Future<void> dispose() async {}
}

Future<void> _open(WidgetTester tester) async {
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: const QRScannerScreen(userId: 'u', username: 'U')));
  await tester.pump();
  await tester.pump();
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 5));
}

void main() {
  testWidgets('a denied camera shows the permission screen, and Retry asks again', (tester) async {
    final camera = _FakeCamera(MobileScannerErrorCode.permissionDenied);
    MobileScannerPlatform.instance = camera;
    await _open(tester);
    expect(find.text('Camera Permission Required'), findsOneWidget);
    expect(camera.starts, 1, reason: 'the camera is started once, not twice');

    camera.failWith = null;   // the user allowed it in settings
    await tester.tap(find.text('Retry Camera Access'));
    await tester.pump();
    await tester.pump();
    expect(camera.starts, 2);
    expect(find.text('Camera Permission Required'), findsNothing);
    await _close(tester);
  });

  testWidgets('any other camera failure is not reported as a permission problem', (tester) async {
    MobileScannerPlatform.instance = _FakeCamera(MobileScannerErrorCode.genericError);
    await _open(tester);
    expect(find.text('Camera Permission Required'), findsNothing);
    expect(find.text('Camera unavailable'), findsOneWidget);
    await _close(tester);
  });
}

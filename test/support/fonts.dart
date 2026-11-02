// Real font metrics for widget tests: the app's bundled fonts plus Roboto and MaterialIcons from the
// Flutter SDK, so text widths match a phone (the test font's square glyphs overflow where a device does not).
import 'dart:io';
import 'package:flutter/services.dart';

/// The app's own bundled fonts (DM Sans body, Fraunces headings): measure with what ships.
Future<void> loadAppFonts() async {
  Future<ByteData> read(String f) async => ByteData.view(File('assets/fonts/$f').readAsBytesSync().buffer);
  final body = FontLoader('DMSans');
  for (final w in [400, 500, 600, 700]) { body.addFont(read('DMSans-$w.ttf')); }
  await body.load();
  final display = FontLoader('Fraunces');
  for (final w in [600, 700, 800]) { display.addFont(read('Fraunces-$w.ttf')); }
  await display.load();
}

Future<void> loadRealFonts() async {
  // flutter_tester lives in <flutter>/bin/cache/artifacts/engine/<platform>/.
  final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
  final dir = Directory('${artifacts.path}${Platform.pathSeparator}material_fonts');
  if (!dir.existsSync()) {
    // ignore: avoid_print
    print('Roboto not found under ${dir.path}; using the test font (stricter widths).');
    return;
  }
  Future<ByteData> read(String f) async =>
      ByteData.view(File('${dir.path}${Platform.pathSeparator}$f').readAsBytesSync().buffer);
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-black.ttf']) {
    roboto.addFont(read(f));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(read('materialicons-regular.otf'))).load();
}

// Phase 1 redesign (2026-10-27): Edit profile rules and flow, every settings row does something, no emoji as icons,
// and no endless animations on Home.
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:ecoreward_bin/core/app_theme.dart';
import 'package:ecoreward_bin/core/profile_rules.dart';
import 'package:ecoreward_bin/models/models.dart';
import 'package:ecoreward_bin/screens/customer/customer_home_screen.dart';
import 'package:ecoreward_bin/screens/customer/customer_profile_screen.dart';
import 'package:ecoreward_bin/screens/customer/edit_profile_screen.dart';
import 'package:ecoreward_bin/screens/login_screen.dart';
import 'package:ecoreward_bin/screens/register_screen.dart';
import 'package:ecoreward_bin/widgets/ui.dart';

UserModel _user({Uint8List? photo}) => UserModel(
    uid: 'u1', username: 'Ana Cruz', email: 'ana@example.com', role: 'customer', points: 60, lifetimePoints: 120,
    createdAt: DateTime(2026, 9, 1), scanCount: 7, streak: 3, lastScanDate: '2026-10-26',
    badges: ['first_scan', 'scan_5', 'pts_100'], photo: photo);

Future<void> _pump(WidgetTester tester, Widget w) async {
  tester.view.physicalSize = const Size(900, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: w));
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _done(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 20));
}

/// Emoji blocks used as icons before the redesign (pictographs, dingbats, misc symbols).
final _emoji = RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true);

List<String> _renderedText(WidgetTester tester) =>
    tester.widgetList<RichText>(find.byType(RichText, skipOffstage: false)).map((r) => r.text.toPlainText()).toList();

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({'notifications_prompted': true}));

  group('username and photo rules', () {
    test('accepts ordinary names, trims the ends', () {
      for (final ok in ['Ana', 'ana_cruz', 'Ana Cruz', 'j.dela.cruz', '  Ana  ']) {
        expect(usernameError(ok), isNull, reason: ok);
      }
    });
    test('rejects short, long, odd characters and double spaces', () {
      expect(usernameError('ab'), contains('at least 3'));
      expect(usernameError('a' * 21), contains('20'));
      expect(usernameError('ana<script>'), contains('letters'));
      expect(usernameError('Ana  Cruz'), contains('single'));
    });
    test('photos above the cap are refused', () {
      expect(photoError(30 * 1024), isNull);
      expect(photoError(kMaxPhotoBytes + 1), isNotNull);
    });
  });

  group('Edit profile', () {
    testWidgets('Save stays disabled until something changes', (tester) async {
      await _pump(tester, EditProfileScreen(user: _user()));
      TextButton save() => tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save'));
      expect(save().onPressed, isNull);
      await tester.enterText(find.byType(TextFormField).first, 'Ana C');
      await tester.pump();
      expect(save().onPressed, isNotNull);
      await tester.enterText(find.byType(TextFormField).first, 'ab');   // invalid again
      await tester.pump();
      expect(save().onPressed, isNull);
      await _done(tester);
    });

    testWidgets('a chosen photo is saved with the name; nothing else is written', (tester) async {
      final photo = Uint8List.fromList(List.filled(2048, 7));
      String? savedName;
      Uint8List? savedPhoto;
      await _pump(tester, EditProfileScreen(
        user: _user(),
        pickImage: (_) async => photo,
        save: (uid, {required username, photo, removePhoto = false}) async { savedName = username; savedPhoto = photo; },
      ));
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choose from library'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Save'));
      await tester.pumpAndSettle();
      expect(savedName, 'Ana Cruz');
      expect(savedPhoto, photo);
      await _done(tester);
    });

    testWidgets('an oversized photo is refused with a message', (tester) async {
      await _pump(tester, EditProfileScreen(
        user: _user(),
        pickImage: (ImageSource _) async => Uint8List(kMaxPhotoBytes + 10),
        save: (uid, {required username, photo, removePhoto = false}) async => fail('must not save'),
      ));
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Take photo'));
      await tester.pump();
      expect(find.textContaining('too large'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Save')).onPressed, isNull);
      await _done(tester);
    });
  });

  testWidgets('Profile: every settings row opens or changes something', (tester) async {
    await _pump(tester, CustomerProfileScreen(user: _user(), logs: const [], onUpdated: () {},
        onOpenRewards: () {}, onOpenHistory: () {}));
    final rows = tester.widgetList<SettingsRow>(find.byType(SettingsRow, skipOffstage: false)).toList();
    expect(rows.length, greaterThanOrEqualTo(6));
    for (final r in rows) {
      if (r.title == 'Email') continue;   // a read-only value, shown without a chevron
      expect(r.onTap != null || r.trailing != null, isTrue, reason: '${r.title} does nothing');
    }
    await _done(tester);
  });

  testWidgets('Home and Profile draw icons, not emoji', (tester) async {
    await _pump(tester, homeTabPreview(user: _user(), myRank: 2));
    expect(_renderedText(tester), contains('Ana Cruz'), reason: 'the scan below must see real text');
    final home = _renderedText(tester).where(_emoji.hasMatch).toList();
    await _done(tester);
    await _pump(tester, CustomerProfileScreen(user: _user(), logs: const [], onUpdated: () {}));
    final profile = _renderedText(tester).where(_emoji.hasMatch).toList();
    expect(home, isEmpty, reason: 'Home');
    expect(profile, isEmpty, reason: 'Profile');
    await _done(tester);
  });

  testWidgets('Home settles: no breathing, pulsing or wiggling loops', (tester) async {
    tester.view.physicalSize = const Size(900, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light, home: homeTabPreview(user: _user())));
    // pumpAndSettle throws if an animation repeats forever.
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
    await _done(tester);
  });

  testWidgets('Sign in and Register: no emoji, and they settle (no pulsing button or drifting leaves)', (tester) async {
    for (final screen in const <Widget>[LoginScreen(), RegisterScreen()]) {
      await _pump(tester, screen);
      await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 10));
      expect(_renderedText(tester).where(_emoji.hasMatch), isEmpty, reason: '${screen.runtimeType}');
      await _done(tester);
    }
  });
}

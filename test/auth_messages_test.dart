// Pure Dart: `dart test test/auth_messages_test.dart`.
import 'package:test/test.dart';
import 'package:ecoreward_bin/core/auth_messages.dart';

void main() {
  group('login', () {
    test('wrong password and unknown e-mail give the same neutral message', () {
      const msg = 'Email or password is incorrect.';
      expect(loginErrorMessage('invalid-credential'), msg);
      expect(loginErrorMessage('user-not-found'), msg);
      expect(loginErrorMessage('wrong-password'), msg);
    });
    test('network problems are reported as such', () {
      expect(loginErrorMessage('network-request-failed'), contains('internet'));
      expect(loginErrorMessage('Exception: Could not reach Firestore after 3 attempts.'), contains('internet'));
    });
    test('rate limit and disabled account', () {
      expect(loginErrorMessage('too-many-requests'), contains('Too many'));
      expect(loginErrorMessage('user-disabled'), contains('disabled'));
    });
    test('anything else never leaks raw exception text', () {
      final msg = loginErrorMessage('PlatformException(ERROR_INTERNAL, internal stack trace...)');
      expect(msg, 'Could not sign in. Please try again.');
    });
  });

  group('register', () {
    test('known codes', () {
      expect(registerErrorMessage('email-already-in-use'), contains('already exists'));
      expect(registerErrorMessage('weak-password'), contains('stronger'));
      expect(registerErrorMessage('invalid-email'), contains('valid email'));
    });
    test('unknown errors are generic', () =>
        expect(registerErrorMessage('[cloud_firestore/permission-denied] ...'), 'Could not create your account. Please try again.'));
  });
}

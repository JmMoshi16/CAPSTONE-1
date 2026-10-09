// User-facing auth error text (audit M-17). Pure Dart; pass FirebaseAuthException.code, or
// the exception's toString() for anything else. Never shows raw exception text.

bool _has(String err, List<String> codes) => codes.any(err.contains);

bool isNetworkError(String err) =>
    _has(err, ['network-request-failed', 'network', 'unavailable', 'Could not reach Firestore']);

String loginErrorMessage(String err) {
  if (isNetworkError(err)) return 'No internet connection. Please try again.';
  if (_has(err, ['too-many-requests'])) return 'Too many attempts. Please wait a moment and try again.';
  if (_has(err, ['user-disabled'])) return 'This account has been disabled. Contact the cafe staff.';
  // Modern Firebase returns invalid-credential for both an unknown e-mail and a wrong password,
  // and naming which one was wrong would reveal whether an account exists.
  if (_has(err, ['invalid-credential', 'user-not-found', 'wrong-password', 'invalid-email'])) {
    return 'Email or password is incorrect.';
  }
  return 'Could not sign in. Please try again.';
}

String registerErrorMessage(String err) {
  if (isNetworkError(err)) return 'No internet connection. Please try again.';
  if (_has(err, ['email-already-in-use'])) return 'An account already exists for this email. Try signing in.';
  if (_has(err, ['weak-password'])) return 'Choose a stronger password (at least 6 characters).';
  if (_has(err, ['invalid-email'])) return 'Enter a valid email address.';
  if (_has(err, ['too-many-requests'])) return 'Too many attempts. Please wait a moment and try again.';
  return 'Could not create your account. Please try again.';
}

/// Shown whether or not the address has an account (no account enumeration).
const passwordResetSentMessage =
    'If an account exists for that email, we have sent a link to reset the password.';

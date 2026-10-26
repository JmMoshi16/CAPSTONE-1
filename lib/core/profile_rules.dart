// Edit profile rules, kept pure so they can be unit-tested.

/// Largest profile photo we store on the user document (the picker makes about 20-40 KB at 256 px).
const kMaxPhotoBytes = 150 * 1024;

final _allowed = RegExp(r"^[A-Za-z0-9._ ]+$");

/// Why [raw] cannot be a username, or null when it can. Spaces at the ends are trimmed first.
String? usernameError(String raw) {
  final v = raw.trim();
  if (v.length < 3) return 'Use at least 3 characters';
  if (v.length > 20) return 'Use 20 characters or fewer';
  if (!_allowed.hasMatch(v)) return 'Use letters, numbers, spaces, dots or underscores';
  if (v.contains('  ')) return 'Use single spaces';
  return null;
}

/// Why this photo cannot be saved, or null when it can.
String? photoError(int bytes) =>
    bytes > kMaxPhotoBytes ? 'That photo is too large. Choose another or take a new one.' : null;

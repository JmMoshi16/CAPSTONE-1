import 'package:intl/intl.dart';

/// The one way the app writes dates and times (and, below, counts). Screens never build month names or formats themselves.
class AppDates {
  static String day(DateTime d) => DateFormat('MMM d').format(d);                 // Jul 9
  static String dayYear(DateTime d) => DateFormat('MMM d, yyyy').format(d);       // Jul 9, 2026
  static String monthYear(DateTime d) => DateFormat('MMM yyyy').format(d);        // Jul 2026
  static String time(DateTime d) => DateFormat('h:mm a').format(d);               // 2:03 PM

  /// Detail sheets: "Thursday, Jul 9, 2026 at 2:03 PM".
  static String full(DateTime d) => "${DateFormat('EEEE, MMM d, yyyy').format(d)} at ${time(d)}";

  /// List rows: "Today, 9:05 AM", "Yesterday, 9:30 PM", "Mar 4, 8:00 AM", "Dec 31, 2025, 11:59 PM".
  static String moment(DateTime d, {DateTime? now}) {
    final rel = _relative(d, now ?? DateTime.now());
    if (rel != null) return '$rel, ${time(d)}';
    return '${_sameYear(d, now) ? day(d) : dayYear(d)}, ${time(d)}';
  }

  /// Day headers: "Today", "Yesterday", "Mon, Oct 12", "Sun, Oct 12, 2025".
  static String dayLabel(DateTime d, {DateTime? now}) =>
      _relative(d, now ?? DateTime.now()) ??
      DateFormat(_sameYear(d, now) ? 'EEE, MMM d' : 'EEE, MMM d, yyyy').format(d);

  static bool _sameYear(DateTime d, DateTime? now) => d.year == (now ?? DateTime.now()).year;

  static String? _relative(DateTime d, DateTime now) {
    final days = DateTime(now.year, now.month, now.day).difference(DateTime(d.year, d.month, d.day)).inDays;
    return days == 0 ? 'Today' : days == 1 ? 'Yesterday' : null;
  }
}

/// Counts and points everywhere in the app: digits grouped ("1,240"), the same on Home, Rewards and the
/// success screen.
String formatCount(int n) => NumberFormat('#,###').format(n);

import 'package:flutter/material.dart';

/// Admin palette (always dark). Text colours meet WCAG AA on [card] and [background].
class AdminColors {
  static const background = Color(0xFF0D1117);
  static const card = Color(0xFF161B22);
  static const cardAlt = Color(0xFF1C2330);
  static const border = Color(0xFF30363D);

  static const textPrimary = Color(0xFFE6EDF3);
  static const textSecondary = Color(0xFFADBAC7);  // 8.6:1 on card
  static const textTertiary = Color(0xFF8B949E);   // 5.7:1 on card

  static const accent = Color(0xFF00E676);
  static const accentDeep = Color(0xFF00C853);
  static const onAccent = Color(0xFF04210F);       // dark text on the bright accent (12:1)
  static const blue = Color(0xFF58A6FF);
  static const purple = Color(0xFFB388FF);
  static const orange = Color(0xFFFFAB40);
  static const danger = Color(0xFFFF7B72);
  static const gold = Color(0xFFE3B341);
}

// Older names, kept so admin screens read the same palette.
const kAdminGreen = AdminColors.accent;
const kAdminDGreen = AdminColors.accentDeep;
const kAdminBlue = AdminColors.blue;
const kAdminPurple = AdminColors.purple;
const kAdminOrange = AdminColors.orange;
const kAdminDark = AdminColors.background;
const kAdminCard = AdminColors.card;
const kAdminBorder = AdminColors.border;

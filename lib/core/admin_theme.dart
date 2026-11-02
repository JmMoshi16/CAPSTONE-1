import 'package:flutter/material.dart';
import 'tokens.dart';

/// Staff console palette: ECOReward's dark forest, denser than the customer app but the same family.
/// Forest-black surfaces, the brand mint as the accent, and the physical bins' colours for waste types.
/// Text colours meet WCAG AA on [card] and [background] (test/contrast_test.dart).
class AdminColors {
  static const background = Color(0xFF0B110E);
  static const card = Color(0xFF141B17);
  static const cardAlt = Color(0xFF1B241F);
  static const border = Color(0xFF2A352F);

  static const textPrimary = Color(0xFFE8ECE9);
  static const textSecondary = Color(0xFFA9B3AD);
  static const textTertiary = Color(0xFF8A948E);

  static const accent = AppPalette.mint;
  static const accentDeep = Color(0xFF5FB98A);
  static const onAccent = Color(0xFF0B2416);       // dark text on the mint accent
  static const blue = Color(0xFF58A6FF);
  static const purple = Color(0xFFB388FF);
  static const orange = Color(0xFFFFAB40);
  static const danger = Color(0xFFFF7B72);       // danger text/icons
  static const dangerFill = Color(0xFFDA3633);   // solid danger buttons with white text (4.6:1)
  static const gold = Color(0xFFE3B341);

  // Avatar gradients for customer initials, from the brand: forest, the recycling-bin blue, coffee and a
  // deep champagne (white letter on each).
  static const avatarGradients = [
    [AppPalette.forestLight, AppPalette.forest],
    [Color(0xFF2B6CB0), Color(0xFF1F5A94)],
    [Color(0xFF8A6448), AppPalette.coffee],
    [Color(0xFF9A7432), Color(0xFF7A5A22)],
  ];

  // Waste types wear the physical bins' colours, as in the customer app: green, blue, charcoal.
  // Residual is never red; red means an error.
  static const bio = Color(0xFF7FCB9C);
  static const rec = Color(0xFF7DB7EE);
  static const res = Color(0xFFC9C1BA);
}

/// Staff console type ramp. Denser than the customer app (a dashboard is scanned, not read), same
/// family (DM Sans, from the theme), nothing below 11 sp. Colour is set at the call site with copyWith.
class AdminType {
  static const caption = TextStyle(fontSize: 11);                                 // meta lines, chips, stat labels
  static const label = TextStyle(fontSize: 12);                                   // secondary rows, small counts
  static const body = TextStyle(fontSize: 13);                                    // list rows
  static const section = TextStyle(fontSize: 13, fontWeight: FontWeight.w600);    // section headings in sheets
  static const input = TextStyle(fontSize: 14);                                   // text fields
  static const title = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);      // row titles
  static const stat = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);       // numbers in stat cards
  static const heading = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);    // screen and sheet titles
  static const display = TextStyle(fontSize: 26, fontWeight: FontWeight.w800);    // big figures, codes to compare
}

/// The ramp's sizes, for styles built at the call site (`TextStyle(fontSize: AdminSize.body, …)`).
class AdminSize {
  static const double caption = 11, label = 12, body = 13, title = 14, stat = 15, heading = 18, display = 26;
}

// Short names the staff screens use (one place, instead of a copy in every screen).
const kGreen = AdminColors.accent;
const kDarkGreen = AdminColors.accentDeep;
const kBlue = AdminColors.blue;
const kPurple = AdminColors.purple;
const kOrange = AdminColors.orange;
const kDark = AdminColors.background;
const kCard = AdminColors.card;
const kBorder = AdminColors.border;

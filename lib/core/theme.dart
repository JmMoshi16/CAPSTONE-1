import 'package:flutter/material.dart';

// ── Brand Colors ──────────────────────────────────────────────────────────────
const kGreen      = Color(0xFF2E7D32);
const kGreenLight = Color(0xFF4CAF50);
const kGreenBg    = Color(0xFFE8F5E9);
const kGold       = Color(0xFFB8860B);
const kGoldLight  = Color(0xFFFFD700);
const kBg         = Color(0xFFF8F9FA);

// ── Waste Type Colors ─────────────────────────────────────────────────────────
const kBioColor = Color(0xFF8BC34A);
const kRecColor = Color(0xFF29B6F6);
const kResColor = Color(0xFFEF5350);

Color wasteColor(String type) {
  switch (type) {
    case 'Biodegradable': return kBioColor;
    case 'Recyclable':    return kRecColor;
    default:              return kResColor;
  }
}

IconData wasteIcon(String type) {
  switch (type) {
    case 'Biodegradable': return Icons.compost_rounded;
    case 'Recyclable':    return Icons.recycling_rounded;
    default:              return Icons.delete_outline_rounded;
  }
}

// ── Rank System ───────────────────────────────────────────────────────────────
class RankInfo {
  final String label;
  final Color color;
  final String icon;
  final String? next;
  final int nextPts;
  final int minPts;
  const RankInfo({
    required this.label, required this.color, required this.icon,
    this.next, required this.nextPts, required this.minPts,
  });
}

RankInfo getRank(int points) {
  if (points >= 500) return const RankInfo(label: 'Platinum', color: Color(0xFF00B0FF), icon: '💎', next: null,       nextPts: 500, minPts: 500);
  if (points >= 200) return const RankInfo(label: 'Gold',     color: Colors.amber,      icon: '🥇', next: 'Platinum', nextPts: 500, minPts: 200);
  if (points >= 50)  return const RankInfo(label: 'Silver',   color: Color(0xFF9E9E9E), icon: '🥈', next: 'Gold',     nextPts: 200, minPts: 50);
  return               const RankInfo(label: 'Bronze',  color: Color(0xFFCD7F32), icon: '🥉', next: 'Silver',  nextPts: 50,  minPts: 0);
}

double rankProgress(int points) {
  if (points >= 500) return 1.0;
  if (points >= 200) return (points - 200) / (500 - 200);
  if (points >= 50)  return (points - 50)  / (200 - 50);
  return points / 50;
}

// ── Shared Decorations ────────────────────────────────────────────────────────
BoxDecoration cardDecoration({Color? color, double radius = 20, bool border = false}) => BoxDecoration(
  color: color ?? Colors.white,
  borderRadius: BorderRadius.circular(radius),
  border: border ? Border.all(color: const Color(0xFFE0E0E0)) : null,
  boxShadow: const [BoxShadow(color: Color(0x0F000000), blurRadius: 12, offset: Offset(0, 4))],
);

const gradientHeader = BoxDecoration(
  gradient: LinearGradient(
    colors: [Color(0xFF43A047), Color(0xFF1B5E20)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  ),
  borderRadius: BorderRadius.only(
    bottomLeft: Radius.circular(32),
    bottomRight: Radius.circular(32),
  ),
);

// ── Level System ──────────────────────────────────────────────────────────────
class LevelInfo {
  final int level;
  final String title;
  final String emoji;
  final Color color;
  final Color bgColor;
  final int minPts;
  final int maxPts; // -1 = no cap (max level)
  const LevelInfo({
    required this.level, required this.title, required this.emoji,
    required this.color, required this.bgColor,
    required this.minPts, required this.maxPts,
  });
}

const _levels = [
  LevelInfo(level: 1, title: 'Eco Seedling', emoji: '🌱', color: Color(0xFF8BC34A), bgColor: Color(0xFFF1F8E9), minPts: 0,    maxPts: 99),
  LevelInfo(level: 2, title: 'Eco Sprout',   emoji: '🌿', color: Color(0xFF4CAF50), bgColor: Color(0xFFE8F5E9), minPts: 100,  maxPts: 249),
  LevelInfo(level: 3, title: 'Eco Grower',   emoji: '🌳', color: Color(0xFF2E7D32), bgColor: Color(0xFFE8F5E9), minPts: 250,  maxPts: 499),
  LevelInfo(level: 4, title: 'Eco Warrior',  emoji: '⚔️', color: Color(0xFF0288D1), bgColor: Color(0xFFE1F5FE), minPts: 500,  maxPts: 999),
  LevelInfo(level: 5, title: 'Eco Champion', emoji: '🏆', color: Color(0xFFB8860B), bgColor: Color(0xFFFFF8E1), minPts: 1000, maxPts: 1999),
  LevelInfo(level: 6, title: 'Eco Legend',   emoji: '💎', color: Color(0xFF7B1FA2), bgColor: Color(0xFFF3E5F5), minPts: 2000, maxPts: -1),
];

LevelInfo getLevel(int points) {
  for (int i = _levels.length - 1; i >= 0; i--) {
    if (points >= _levels[i].minPts) return _levels[i];
  }
  return _levels[0];
}

/// Progress within the current level (0.0 – 1.0)
double levelProgress(int points) {
  final lv = getLevel(points);
  if (lv.maxPts == -1) return 1.0;
  return ((points - lv.minPts) / (lv.maxPts + 1 - lv.minPts)).clamp(0.0, 1.0);
}

/// Points needed to reach the next level (0 if already at max)
int ptsToNextLevel(int points) {
  final lv = getLevel(points);
  if (lv.maxPts == -1) return 0;
  return lv.maxPts + 1 - points;
}



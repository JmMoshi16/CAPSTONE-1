import 'package:flutter/material.dart';

/// Crave by: Secret Cafe, the café whose brand the app wears. Every logo in the app is the official image
/// (tool/generate_icon.py builds the other assets from it); nothing is redrawn.
abstract final class CraveBrand {
  /// The official logo, pixel for pixel: navy line art on yellow, 1254 px square.
  static const logo = 'assets/brand/crave_logo_full.webp';

  /// The logo's own steam, cup and saucer on a yellow tile: the app icon, for places too small for lettering.
  static const mark = 'assets/icons/app_icon.png';

  static const name = 'Crave by Secret Cafe';

  /// The yellow the logo is printed on. Surfaces that hold the image use it, so the image's edges vanish.
  static const ground = Color(0xFFFDCF09);

  /// The logo's four parts as bands of its height (top, bottom), cut along the empty rows between them:
  /// steam, cup and saucer, CRAVE, BY: SECRET CAFE. Together they are the whole image, once.
  static const layers = [(0.0, 333 / 1254), (333 / 1254, 759 / 1254), (759 / 1254, 950 / 1254), (950 / 1254, 1.0)];
}

/// The official logo on its yellow, as a rounded tile. Only yellow is rounded away; the artwork keeps its margin.
class CraveLogo extends StatelessWidget {
  const CraveLogo({super.key, this.size = 132});

  final double size;

  @override
  Widget build(BuildContext context) {
    final px = (size * MediaQuery.devicePixelRatioOf(context)).round();
    return Semantics(
      image: true,
      label: CraveBrand.name,
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: CraveBrand.ground,
          borderRadius: BorderRadius.circular(size * 0.16),
          boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 32, spreadRadius: -6, offset: Offset(0, 14))],
        ),
        child: Image(
          image: ResizeImage.resizeIfNeeded(px < 1254 ? px : null, null, const AssetImage(CraveBrand.logo)),
          fit: BoxFit.contain,
          excludeFromSemantics: true,
        ),
      ),
    );
  }
}

/// The app icon (the logo's cup on yellow), for small places such as Home's header.
class CraveMark extends StatelessWidget {
  const CraveMark({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
        image: true,
        label: CraveBrand.name,
        child: Image.asset(CraveBrand.mark, width: size, height: size, excludeFromSemantics: true,
            cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round()),
      );
}

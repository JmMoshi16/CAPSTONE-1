import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/ui.dart';

/// Sign in and Register: a forest hero (the brand surface) across the top and the form on a cream sheet that
/// rises over its rounded edge. The hero's height follows the screen, not the keyboard, so nothing jumps
/// while typing; its content scales down on small phones instead of overflowing.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({super.key, required this.hero, required this.sheet, this.heroFraction = 0.42, this.onBack});

  final Widget hero;
  final Widget sheet;
  final double heroFraction;
  final VoidCallback? onBack;

  static const _overlap = AppRadius.xxl;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final heroHeight = (MediaQuery.sizeOf(context).height * heroFraction).clamp(220.0, 420.0);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: c.background,
        body: LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: Stack(children: [
              Positioned(
                top: 0, left: 0, right: 0, height: heroHeight,
                child: AuroraBackground(
                  child: SafeArea(
                    bottom: false,
                    child: Stack(children: [
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, _overlap + AppSpace.sm),
                          child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: hero)),
                        ),
                      ),
                      if (onBack != null)
                        Positioned(
                          top: AppSpace.xxs, left: AppSpace.xxs,
                          child: IconButton(
                            tooltip: 'Back',
                            onPressed: onBack,
                            icon: Icon(Icons.arrow_back_rounded, color: c.onHero),
                          ),
                        ),
                    ]),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(top: heroHeight - _overlap),
                child: Container(
                  width: double.infinity,
                  constraints: BoxConstraints(minHeight: (box.maxHeight - heroHeight + _overlap).clamp(0.0, double.infinity)),
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(_overlap)),
                    boxShadow: AppShadows.of(context, AppShadows.e3),
                  ),
                  padding: EdgeInsets.fromLTRB(
                      AppSpace.xl, AppSpace.xl, AppSpace.xl, AppSpace.xxl + MediaQuery.paddingOf(context).bottom),
                  child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 480), child: sheet)),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// The brand symbol on a cream medallion, for the forest hero (the animation's colours are drawn for cream).
class BrandMedallion extends StatelessWidget {
  const BrandMedallion({super.key, required this.child, this.size = 120});

  final Widget child;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          color: AppPalette.cream,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 40, spreadRadius: -6, offset: Offset(0, 18))],
        ),
        child: Center(child: child),
      );
}

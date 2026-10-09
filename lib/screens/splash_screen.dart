// Launch screen: the app icon, name and tagline, completely still. It shows only while the
// saved sign-in is checked (no fixed wait), on the same cream as Android's launch window,
// so opening the app goes straight from the phone's launch screen to Login or Home.

import 'package:flutter/material.dart';

import '../core/tokens.dart';

class BrandSplash extends StatelessWidget {
  const BrandSplash({
    super.key,
    this.appName = 'ECOReward Bin',
    this.tagline = 'From coffee to a greener future',
  });

  final String appName;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final icon = (MediaQuery.sizeOf(context).shortestSide * .30).clamp(96.0, 140.0);
    return Scaffold(
      backgroundColor: AppPalette.cream,
      body: Center(
        child: Semantics(
          label: '$appName. Signing you in',
          excludeSemantics: true,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/icons/app_icon.png', width: icon, height: icon),
            const SizedBox(height: AppSpace.lg),
            Text(appName,
                style: const TextStyle(
                  fontFamily: AppType.displayFamily,
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: .2,
                  color: AppPalette.forest,
                )),
            if (tagline != null) ...[
              const SizedBox(height: 6),
              Text(tagline!,
                  style: TextStyle(fontSize: 13.5, letterSpacing: .2, color: AppPalette.coffee.withValues(alpha: .8))),
            ],
          ]),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../core/tokens.dart';

/// The one back button: an arrow with a 48 dp target, announced as "Back".
/// [onImage] draws it on a dark disc so it reads over a camera image or photo.
class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.onPressed, this.onImage = false});

  /// Defaults to closing the current page.
  final VoidCallback? onPressed;
  final bool onImage;

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Back',
        onPressed: onPressed ?? () => Navigator.maybePop(context),
        style: onImage ? IconButton.styleFrom(backgroundColor: Colors.black54) : null,
        icon: Icon(Icons.arrow_back_rounded, color: onImage ? Colors.white : context.colors.textPrimary),
      );
}

/// The page header for pushed pages: a large serif title that collapses into a pinned bar that still names
/// the page. Content that belongs under the title (summary chips, a rank pill) goes in the next sliver.
class AppSliverHeader extends StatelessWidget {
  const AppSliverHeader({super.key, required this.title, this.actions, this.showBack = true, this.onBack});

  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SliverAppBar.large(
      pinned: true,
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      leading: showBack ? AppBackButton(onPressed: onBack) : null,
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: actions,
    );
  }
}

/// The same header for a page that does not scroll under it, e.g. a form.
class AppHeaderBar extends StatelessWidget implements PreferredSizeWidget {
  const AppHeaderBar({super.key, required this.title, this.actions, this.onBack});

  final String title;
  final List<Widget>? actions;
  final VoidCallback? onBack;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) => AppBar(
        backgroundColor: context.colors.background,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        leading: AppBackButton(onPressed: onBack),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: actions,
      );
}

/// The flexible space of a forest header (Rewards, Activity): the hero content, plus the page name fading into
/// the pinned bar over the last third of the collapse, so a collapsed header still says which page this is.
class HeroHeaderSpace extends StatelessWidget {
  const HeroHeaderSpace({super.key, required this.title, required this.background});

  final String title;
  final Widget background;

  @override
  Widget build(BuildContext context) {
    final settings = context.dependOnInheritedWidgetOfExactType<FlexibleSpaceBarSettings>();
    final range = settings == null ? 0.0 : settings.maxExtent - settings.minExtent;
    final collapsed = range <= 0 ? 0.0 : ((settings!.maxExtent - settings.currentExtent) / range).clamp(0.0, 1.0);
    return Stack(fit: StackFit.expand, children: [
      FlexibleSpaceBar(background: background),
      Positioned(
        top: MediaQuery.paddingOf(context).top,
        left: AppSpace.lg,
        right: AppSpace.lg,
        height: kToolbarHeight,
        child: IgnorePointer(
          child: Opacity(
            key: const ValueKey('bar-title'),
            opacity: ((collapsed - 0.66) / 0.34).clamp(0.0, 1.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge!.copyWith(color: AppPalette.cream)),
            ),
          ),
        ),
      ),
    ]);
  }
}

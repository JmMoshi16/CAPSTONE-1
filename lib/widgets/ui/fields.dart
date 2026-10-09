import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/haptics.dart';
import '../../core/tokens.dart';

/// Text field that lifts 2 dp and glows softly in the brand colour while focused.
class AppTextField extends StatefulWidget {
  const AppTextField({
    super.key,
    required this.controller,
    this.hint,
    this.label,
    this.icon,
    this.keyboardType,
    this.obscure = false,
    this.suffix,
    this.validator,
    this.onChanged,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String? hint;
  final String? label;
  final IconData? icon;
  final TextInputType? keyboardType;
  final bool obscure;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduced = AppMotion.reduced(context);
    return AnimatedContainer(
      duration: AppMotion.of(context, AppMotion.medium),
      curve: AppMotion.standard,
      transform: Matrix4.translationValues(0, _focused && !reduced ? -2 : 0, 0),
      decoration: BoxDecoration(
        borderRadius: AppRadius.all(AppRadius.md + 2),
        boxShadow: _focused && !c.isDark ? AppShadows.glow(c.primary, strength: 0.45) : AppShadows.none,
      ),
      child: TextFormField(
        controller: widget.controller,
        focusNode: _focus,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscure,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        onFieldSubmitted: widget.onSubmitted,
        onChanged: widget.onChanged,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: widget.hint,
          labelText: widget.label,
          prefixIcon: widget.icon == null
              ? null
              : AnimatedSwitcher(
                  duration: AppMotion.of(context, AppMotion.fast),
                  child: Icon(widget.icon, key: ValueKey(_focused), size: 20,
                      color: _focused ? c.primary : c.textTertiary),
                ),
          suffixIcon: widget.suffix,
        ),
        validator: widget.validator,
      ),
    );
  }
}

/// Wraps content that should shake (e.g. a form after a failed sign-in).
/// Call `key.currentState!.shake()`; with reduced motion it only buzzes.
class Shake extends StatefulWidget {
  const Shake({super.key, required this.child});
  final Widget child;
  @override
  State<Shake> createState() => ShakeState();
}

class ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: AppMotion.slow);

  void shake({bool haptic = true}) {
    if (haptic) AppHaptics.error();
    if (!AppMotion.reduced(context)) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        child: widget.child,
        // Three damped swings, about 10 dp at the start.
        builder: (_, child) => Transform.translate(
          offset: Offset(math.sin(_c.value * math.pi * 6) * 10 * (1 - _c.value), 0),
          child: child,
        ),
      );
}

/// Display-only password strength (sign-up still requires only 6+ characters).
class PasswordStrengthMeter extends StatelessWidget {
  const PasswordStrengthMeter({super.key, required this.password});
  final String password;

  /// 0-4: length >= 8, mixed case, a digit, a symbol.
  static int score(String p) {
    if (p.isEmpty) return 0;
    var s = 0;
    if (p.length >= 8) s++;
    if (RegExp(r'[a-z]').hasMatch(p) && RegExp(r'[A-Z]').hasMatch(p)) s++;
    if (RegExp(r'\d').hasMatch(p)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(p)) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = score(password);
    final (label, color) = switch (s) {
      0 || 1 => ('Weak', c.danger),
      2 => ('Fair', c.warning),
      3 => ('Good', c.info),
      _ => ('Strong', c.success),
    };
    if (password.isEmpty) return const SizedBox(height: AppSpace.xs);
    return Semantics(
      label: 'Password strength: $label',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.xs),
        child: Row(children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: AppMotion.of(context, AppMotion.medium),
                height: 4,
                decoration: BoxDecoration(
                  color: i < math.max(s, 1) ? color : c.surfaceAlt,
                  borderRadius: AppRadius.all(2),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: AppSpace.xxs),
          ],
          const SizedBox(width: AppSpace.sm),
          SizedBox(
            width: 52,
            child: Text(label, style: context.text.labelSmall!.copyWith(color: color, fontWeight: FontWeight.w700)),
          ),
        ]),
      ),
    );
  }
}

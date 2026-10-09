import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_messages.dart';
import '../services/firebase_service.dart';
import '../widgets/ui.dart';
import 'customer/customer_home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _sendingReset = false;
  final _shakeKey = GlobalKey<ShakeState>();

  late AnimationController _heroCtrl;
  late AnimationController _formCtrl;
  late AnimationController _btnCtrl;

  late Animation<double> _heroFade;
  late Animation<double> _formFade;
  late Animation<Offset>  _formSlide;
  late Animation<double> _btnScale;
  late Animation<double> _field1Fade, _field2Fade, _btnFade;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: AppMotion.standard);

    _formCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
    _formFade  = CurvedAnimation(parent: _formCtrl, curve: AppMotion.standard);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formCtrl, curve: AppMotion.standard));

    _field1Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.3, 0.8, curve: AppMotion.standard)));
    _field2Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.5, 1.0, curve: AppMotion.standard)));
    _btnFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.65, 1.0, curve: AppMotion.standard)));


    _btnCtrl = AnimationController(vsync: this, duration: AppMotion.ambient)..repeat(reverse: true);
    _btnScale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    _heroCtrl.forward().then((_) {
      Future.delayed(AppMotion.medium, () {
        if (mounted) _formCtrl.forward();
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Reduced motion: no drifting leaves, no pulsing button, the form is simply there.
    if (AppMotion.reduced(context)) {
      _btnCtrl
        ..stop()
        ..value = 0;
      _heroCtrl.value = 1;
      _formCtrl.value = 1;
    }
  }

  @override
  void dispose() {
    _heroCtrl.dispose();
    _formCtrl.dispose();
    _btnCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      // Password trimmed exactly as at registration (audit M-17).
      final user = await FirebaseService.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
      if (mounted) {
        Navigator.pushReplacement(context, PageRouteBuilder(
          pageBuilder: (_, a, __) =>
              user.role == 'admin' ? const AdminDashboardScreen() : const CustomerHomeScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: AppMotion.slow,
        ));
      }
    } catch (e) {
      if (mounted) {
        _shakeKey.currentState?.shake(haptic: false);   // the error snackbar buzzes
        _snack(loginErrorMessage(e is FirebaseAuthException ? e.code : e.toString()), context.colors.danger);
        setState(() => _loading = false);
      }
    }
  }

  /// Danger-coloured calls are errors, success-coloured ones successes, the rest info.
  void _snack(String msg, Color color) {
    final c = context.colors;
    AppSnackbar.show(context, msg,
        kind: color == c.danger ? SnackKind.error : color == c.success ? SnackKind.success : SnackKind.info);
  }

  // Audit M-17: there was no way to recover a forgotten password.
  Future<void> _forgotPassword() async {
    final c = context.colors;
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack('Enter your email above first, then tap "Forgot password?"', c.warning);
      return;
    }
    setState(() => _sendingReset = true);
    try {
      await FirebaseService.sendPasswordReset(email);
      if (mounted) _snack(passwordResetSentMessage, c.success);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Same message for unknown addresses: do not reveal which e-mails have accounts.
      if (isNetworkError(e.code) || e.code == 'too-many-requests') {
        _snack(loginErrorMessage(e.code), c.danger);
      } else {
        _snack(passwordResetSentMessage, c.success);
      }
    } catch (_) {
      if (mounted) _snack('No internet connection. Please try again.', c.danger);
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.hero.first,
      body: Stack(children: [
        // Background gradient
        Container(
          width: double.infinity, height: double.infinity,
          decoration: heroDecoration(context),
        ),

        // Decorative circles
        Positioned(top: -60, right: -60,
          child: _circle(220, c.accent.withValues(alpha: 0.12))),
        Positioned(top: 80, right: 40,
          child: _circle(80, c.accent.withValues(alpha: 0.10))),
        Positioned(bottom: size.height * 0.35, left: -40,
          child: _circle(160, c.accent.withValues(alpha: 0.08))),

        // Floating leaves (own layer; they hold still with reduced motion)
        const Positioned.fill(child: FloatingLeaves()),

        // Header and form scroll together; on tall screens the form card fills the rest.
        // (The form used to start at a fixed 46 % of the height, hiding the header on
        // small phones and clipping with large text.) Centred at 560 dp on tablets.
        LayoutBuilder(builder: (context, box) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    FadeTransition(
                      opacity: _heroFade,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xl, AppSpace.xxl, AppSpace.xxl),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            // Logo pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: AppSpace.md - 2, vertical: AppSpace.xs),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: AppRadius.all(AppRadius.pill),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(
                                  width: 28, height: 28,
                                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                                  child: Icon(Icons.recycling_rounded, color: c.onHero, size: 16),
                                ),
                                const SizedBox(width: AppSpace.xs),
                                Text('ECOReward', style: t.titleSmall!.copyWith(color: c.onHero, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                            const SizedBox(height: AppSpace.xxl),

                            Text('Welcome\nback! 👋', style: t.displayLarge!.copyWith(color: c.onHero)),
                            const SizedBox(height: AppSpace.sm),
                            Text('Sign in and keep making\na difference for our planet 🌍',
                                style: t.bodyLarge!.copyWith(color: c.onHeroMuted)),
                            const SizedBox(height: AppSpace.xl),

                            // Stat badges
                            Wrap(spacing: AppSpace.xs, runSpacing: AppSpace.xs, children: [
                              _statBadge('♻️', 'Recycle'),
                              _statBadge('⭐', 'Earn'),
                              _statBadge('🎁', 'Redeem'),
                            ]),
                          ]),
                        ),
                      ),
                    ),
                    Expanded(
                      child: FadeTransition(
                        opacity: _formFade,
                        child: SlideTransition(
                          position: _formSlide,
                          child: Container(
                            decoration: BoxDecoration(
                              color: c.background,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl + 8)),
                            ),
                            padding: const EdgeInsets.fromLTRB(AppSpace.xl + 4, AppSpace.xxl, AppSpace.xl + 4, AppSpace.xxl),
                            child: Shake(key: _shakeKey, child: Form(
                              key: _formKey,
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              // Handle
                              Center(child: Container(width: 40, height: 4,
                                  decoration: BoxDecoration(color: c.border, borderRadius: AppRadius.all(2)))),
                              const SizedBox(height: AppSpace.xl),

                              // Title
                              Row(children: [
                                Container(width: 4, height: 22,
                                    decoration: BoxDecoration(color: c.primary, borderRadius: AppRadius.all(2))),
                                const SizedBox(width: AppSpace.sm),
                                Text('Sign In', style: t.headlineSmall),
                              ]),
                              const SizedBox(height: AppSpace.xl),

                              // Email
                              FadeTransition(opacity: _field1Fade,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _label('Email address'),
                                  const SizedBox(height: AppSpace.xs),
                                  AppTextField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [AutofillHints.email],
                                    hint: 'you@example.com',
                                    icon: Icons.alternate_email_rounded,
                                    validator: (v) => !v!.contains('@') ? 'Enter a valid email' : null,
                                  ),
                                ])),
                              const SizedBox(height: AppSpace.md),

                              // Password
                              FadeTransition(opacity: _field2Fade,
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  _label('Password'),
                                  const SizedBox(height: AppSpace.xs),
                                  AppTextField(
                                    controller: _passCtrl,
                                    obscure: _obscure,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.password],
                                    onSubmitted: (_) => _login(),
                                    hint: '••••••••',
                                    icon: Icons.lock_outline_rounded,
                                    suffix: IconButton(
                                      tooltip: _obscure ? 'Show password' : 'Hide password',
                                      onPressed: () => setState(() => _obscure = !_obscure),
                                      icon: AnimatedSwitcher(duration: AppMotion.medium,
                                        child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                            key: ValueKey(_obscure), size: 20)),
                                    ),
                                    validator: (v) => v!.trim().isEmpty ? 'Enter your password' : null,
                                  ),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _loading || _sendingReset ? null : _forgotPassword,
                                      child: Text(_sendingReset ? 'Sending link…' : 'Forgot password?'),
                                    ),
                                  ),
                                ])),
                              const SizedBox(height: AppSpace.sm),

                              // Sign in button
                              FadeTransition(opacity: _btnFade,
                                child: ScaleTransition(
                                  scale: _loading ? const AlwaysStoppedAnimation(1.0) : _btnScale,
                                  child: GlowButton(
                                    label: 'Sign In',
                                    icon: Icons.eco_rounded,
                                    trailingIcon: Icons.arrow_forward_rounded,
                                    loading: _loading,
                                    onPressed: _login,
                                  ),
                                )),
                              const SizedBox(height: AppSpace.lg),

                              // Divider
                              Row(children: [
                                const Expanded(child: Divider()),
                                Padding(padding: const EdgeInsets.symmetric(horizontal: AppSpace.md - 2),
                                  child: Text('or', style: t.bodyMedium!.copyWith(color: c.textTertiary))),
                                const Expanded(child: Divider()),
                              ]),
                              const SizedBox(height: AppSpace.lg),

                              // Register
                              AppButton.secondary(
                                label: 'Create new account',
                                icon: Icons.person_add_alt_1_rounded,
                                height: 56,
                                onPressed: () => Navigator.push(context,
                                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              ),
                              const SizedBox(height: AppSpace.xl),

                              Center(child: Text('ECOReward Bin  ·  Smart Waste Recycling', style: t.labelSmall)),
                              ]),
                            )),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        )),
      ]),
    );
  }

  Widget _circle(double d, Color color) =>
      Container(width: d, height: d, decoration: BoxDecoration(shape: BoxShape.circle, color: color));

  Widget _statBadge(String emoji, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: AppRadius.all(AppRadius.pill),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: AppSpace.xs - 2),
      Text(label, style: context.text.labelMedium!.copyWith(color: context.colors.onHero)),
    ]),
  );

  Widget _label(String text) => Text(text, style: context.text.labelMedium!.copyWith(
      color: context.colors.textSecondary, fontSize: 13));
}

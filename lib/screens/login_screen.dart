import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_messages.dart';
import '../models/models.dart';
import '../services/firebase_service.dart';
import '../widgets/eco_animations.dart';
import '../widgets/ui.dart';
import 'customer/customer_home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'auth_scaffold.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.signIn});

  /// Replaces the Firebase sign-in in widget tests; the app always leaves it null.
  @visibleForTesting
  final Future<UserModel> Function(String email, String password)? signIn;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _sendingReset = false;
  final _shakeKey = GlobalKey<ShakeState>();

  // The sheet rises over the hero once; its rows then cascade in (first visit of the session only).
  late final AnimationController _enter = AnimationController(vsync: this, duration: AppMotion.slow);
  late final Animation<double> _fade = CurvedAnimation(parent: _enter, curve: AppMotion.standard);
  late final Animation<Offset> _slide = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
      .animate(_fade);
  final _cascade = EntranceGate('login');

  @override
  void initState() {
    super.initState();
    _enter.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _enter.value = 1;
  }

  @override
  void dispose() {
    _enter.dispose();
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
      final user = await (widget.signIn ?? FirebaseService.login)(_emailCtrl.text.trim(), _passCtrl.text.trim());
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
        _snack(loginErrorMessage(e is FirebaseAuthException ? '${e.code} ${e.message}' : e.toString()), context.colors.danger);
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
    if (!isValidEmail(email)) {
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
    final c = context.colors;
    final t = context.text;
    final play = _cascade.play;
    return AuthScaffold(
      hero: Column(mainAxisSize: MainAxisSize.min, children: [
        // The brand moment: the coffee bean becomes a leaf in the cup-bin, once.
        const BrandMedallion(child: EcoBrandIntro(size: 104)),
        const SizedBox(height: AppSpace.md),
        Semantics(
          header: true,
          child: Text('ECOReward', style: t.displaySmall!.copyWith(color: AppPalette.cream, fontSize: 34)),
        ),
        const SizedBox(height: AppSpace.xxs),
        Text('From coffee to a greener future', style: t.bodyMedium!.copyWith(color: c.onHeroMuted)),
      ]),
      sheet: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: Shake(key: _shakeKey, child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                StaggeredEntrance(index: 0, play: play, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Welcome back', style: t.headlineMedium),
                    const SizedBox(height: AppSpace.xxs),
                    Text('Sign in to collect points for everything you sort at the bin.',
                        style: t.bodyMedium!.copyWith(color: c.textSecondary)),
                  ],
                )),
                const SizedBox(height: AppSpace.xl),
                StaggeredEntrance(index: 1, play: play, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _label('Email address'),
                    const SizedBox(height: AppSpace.xs),
                    AppTextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.email],
                      hint: 'you@example.com',
                      icon: Icons.alternate_email_rounded,
                      validator: (v) => isValidEmail(v!.trim()) ? null : 'Enter a valid email',
                    ),
                  ],
                )),
                const SizedBox(height: AppSpace.md),
                StaggeredEntrance(index: 2, play: play, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
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
                  ],
                )),
                const SizedBox(height: AppSpace.sm),
                StaggeredEntrance(index: 3, play: play, child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppButton(key: const ValueKey('sign-in'), label: 'Sign in', loading: _loading, onPressed: _login),
                    const SizedBox(height: AppSpace.sm),
                    AppButton.secondary(
                      label: 'Create an account',
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const RegisterScreen())),
                    ),
                  ],
                )),
              ]),
            ),
          )),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(text, style: context.text.labelMedium!.copyWith(
      color: context.colors.textSecondary, fontSize: 13));
}

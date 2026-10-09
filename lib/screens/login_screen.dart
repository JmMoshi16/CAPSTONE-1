import 'dart:math' as math;
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

  late AnimationController _heroCtrl;
  late AnimationController _formCtrl;
  late AnimationController _particleCtrl;
  late AnimationController _btnCtrl;

  late Animation<double> _heroFade;
  late Animation<double> _formFade;
  late Animation<Offset>  _formSlide;
  late Animation<double> _btnScale;
  late Animation<double> _field1Fade, _field2Fade, _btnFade;

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: AppMotion.slow * 2);
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: AppMotion.standard);

    _formCtrl = AnimationController(vsync: this, duration: AppMotion.slow * 2);
    _formFade  = CurvedAnimation(parent: _formCtrl, curve: AppMotion.standard);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formCtrl, curve: AppMotion.standard));

    _field1Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.3, 0.8, curve: AppMotion.standard)));
    _field2Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.5, 1.0, curve: AppMotion.standard)));
    _btnFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.65, 1.0, curve: AppMotion.standard)));

    _particleCtrl = AnimationController(vsync: this, duration: AppMotion.ambient * 4)..repeat();

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
      _particleCtrl.stop();
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
    _particleCtrl.dispose();
    _btnCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
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
        _snack(loginErrorMessage(e is FirebaseAuthException ? e.code : e.toString()), context.colors.danger);
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: AppSpace.xs),
        Expanded(child: Text(msg)),
      ]),
      backgroundColor: color,
      margin: const EdgeInsets.all(AppSpace.md),
    ));
  }

  // Audit M-17: there was no way to recover a forgotten password.
  Future<void> _forgotPassword() async {
    final c = context.colors;
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack('Enter your email above first, then tap "Forgot password?"', c.warning);
      return;
    }
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

        // Floating particles (own layer so the form never repaints with them)
        RepaintBoundary(
          child: AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: Size(size.width, size.height),
              painter: _LeafParticlePainter(_particleCtrl.value),
            ),
          ),
        ),

        // Hero text
        FadeTransition(
          opacity: _heroFade,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xl, AppSpace.xxl, 0),
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
                Row(children: [
                  _statBadge('♻️', 'Recycle'),
                  const SizedBox(width: AppSpace.xs),
                  _statBadge('⭐', 'Earn'),
                  const SizedBox(width: AppSpace.xs),
                  _statBadge('🎁', 'Redeem'),
                ]),
              ]),
            ),
          ),
        ),

        // Form card
        Positioned(
          top: size.height * 0.46,
          left: 0, right: 0, bottom: 0,
          child: FadeTransition(
            opacity: _formFade,
            child: SlideTransition(
              position: _formSlide,
              child: Container(
                decoration: BoxDecoration(
                  color: c.background,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl + 8)),
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(AppSpace.xl + 4, AppSpace.xxl, AppSpace.xl + 4, AppSpace.xxl),
                  child: Form(
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
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            style: t.bodyLarge,
                            decoration: const InputDecoration(
                              hintText: 'you@example.com',
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                            ),
                            validator: (v) => !v!.contains('@') ? 'Enter a valid email' : null,
                          ),
                        ])),
                      const SizedBox(height: AppSpace.md),

                      // Password
                      FadeTransition(opacity: _field2Fade,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('Password'),
                          const SizedBox(height: AppSpace.xs),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscure,
                            style: t.bodyLarge,
                            decoration: InputDecoration(
                              hintText: '••••••••',
                              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show password' : 'Hide password',
                                onPressed: () => setState(() => _obscure = !_obscure),
                                icon: AnimatedSwitcher(duration: AppMotion.medium,
                                  child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                      key: ValueKey(_obscure), size: 20)),
                              ),
                            ),
                            validator: (v) => v!.trim().isEmpty ? 'Enter your password' : null,
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text('Forgot password?'),
                            ),
                          ),
                        ])),
                      const SizedBox(height: AppSpace.sm),

                      // Sign in button
                      FadeTransition(opacity: _btnFade,
                        child: ScaleTransition(
                          scale: _loading ? const AlwaysStoppedAnimation(1.0) : _btnScale,
                          child: AppButton(
                            label: 'Sign In',
                            icon: Icons.eco_rounded,
                            trailingIcon: Icons.arrow_forward_rounded,
                            height: 56,
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
                  ),
                ),
              ),
            ),
          ),
        ),
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

// Floating leaf particle painter
class _LeafParticlePainter extends CustomPainter {
  final double progress;
  static final _rand = math.Random(42);
  static final _particles = List.generate(14, (i) => _Particle(
    x:       _rand.nextDouble(),
    speed:   0.04 + _rand.nextDouble() * 0.07,
    size:    4 + _rand.nextDouble() * 7,
    opacity: 0.06 + _rand.nextDouble() * 0.13,
    phase:   _rand.nextDouble(),
    drift:   (_rand.nextDouble() - 0.5) * 0.04,
  ));

  _LeafParticlePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _particles) {
      final t = ((p.phase + progress * p.speed * 10) % 1.0);
      final y = size.height * (1.0 - t);
      final x = size.width * (p.x + math.sin(t * math.pi * 2 + p.phase) * p.drift);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: p.opacity)
        ..style = PaintingStyle.fill;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(t * math.pi * 2);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 1.6), paint);
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_LeafParticlePainter old) => old.progress != progress;
}

class _Particle {
  final double x, speed, size, opacity, phase, drift;
  const _Particle({required this.x, required this.speed, required this.size,
      required this.opacity, required this.phase, required this.drift});
}

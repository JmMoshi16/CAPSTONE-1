import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_messages.dart';
import '../services/firebase_service.dart';
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

  static const _darkGreen   = Color(0xFF0A2E0C);
  static const _midGreen    = Color(0xFF2E7D32);
  static const _lightGreen  = Color(0xFF4CAF50);
  static const _accentGreen = Color(0xFF66BB6A);

  @override
  void initState() {
    super.initState();
    _heroCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heroFade = CurvedAnimation(parent: _heroCtrl, curve: Curves.easeOut);

    _formCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _formFade  = CurvedAnimation(parent: _formCtrl, curve: Curves.easeOut);
    _formSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _formCtrl, curve: Curves.easeOutCubic));

    _field1Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.3, 0.8, curve: Curves.easeOut)));
    _field2Fade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.5, 1.0, curve: Curves.easeOut)));
    _btnFade = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _formCtrl, curve: const Interval(0.65, 1.0, curve: Curves.easeOut)));

    _particleCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 6))..repeat();

    _btnCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat(reverse: true);
    _btnScale = Tween<double>(begin: 1.0, end: 1.02)
        .animate(CurvedAnimation(parent: _btnCtrl, curve: Curves.easeInOut));

    _heroCtrl.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _formCtrl.forward();
      });
    });
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
          transitionDuration: const Duration(milliseconds: 400),
        ));
      }
    } catch (e) {
      if (mounted) {
        _snack(loginErrorMessage(e is FirebaseAuthException ? e.code : e.toString()), Colors.red.shade700);
        setState(() => _loading = false);
      }
    }
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
      ]),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ));
  }

  // Audit M-17: there was no way to recover a forgotten password.
  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (!email.contains('@')) {
      _snack('Enter your email above first, then tap "Forgot password?"', Colors.orange.shade800);
      return;
    }
    try {
      await FirebaseService.sendPasswordReset(email);
      if (mounted) _snack(passwordResetSentMessage, const Color(0xFF2E7D32));
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Same message for unknown addresses: do not reveal which e-mails have accounts.
      if (isNetworkError(e.code) || e.code == 'too-many-requests') {
        _snack(loginErrorMessage(e.code), Colors.red.shade700);
      } else {
        _snack(passwordResetSentMessage, const Color(0xFF2E7D32));
      }
    } catch (_) {
      if (mounted) _snack('No internet connection. Please try again.', Colors.red.shade700);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _darkGreen,
      body: Stack(children: [
        // Background gradient
        Container(
          width: double.infinity, height: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A2E0C), Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF1A3A1C)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              stops: [0.0, 0.35, 0.65, 1.0],
            ),
          ),
        ),

        // Decorative circles
        Positioned(top: -60, right: -60,
          child: Container(width: 220, height: 220,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _lightGreen.withValues(alpha: 0.12)))),
        Positioned(top: 80, right: 40,
          child: Container(width: 80, height: 80,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _accentGreen.withValues(alpha: 0.10)))),
        Positioned(bottom: size.height * 0.35, left: -40,
          child: Container(width: 160, height: 160,
            decoration: BoxDecoration(shape: BoxShape.circle,
                color: _lightGreen.withValues(alpha: 0.08)))),

        // Floating particles
        AnimatedBuilder(
          animation: _particleCtrl,
          builder: (_, __) => CustomPaint(
            size: Size(size.width, size.height),
            painter: _LeafParticlePainter(_particleCtrl.value),
          ),
        ),

        // Hero text
        FadeTransition(
          opacity: _heroFade,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Logo pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 8),
                    const Text('ECOReward',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ]),
                ),
                const SizedBox(height: 32),

                const Text('Welcome\nback! 👋',
                    style: TextStyle(color: Colors.white, fontSize: 46,
                        fontWeight: FontWeight.w900, height: 1.05, letterSpacing: -1.5)),
                const SizedBox(height: 12),
                Text('Sign in and keep making\na difference for our planet 🌍',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 15, height: 1.55)),
                const SizedBox(height: 28),

                // Stat badges
                Row(children: [
                  _statBadge('♻️', 'Recycle'),
                  const SizedBox(width: 10),
                  _statBadge('⭐', 'Earn'),
                  const SizedBox(width: 10),
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
                decoration: const BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
                ),
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(28, 30, 28, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Handle
                      Center(child: Container(width: 40, height: 4,
                          decoration: BoxDecoration(color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 22),

                      // Title
                      Row(children: [
                        Container(width: 4, height: 22,
                            decoration: BoxDecoration(color: _lightGreen,
                                borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 10),
                        const Text('Sign In',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A1A1A))),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: _lightGreen.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10)),
                          child: const Text('🌱 Eco Mode',
                              style: TextStyle(fontSize: 10, color: _midGreen, fontWeight: FontWeight.bold)),
                        ),
                      ]),
                      const SizedBox(height: 24),

                      // Email
                      FadeTransition(opacity: _field1Fade,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('Email address'),
                          const SizedBox(height: 8),
                          _buildField(controller: _emailCtrl, hint: 'you@example.com',
                            icon: Icons.alternate_email_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => !v!.contains('@') ? 'Enter a valid email' : null),
                        ])),
                      const SizedBox(height: 18),

                      // Password
                      FadeTransition(opacity: _field2Fade,
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          _label('Password'),
                          const SizedBox(height: 8),
                          _buildField(controller: _passCtrl, hint: '••••••••',
                            icon: Icons.lock_outline_rounded, obscure: _obscure,
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: AnimatedSwitcher(duration: const Duration(milliseconds: 200),
                                child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                    key: ValueKey(_obscure), color: Colors.grey.shade400, size: 20)),
                            ),
                            validator: (v) => v!.trim().isEmpty ? 'Enter your password' : null),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _loading ? null : _forgotPassword,
                              child: const Text('Forgot password?',
                                  style: TextStyle(color: _midGreen, fontWeight: FontWeight.w600, fontSize: 13)),
                            ),
                          ),
                        ])),
                      const SizedBox(height: 14),

                      // Sign in button
                      FadeTransition(opacity: _btnFade,
                        child: ScaleTransition(
                          scale: _loading ? const AlwaysStoppedAnimation(1.0) : _btnScale,
                          child: SizedBox(width: double.infinity, height: 58,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF43A047)],
                                  begin: Alignment.centerLeft, end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [BoxShadow(
                                  color: _lightGreen.withValues(alpha: 0.40),
                                  blurRadius: 20, offset: const Offset(0, 8),
                                )],
                              ),
                              child: ElevatedButton(
                                onPressed: _loading ? null : _login,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: _loading
                                    ? const SizedBox(width: 24, height: 24,
                                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                    : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                        Icon(Icons.eco_rounded, size: 20),
                                        SizedBox(width: 10),
                                        Text('Sign In',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                        SizedBox(width: 10),
                                        Icon(Icons.arrow_forward_rounded, size: 18),
                                      ]),
                              ),
                            ),
                          ),
                        )),
                      const SizedBox(height: 22),

                      // Divider
                      Row(children: [
                        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.2)),
                        Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Text('or', style: TextStyle(color: Colors.grey.shade400, fontSize: 13))),
                        Expanded(child: Divider(color: Colors.grey.shade200, thickness: 1.2)),
                      ]),
                      const SizedBox(height: 22),

                      // Register
                      SizedBox(width: double.infinity, height: 56,
                        child: OutlinedButton(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(builder: (_) => const RegisterScreen())),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _midGreen,
                            side: BorderSide(color: _lightGreen.withValues(alpha: 0.45), width: 1.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            backgroundColor: _lightGreen.withValues(alpha: 0.04),
                          ),
                          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.person_add_alt_1_rounded, size: 18),
                            SizedBox(width: 8),
                            Text('Create new account',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          ]),
                        )),
                      const SizedBox(height: 24),

                      Center(child: Text('ECOReward Bin  ·  Smart Waste Recycling',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 11, letterSpacing: 0.3))),
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

  Widget _statBadge(String emoji, String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(emoji, style: const TextStyle(fontSize: 14)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
    ]),
  );

  Widget _label(String text) => Text(text,
      style: const TextStyle(color: Color(0xFF424242), fontSize: 13, fontWeight: FontWeight.w600));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscure,
    style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      prefixIcon: Icon(icon, color: _lightGreen, size: 20),
      suffixIcon: suffixIcon != null
          ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon) : null,
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _lightGreen, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    ),
    validator: validator,
  );
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

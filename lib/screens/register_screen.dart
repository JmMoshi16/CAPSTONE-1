import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_messages.dart';
import '../services/firebase_service.dart';
import '../widgets/ui.dart';
import 'customer/customer_home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _userCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  bool _obscureConfirm = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: AppMotion.slow * 2);
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: AppMotion.standard);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: AppMotion.standard));
    _animCtrl.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AppMotion.reduced(context)) _animCtrl.value = 1;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _userCtrl.dispose(); _emailCtrl.dispose();
    _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await FirebaseService.register(
        _userCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text.trim(), 'customer',
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const CustomerHomeScreen()), (_) => false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: AppSpace.xs),
            Expanded(child: Text(registerErrorMessage(e is FirebaseAuthException ? e.code : e.toString()))),
          ]),
          backgroundColor: context.colors.danger,
        ));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      body: Stack(
        children: [
          // Top green header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: size.height * 0.32,
              decoration: heroDecoration(context,
                  radius: const BorderRadius.vertical(bottom: Radius.circular(AppRadius.xxxl))),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.md, AppSpace.xl, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back + logo row
                      Row(children: [
                        Tap(
                          label: 'Back',
                          tooltip: true,
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: AppRadius.all(AppRadius.md),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: Icon(Icons.arrow_back_ios_new_rounded, color: c.onHero, size: 16),
                          ),
                        ),
                        const SizedBox(width: AppSpace.xs),
                        Icon(Icons.recycling_rounded, color: c.onHeroMuted, size: 20),
                        const SizedBox(width: AppSpace.xs - 2),
                        Text('ECOReward', style: t.titleSmall!.copyWith(color: c.onHeroMuted)),
                      ]),

                      const SizedBox(height: AppSpace.md),

                      Text('Join ECOReward ♻️', style: t.headlineMedium!.copyWith(color: c.onHero, fontSize: 30)),
                      const SizedBox(height: AppSpace.xs),
                      Text('Start earning rewards for recycling today',
                          style: t.bodyMedium!.copyWith(color: c.onHeroMuted)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Form
          Positioned(
            top: size.height * 0.27,
            left: 0, right: 0, bottom: 0,
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Container(
                  decoration: BoxDecoration(
                    color: c.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl + 4)),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(AppSpace.xl + 4, AppSpace.xl + 4, AppSpace.xl + 4, AppSpace.xl),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Benefits chips
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(children: [
                              _chip(Icons.stars_rounded, 'Earn Points'),
                              const SizedBox(width: AppSpace.xs),
                              _chip(Icons.card_giftcard_rounded, 'Claim Rewards'),
                              const SizedBox(width: AppSpace.xs),
                              _chip(Icons.eco_rounded, 'Track Impact'),
                            ]),
                          ),

                          const SizedBox(height: AppSpace.xl),

                          // Username
                          _fieldLabel('Username'),
                          const SizedBox(height: AppSpace.xs),
                          _buildField(
                            controller: _userCtrl,
                            hint: 'Choose a username',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => v!.trim().length < 3 ? 'Min 3 characters' : null,
                          ),

                          const SizedBox(height: AppSpace.md),

                          // Email
                          _fieldLabel('Email address'),
                          const SizedBox(height: AppSpace.xs),
                          _buildField(
                            controller: _emailCtrl,
                            hint: 'Enter your email',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => !v!.contains('@') ? 'Enter a valid email' : null,
                          ),

                          const SizedBox(height: AppSpace.md),

                          // Password
                          _fieldLabel('Password'),
                          const SizedBox(height: AppSpace.xs),
                          _buildField(
                            controller: _passCtrl,
                            hint: 'Min 6 characters',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffixIcon: IconButton(
                              tooltip: _obscure ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscure = !_obscure),
                              icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                            ),
                            validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                          ),

                          const SizedBox(height: AppSpace.md),

                          // Confirm password
                          _fieldLabel('Confirm Password'),
                          const SizedBox(height: AppSpace.xs),
                          _buildField(
                            controller: _confirmCtrl,
                            hint: 'Re-enter your password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            suffixIcon: IconButton(
                              tooltip: _obscureConfirm ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  size: 20),
                            ),
                            validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null,
                          ),

                          const SizedBox(height: AppSpace.xl + 4),

                          // Create button
                          AppButton(
                            label: 'Create Account',
                            trailingIcon: Icons.arrow_forward_rounded,
                            height: 56,
                            loading: _loading,
                            onPressed: _register,
                          ),

                          const SizedBox(height: AppSpace.md),

                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text.rich(TextSpan(
                                text: 'Already have an account?  ',
                                style: t.bodyMedium!.copyWith(color: c.textSecondary),
                                children: [TextSpan(text: 'Sign In',
                                    style: TextStyle(color: c.primary, fontWeight: FontWeight.bold))],
                              )),
                            ),
                          ),
                          const SizedBox(height: AppSpace.xl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: c.primaryContainer,
        borderRadius: AppRadius.all(AppRadius.pill),
        border: Border.all(color: c.primary.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: c.onPrimaryContainer, size: 14),
        const SizedBox(width: AppSpace.xs - 2),
        Text(label, style: context.text.labelMedium!.copyWith(color: c.onPrimaryContainer)),
      ]),
    );
  }

  Widget _fieldLabel(String text) => Text(text, style: context.text.labelMedium!.copyWith(
      color: context.colors.textSecondary, fontSize: 13));

  Widget _buildField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) =>
      TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscure,
        style: context.text.bodyLarge,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: suffixIcon,
        ),
        validator: validator,
      );
}

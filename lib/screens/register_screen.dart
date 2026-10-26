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
  final _shakeKey = GlobalKey<ShakeState>();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: AppMotion.slow);
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
    if (!_formKey.currentState!.validate()) {
      _shakeKey.currentState?.shake();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await FirebaseService.register(
        _userCtrl.text.trim(), _emailCtrl.text.trim(), _passCtrl.text.trim(),
      );
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
            MaterialPageRoute(builder: (_) => const CustomerHomeScreen()), (_) => false);
      }
    } catch (e) {
      if (mounted) {
        _shakeKey.currentState?.shake(haptic: false);
        AppSnackbar.error(context, registerErrorMessage(e is FirebaseAuthException ? e.code : e.toString()));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.text;
    return Scaffold(
      backgroundColor: c.background,
      appBar: AppBar(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        leading: HeroBackButton(onTap: () => Navigator.pop(context)),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xxl),
            // Centred at 480 dp on tablets.
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Shake(key: _shakeKey, child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Create your account', style: t.displaySmall),
                            const SizedBox(height: AppSpace.xs),
                            Text('Sort your waste at the bin, collect points, and spend them at the counter.',
                                style: t.bodyLarge!.copyWith(color: c.textSecondary)),
                            const SizedBox(height: AppSpace.xxl),

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
                              validator: (v) => isValidEmail(v!.trim()) ? null : 'Enter a valid email',
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
                              onChanged: (_) => setState(() {}),   // redraw the strength meter
                            ),
                            PasswordStrengthMeter(password: _passCtrl.text),

                            const SizedBox(height: AppSpace.md),

                            // Confirm password
                            _fieldLabel('Confirm password'),
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

                            const SizedBox(height: AppSpace.xl),

                            AppButton(
                              label: 'Create account',
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
                                  children: [TextSpan(text: 'Sign in',
                                      style: TextStyle(color: c.primary, fontWeight: FontWeight.bold))],
                                )),
                              ),
                            ),
                          ],
                        ),
                      )),
                ),
              ),
            ),
          ),
        ),
      ),
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
    ValueChanged<String>? onChanged,
  }) =>
      AppTextField(
        controller: controller,
        keyboardType: keyboardType,
        obscure: obscure,
        hint: hint,
        icon: icon,
        suffix: suffixIcon,
        validator: validator,
        onChanged: onChanged,
        textInputAction: TextInputAction.next,
      );
}

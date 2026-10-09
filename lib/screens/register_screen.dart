import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../core/auth_messages.dart';
import '../services/firebase_service.dart';
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

  static const _bg = Color(0xFFF8F9FA);
  static const _green = Color(0xFF2E7D32);
  static const _greenLight = Color(0xFF4CAF50);
  static const _greenSurface = Color(0xFFE8F5E9);

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
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
            const SizedBox(width: 8),
            Expanded(child: Text(registerErrorMessage(e is FirebaseAuthException ? e.code : e.toString()),
                style: const TextStyle(fontWeight: FontWeight.w500))),
          ]),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Top green header
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: size.height * 0.32,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 20, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Back + logo row
                      Row(children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Icon(Icons.recycling_rounded, color: Colors.white70, size: 20),
                        const SizedBox(width: 6),
                        const Text('ECOReward', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      ]),

                      const SizedBox(height: 24),

                      const Text('Join ECOReward ♻️', style: TextStyle(
                        color: Colors.white, fontSize: 32,
                        fontWeight: FontWeight.bold, height: 1.1, letterSpacing: -0.5,
                      )),
                      const SizedBox(height: 8),
                      const Text('Start earning rewards for recycling today',
                          style: TextStyle(color: Colors.white70, fontSize: 14)),
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
                  decoration: const BoxDecoration(
                    color: _bg,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
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
                              const SizedBox(width: 8),
                              _chip(Icons.card_giftcard_rounded, 'Claim Rewards'),
                              const SizedBox(width: 8),
                              _chip(Icons.eco_rounded, 'Track Impact'),
                            ]),
                          ),

                          const SizedBox(height: 24),

                          // Username
                          _fieldLabel('Username'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _userCtrl,
                            hint: 'Choose a username',
                            icon: Icons.person_outline_rounded,
                            validator: (v) => v!.trim().length < 3 ? 'Min 3 characters' : null,
                          ),

                          const SizedBox(height: 16),

                          // Email
                          _fieldLabel('Email address'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _emailCtrl,
                            hint: 'Enter your email',
                            icon: Icons.mail_outline_rounded,
                            keyboardType: TextInputType.emailAddress,
                            validator: (v) => !v!.contains('@') ? 'Enter a valid email' : null,
                          ),

                          const SizedBox(height: 16),

                          // Password
                          _fieldLabel('Password'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _passCtrl,
                            hint: 'Min 6 characters',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscure = !_obscure),
                              child: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey, size: 20),
                            ),
                            validator: (v) => v!.length < 6 ? 'Min 6 characters' : null,
                          ),

                          const SizedBox(height: 16),

                          // Confirm password
                          _fieldLabel('Confirm Password'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _confirmCtrl,
                            hint: 'Re-enter your password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscureConfirm,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscureConfirm = !_obscureConfirm),
                              child: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: Colors.grey, size: 20),
                            ),
                            validator: (v) => v != _passCtrl.text ? 'Passwords do not match' : null,
                          ),

                          const SizedBox(height: 28),

                          // Create button
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _green,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: _loading
                                  ? const SizedBox(width: 22, height: 22,
                                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                                  : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                                      Text('Create Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ]),
                            ),
                          ),

                          const SizedBox(height: 20),

                          Center(
                            child: GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: RichText(
                                text: const TextSpan(
                                  text: 'Already have an account?  ',
                                  style: TextStyle(color: Colors.grey, fontSize: 14),
                                  children: [TextSpan(text: 'Sign In',
                                      style: TextStyle(color: _green, fontWeight: FontWeight.bold))],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
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

  Widget _chip(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: _greenSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _greenLight.withValues(alpha: 0.3)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: _green, size: 14),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _green, fontWeight: FontWeight.w600, fontSize: 12)),
        ]),
      );

  Widget _fieldLabel(String text) => Text(text,
      style: const TextStyle(color: Color(0xFF424242), fontSize: 13, fontWeight: FontWeight.w600));

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
        style: const TextStyle(color: Color(0xFF1A1A1A), fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          prefixIcon: Icon(icon, color: _greenLight, size: 20),
          suffixIcon: suffixIcon != null
              ? Padding(padding: const EdgeInsets.only(right: 12), child: suffixIcon) : null,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.grey.shade200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: _greenLight, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red)),
          focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Colors.red, width: 1.5)),
        ),
        validator: validator,
      );
}

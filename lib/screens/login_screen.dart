import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/firebase_service.dart';
import 'customer/customer_home_screen.dart';
import 'admin/admin_dashboard_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
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
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final user = await FirebaseService.login(_emailCtrl.text.trim(), _passCtrl.text.trim());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('username', user.username);
      await prefs.setString('role', user.role);
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => user.role == 'admin' ? const AdminDashboardScreen() : const CustomerHomeScreen(),
        ));
      }
    } catch (e) {
      if (mounted) {
        String msg = 'Invalid email or password';
        final err = e.toString();
        if (err.contains('user-not-found') || err.contains('invalid-credential')) msg = 'No account found with this email';
        else if (err.contains('wrong-password')) msg = 'Wrong password';
        else if (err.contains('network')) msg = 'No internet connection';
        else if (err.contains('too-many-requests')) msg = 'Too many attempts. Try later';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w500))),
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
          // Top green wave
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: size.height * 0.42,
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
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Logo
                      Row(children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: const Icon(Icons.recycling_rounded, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text('ECOReward', style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold,
                          fontSize: 18, letterSpacing: 0.5,
                        )),
                      ]),

                      const SizedBox(height: 36),

                      // Headline
                      const Text('Welcome\nback! 👋', style: TextStyle(
                        color: Colors.white, fontSize: 42,
                        fontWeight: FontWeight.bold, height: 1.1, letterSpacing: -1,
                      )),
                      const SizedBox(height: 10),
                      const Text('Sign in to continue recycling\nand earning rewards',
                          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Form card
          Positioned(
            top: size.height * 0.36,
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
                    padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card header
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _greenSurface,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                Container(width: 6, height: 6,
                                    decoration: const BoxDecoration(color: _greenLight, shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                const Text('Sign In', style: TextStyle(
                                    color: _green, fontWeight: FontWeight.bold, fontSize: 12)),
                              ]),
                            ),
                          ]),

                          const SizedBox(height: 24),

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

                          const SizedBox(height: 18),

                          // Password
                          _fieldLabel('Password'),
                          const SizedBox(height: 8),
                          _buildField(
                            controller: _passCtrl,
                            hint: 'Enter your password',
                            icon: Icons.lock_outline_rounded,
                            obscure: _obscure,
                            suffixIcon: GestureDetector(
                              onTap: () => setState(() => _obscure = !_obscure),
                              child: Icon(
                                _obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                color: Colors.grey, size: 20,
                              ),
                            ),
                            validator: (v) => v!.isEmpty ? 'Enter your password' : null,
                          ),

                          const SizedBox(height: 32),

                          // Sign in button
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _login,
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
                                      Text('Sign In', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      SizedBox(width: 8),
                                      Icon(Icons.arrow_forward_rounded, size: 18),
                                    ]),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Divider
                          Row(children: [
                            Expanded(child: Divider(color: Colors.grey.shade200)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('or', style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
                            ),
                            Expanded(child: Divider(color: Colors.grey.shade200)),
                          ]),

                          const SizedBox(height: 24),

                          // Register button
                          SizedBox(
                            width: double.infinity, height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.push(context,
                                  MaterialPageRoute(builder: (_) => const RegisterScreen())),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _green,
                                side: BorderSide(color: _greenLight.withOpacity(0.4)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Create new account',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                            ),
                          ),

                          const SizedBox(height: 20),
                          Center(
                            child: Text('ECOReward Bin · Smart Waste Recycling',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 11)),
                          ),
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

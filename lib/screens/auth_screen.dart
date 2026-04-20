// lib/screens/auth_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/notification_service.dart';
import 'main_shell.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _AuthMode { login, signup }

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = false;

  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;

  final _signupFormKey = GlobalKey<FormState>();
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupConfirmCtrl = TextEditingController();
  bool _signupObscure = true;
  bool _signupConfirmObscure = true;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  void dispose() {
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupConfirmCtrl.dispose();
    super.dispose();
  }

  // ═══ WELCOME / WELCOME BACK NOTIFICATION ═══
  Future<void> _sendLoginNotification() async {
    final user = _auth.currentUser;
    if (user == null) return;

    final prefs = await SharedPreferences.getInstance();
    final key = 'welcome_sent_${user.uid}';
    final isFirstTime = prefs.getBool(key) != true;

    if (isFirstTime) {
      await prefs.setBool(key, true);
      await NotificationService().sendWelcomeNotification(
        user.displayName ?? 'Explorer',
      );
    } else {
      await NotificationService().sendWelcomeBackNotification(
        user.displayName ?? 'Explorer',
      );
    }
  }

  void _navigateToHome() {
    if (!mounted) return;
    _sendLoginNotification();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainShell()),
    );
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red[700] : AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _firebaseError(String code) {
    switch (code) {
      case 'user-not-found': return 'No account found with this email';
      case 'wrong-password': return 'Incorrect password';
      case 'invalid-credential': return 'Invalid email or password';
      case 'email-already-in-use': return 'Email is already registered';
      case 'invalid-email': return 'Invalid email address';
      case 'weak-password': return 'Password must be at least 6 characters';
      case 'too-many-requests': return 'Too many attempts. Try again later';
      case 'account-exists-with-different-credential': return 'Account exists with a different sign-in method';
      default: return 'Something went wrong. Please try again';
    }
  }

  // ── Email/Password Login ──────────────────────────────────────────────────

  Future<void> _login() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      await _auth.signInWithEmailAndPassword(
        email: _loginEmailCtrl.text.trim(),
        password: _loginPasswordCtrl.text.trim(),
      );
      _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseError(e.code), isError: true);
    } catch (_) {
      if (_auth.currentUser != null) { _navigateToHome(); return; }
      _showSnackBar('Login failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Email/Password Sign Up ────────────────────────────────────────────────

  Future<void> _signUp() async {
    if (!_signupFormKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: _signupEmailCtrl.text.trim(),
        password: _signupPasswordCtrl.text.trim(),
      );
      await credential.user?.updateDisplayName(_signupNameCtrl.text.trim());
      _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseError(e.code), isError: true);
    } catch (_) {
      if (_auth.currentUser != null) { _navigateToHome(); return; }
      _showSnackBar('Sign up failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Google Sign-In (always shows account picker) ──────────────────────────

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      // Sign out first to force account picker every time
      await _googleSignIn.signOut();

      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) { setState(() => _isLoading = false); return; }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken, idToken: googleAuth.idToken,
      );

      await _auth.signInWithCredential(credential);
      _navigateToHome();
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseError(e.code), isError: true);
    } catch (_) {
      if (_auth.currentUser != null) { _navigateToHome(); return; }
      _showSnackBar('Google sign-in failed. Please try again.', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Forgot Password ──────────────────────────────────────────────────────

  Future<void> _forgotPassword() async {
    if (_loginEmailCtrl.text.trim().isEmpty) {
      _showSnackBar('Enter your email above first', isError: true);
      return;
    }
    try {
      await _auth.sendPasswordResetEmail(email: _loginEmailCtrl.text.trim());
      _showSnackBar('Password reset email sent!');
    } on FirebaseAuthException catch (e) {
      _showSnackBar(_firebaseError(e.code), isError: true);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              const SizedBox(height: 28),
              _buildLogo(),
              const SizedBox(height: 36),
              _buildCard(),
              const SizedBox(height: 24),
              _buildBottomToggle(),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.6)]),
            boxShadow: [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 24, spreadRadius: 2),
            ],
          ),
          child: const Icon(Icons.travel_explore_rounded, color: Colors.white, size: 34),
        ),
        const SizedBox(height: 14),
        const Text('GOVISTA', style: TextStyle(
          color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 4)),
        const SizedBox(height: 4),
        Text('Explore the Himalayas',
          style: TextStyle(color: Colors.grey[500], fontSize: 13, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        children: [
          _buildTabs(),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
            child: _mode == _AuthMode.login ? _buildLoginForm() : _buildSignupForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: const Color(0xFF252837), borderRadius: BorderRadius.circular(30)),
      child: Row(children: [_tab('Login', _AuthMode.login), _tab('Sign Up', _AuthMode.signup)]),
    );
  }

  Widget _tab(String label, _AuthMode mode) {
    final active = _mode == mode;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _mode = mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: active ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
            boxShadow: active ? [
              BoxShadow(color: AppColors.primary.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4)),
            ] : null,
          ),
          child: Text(label, textAlign: TextAlign.center, style: TextStyle(
            color: active ? Colors.white : Colors.grey[500], fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }

  // ── Login Form ────────────────────────────────────────────────────────────

  Widget _buildLoginForm() {
    return Form(
      key: _loginFormKey,
      child: Column(
        key: const ValueKey('login'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(controller: _loginEmailCtrl, label: 'EMAIL ADDRESS', hint: 'name@example.com',
            icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            }),
          const SizedBox(height: 20),
          _passwordField(controller: _loginPasswordCtrl, label: 'PASSWORD', hint: 'Enter your password',
            obscure: _loginObscure, onToggle: () => setState(() => _loginObscure = !_loginObscure),
            showForgot: true,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter your password';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            }),
          const SizedBox(height: 28),
          _primaryButton('Login', _login),
          const SizedBox(height: 22),
          _orDivider('OR CONTINUE WITH'),
          const SizedBox(height: 22),
          _googleButton(),
        ],
      ),
    );
  }

  // ── Sign-Up Form ──────────────────────────────────────────────────────────

  Widget _buildSignupForm() {
    return Form(
      key: _signupFormKey,
      child: Column(
        key: const ValueKey('signup'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _textField(controller: _signupNameCtrl, label: 'FULL NAME', hint: 'Your full name',
            icon: Icons.person_outline_rounded,
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your name' : null),
          const SizedBox(height: 20),
          _textField(controller: _signupEmailCtrl, label: 'EMAIL ADDRESS', hint: 'name@example.com',
            icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@')) return 'Enter a valid email';
              return null;
            }),
          const SizedBox(height: 20),
          _passwordField(controller: _signupPasswordCtrl, label: 'PASSWORD', hint: 'Create a password',
            obscure: _signupObscure, onToggle: () => setState(() => _signupObscure = !_signupObscure),
            showForgot: false,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 6) return 'Minimum 6 characters';
              return null;
            }),
          const SizedBox(height: 20),
          _passwordField(controller: _signupConfirmCtrl, label: 'CONFIRM PASSWORD', hint: 'Re-enter your password',
            obscure: _signupConfirmObscure,
            onToggle: () => setState(() => _signupConfirmObscure = !_signupConfirmObscure),
            showForgot: false,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Confirm your password';
              if (v != _signupPasswordCtrl.text) return 'Passwords do not match';
              return null;
            }),
          const SizedBox(height: 28),
          _primaryButton('Create Account', _signUp),
          const SizedBox(height: 22),
          _orDivider('OR SIGN UP WITH'),
          const SizedBox(height: 22),
          _googleButton(),
        ],
      ),
    );
  }

  // ── Full-width Google Button ──────────────────────────────────────────────

  Widget _googleButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: _isLoading ? null : _signInWithGoogle,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Colors.grey[700]!, width: 1),
          backgroundColor: const Color(0xFF252837),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Image.network('https://www.gstatic.com/firebasejs/ui/2.0.0/images/auth/google.svg',
            height: 20, width: 20,
            errorBuilder: (_, __, ___) => const Text('G', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white))),
          const SizedBox(width: 10),
          const Text('Continue with Google', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }

  // ── Reusable widgets ─────────────────────────────────────────────────────

  Widget _textField({
    required TextEditingController controller, required String label,
    required String hint, required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
      const SizedBox(height: 10),
      TextFormField(
        controller: controller, keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        validator: validator, decoration: _inputDeco(hint: hint, icon: icon)),
    ]);
  }

  Widget _passwordField({
    required TextEditingController controller, required String label,
    required String hint, required bool obscure, required VoidCallback onToggle,
    required bool showForgot, String? Function(String?)? validator,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        if (showForgot)
          GestureDetector(onTap: _forgotPassword,
            child: Text('FORGOT?', style: TextStyle(
              color: AppColors.primary.withValues(alpha: 0.9), fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5))),
      ]),
      const SizedBox(height: 10),
      TextFormField(
        controller: controller, obscureText: obscure,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        validator: validator,
        decoration: _inputDeco(hint: hint, icon: Icons.lock_outline_rounded,
          suffix: IconButton(onPressed: onToggle,
            icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey[600], size: 20)))),
    ]);
  }

  InputDecoration _inputDeco({required String hint, required IconData icon, Widget? suffix}) {
    return InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: Colors.grey[700], fontSize: 14),
      prefixIcon: Icon(icon, color: Colors.grey[600], size: 20), suffixIcon: suffix,
      filled: true, fillColor: const Color(0xFF252837),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey[800]!, width: 1)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.red, width: 1)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.red, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    );
  }

  Widget _primaryButton(String label, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0),
        child: _isLoading
            ? const SizedBox(height: 22, width: 22,
                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
            : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _orDivider(String text) {
    return Row(children: [
      Expanded(child: Divider(color: Colors.grey[800]!, thickness: 1)),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8))),
      Expanded(child: Divider(color: Colors.grey[800]!, thickness: 1)),
    ]);
  }

  Widget _buildBottomToggle() {
    final isLogin = _mode == _AuthMode.login;
    return GestureDetector(
      onTap: () => setState(() => _mode = isLogin ? _AuthMode.signup : _AuthMode.login),
      child: RichText(
        text: TextSpan(
          text: isLogin ? "Don't have an account?  " : "Already have an account?  ",
          style: TextStyle(color: Colors.grey[500], fontSize: 14),
          children: [
            TextSpan(text: isLogin ? 'Sign Up' : 'Login',
              style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}
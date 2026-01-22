// lib/views/auth/login_page.dart
import 'package:flutter/material.dart';
//import 'package:firebase_auth/firebase_auth.dart';
import '../../controller/auth_controller.dart';
//import '../../models/user_model.dart';
import '../app_shell.dart';
import 'signup_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/api_service.dart';
import 'package:mediqtrack03/view/auth/forgot_password_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final AuthController _authController = AuthController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

 void _doLogin() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);

    print('ðŸŸ¢ Mula login...');

    final userModel = await _authController.login(
      email: _email.text.trim(),
      password: _password.text,
      context: context,
    );

    print('ðŸŸ¡ Login function siap, userModel: $userModel');
    setState(() => _loading = false);

    // âœ… Semak sama ada FirebaseAuth dah update user
    final currentUserBefore = FirebaseAuth.instance.currentUser;
    print('ðŸ§© currentUser sebelum delay: $currentUserBefore');

    await Future.delayed(const Duration(seconds: 2));

    final currentUser = FirebaseAuth.instance.currentUser;
    print('ðŸ§© currentUser selepas delay: $currentUser');

    // âœ… Paksa refresh token baru (elak expired / invalid token)
    await currentUser?.getIdToken(true); 
    final token = await currentUser?.getIdToken();
    print('ðŸ”¥ Firebase ID Token length: ${token?.length}');

    if (userModel != null && mounted) {
      // âœ… Verify token terus ke Laravel API
      await ApiService.verifyToken();

      // âœ… Navigasi ke halaman utama selepas login berjaya
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeShell()),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/icon/images/logo.png',
                  height: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 12),
                const Text('Welcome to MediQTrack',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text('Sign in to continue',
                    style: TextStyle(color: Colors.black54)),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.email_outlined),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Email required';
                          if (!v.contains('@')) return 'Enter a valid email';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _password,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure
                                ? Icons.visibility
                                : Icons.visibility_off),
                          ),
                        ),
                        obscureText: _obscure,
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Min 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 6),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Forgot Password?',
                          style: TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loading ? null : _doLogin,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Sign In'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                    );
                  },
                  child: const Text("Don't have an account? Sign Up"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

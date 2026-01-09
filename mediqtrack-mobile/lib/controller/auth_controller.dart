// lib/controllers/auth_controller.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/user_model.dart';

class AuthController {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 🔐 Login function
  Future<UserModel?> login(
      {required String email,
      required String password,
      required BuildContext context}) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = cred.user;
      if (user == null) {
        _showMessage(context, 'Login gagal: user tidak dijumpai.');
        return null;
      }

      // Refresh verification status
      await user.reload();
      final refreshed = _auth.currentUser;

      if (refreshed == null) {
        _showMessage(context, 'Login gagal: masalah sesi pengguna.');
        return null;
      }

      if (!refreshed.emailVerified) {
        final resend = await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Email belum disahkan'),
            content: const Text(
              'Sila sahkan email anda dahulu. Nak saya hantar semula email pengesahan?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Hantar semula'),
              ),
            ],
          ),
        );

        if (resend == true) {
          await refreshed.sendEmailVerification();
          _showMessage(context, 'Email pengesahan dihantar semula.');
        }

        await _auth.signOut();
        return null;
      }

      return UserModel.fromFirebaseUser(refreshed);
    } on FirebaseAuthException catch (e) {
      String msg = 'Login gagal.';
      switch (e.code) {
        case 'invalid-email':
          msg = 'Email tidak sah.';
          break;
        case 'user-disabled':
          msg = 'Akaun ini telah dinyahaktifkan.';
          break;
        case 'user-not-found':
          msg = 'Tiada akaun dengan email ini.';
          break;
        case 'wrong-password':
          msg = 'Katalaluan salah.';
          break;
        default:
          msg = e.message ?? e.code;
      }
      _showMessage(context, msg);
      return null;
    } catch (e) {
      _showMessage(context, 'Ralat: ${e.toString()}');
      return null;
    }
  }

  // 🚪 Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  void _showMessage(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

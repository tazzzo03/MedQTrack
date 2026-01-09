import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../main.dart'; // akses _setupFCM & _didSetupFCM
import '../app_shell.dart';
import 'login_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    print('🧩 [DEBUG] AuthGate loaded');

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        // setup FCM sekali je
        if (!didSetupFCM && user.uid.isNotEmpty) {
          didSetupFCM = true;
          print('🧩 [DEBUG] Setup FCM untuk user: ${user.uid}');
          setupFCM();
        }

        // kalau belum verify email
        if (!user.emailVerified) {
          return Scaffold(
            appBar: AppBar(title: const Text('Verify Email')),
            body: Center(child: Text('Please verify your email.')),
          );
        }

        return const HomeShell();
      },
    );
  }
}

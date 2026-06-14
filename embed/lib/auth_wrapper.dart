import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'dashboard_page.dart';
import 'login_page.dart';

/// Mengarahkan pengguna ke dashboard bila sudah masuk, atau ke halaman login
/// bila belum, berdasarkan status autentikasi Firebase.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.active) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final user = snapshot.data;
        return user == null ? const LoginPage() : DashboardPage(userId: user.uid);
      },
    );
  }
}

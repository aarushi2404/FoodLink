import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'admin_home.dart';
import 'login_screen.dart';
import 'user_home.dart';
import 'vendor_home.dart';

/// Decides what to show: login, or the home for the signed-in role.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: AuthService.instance.authChanges,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const _Loading();
        }
        final user = snap.data;
        if (user == null) return const LoginScreen();

        return FutureBuilder<AppUser?>(
          // key forces a reload when a different account signs in
          key: ValueKey(user.uid),
          future: _loadWithRetry(user.uid),
          builder: (context, profileSnap) {
            if (profileSnap.connectionState == ConnectionState.waiting) {
              return const _Loading();
            }
            final profile = profileSnap.data;
            if (profile == null) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Could not load your profile.'),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: AuthService.instance.signOut,
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (profile.isAdmin) return AdminHome(admin: profile);
            if (profile.isVendor) return VendorHome(vendor: profile);
            return UserHome(user: profile);
          },
        );
      },
    );
  }

  // Right after sign-up the profile doc may land a moment after the auth event.
  Future<AppUser?> _loadWithRetry(String uid) async {
    for (var i = 0; i < 4; i++) {
      final p = await AuthService.instance.loadProfile(uid);
      if (p != null) return p;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return null;
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

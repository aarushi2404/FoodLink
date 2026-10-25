import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import 'dashboard_view.dart';

/// Platform-wide impact across every vendor. Admin accounts are created by
/// setting `role` to `admin` on a user in the Firebase console.
class AdminHome extends StatelessWidget {
  final AppUser admin;
  const AdminHome({super.key, required this.admin});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FoodLink - Admin'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: AuthService.instance.signOut,
          ),
        ],
      ),
      body: const DashboardView(vendorId: null),
    );
  }
}

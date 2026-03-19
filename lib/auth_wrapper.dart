import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'Providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/admin_dashboard.dart';
import 'screens/employee_dashboard.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: Colors.white)),
          );
        }

        if (auth.user == null) {
          return const LoginScreen();
        }

        final String role = (auth.appUser?.role ?? 'customer').toLowerCase();

        switch (role) {
          case 'admin':
            return const AdminDashboard();
          case 'employee':
            return const EmployeeDashboard();
          case 'customer':
          default:
            return const HomeScreen();
        }
      },
    );
  }
}

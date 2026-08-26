import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/customer_shell.dart';
import 'screens/admin_dashboard.dart';
import 'screens/employee_dashboard.dart';
import 'core/theme/app_colors.dart';
import 'core/widgets/app_widgets.dart';

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.isLoading) {
          return const Scaffold(
            backgroundColor: AppColors.primary,
            body: GlowLoading(message: 'Loading Polar Glow…'),
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
            return const CustomerShell();
        }
      },
    );
  }
}

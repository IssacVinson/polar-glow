import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/auth/auth_gate.dart';
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
        final dest = AuthGate.destination(
          isLoading: auth.isLoading,
          signedIn: auth.user != null,
          role: auth.appUser?.role,
        );

        switch (dest) {
          case AuthDestination.loading:
            return const Scaffold(
              backgroundColor: AppColors.primary,
              body: GlowLoading(message: 'Loading Polar Glow…'),
            );
          case AuthDestination.login:
            return const LoginScreen();
          case AuthDestination.admin:
            return const AdminDashboard();
          case AuthDestination.employee:
            return const EmployeeDashboard();
          case AuthDestination.customer:
            return const CustomerShell();
        }
      },
    );
  }
}

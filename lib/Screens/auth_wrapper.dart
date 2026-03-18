import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'employee_clock_screen.dart';
import 'admin_dashboard.dart'; // your existing one
import 'home_screen.dart'; // the one we just made

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('🔄 Auth state changed → hasUser: ${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == null) {
          debugPrint('✅ Showing LoginScreen');
          return const LoginScreen();
        }

        final user = snapshot.data!;
        debugPrint('👤 Logged in: ${user.email} (UID: ${user.uid})');

        return FutureBuilder<DocumentSnapshot>(
          // Added timeout so it never hangs forever
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get()
              .timeout(const Duration(seconds: 10)),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              debugPrint('⏳ Fetching role from Firestore...');
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            // Error (permissions, network, etc.)
            if (roleSnapshot.hasError) {
              debugPrint('❌ Firestore error: ${roleSnapshot.error}');
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 80,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Error loading profile:\n${roleSnapshot.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 32),
                        ElevatedButton(
                          onPressed: () => FirebaseAuth.instance.signOut(),
                          child: const Text('Sign Out & Try Again'),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            // Document missing (very common cause of stuck spinner)
            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              debugPrint('⚠️ No user document found for UID: ${user.uid}');
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'User profile not found in database.\n\n'
                      'Sign out, then sign up again (it will create the profile).\n'
                      'Or contact support.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              );
            }

            // Success — normal role routing
            final roleData = roleSnapshot.data!.data() as Map<String, dynamic>?;
            final role =
                (roleData?['role'] as String?)?.toLowerCase() ?? 'customer';
            debugPrint('✅ Role loaded: $role');

            switch (role) {
              case 'admin':
                return const AdminDashboard();
              case 'employee':
                return const EmployeeClockScreen();
              case 'customer':
              default:
                return const HomeScreen();
            }
          },
        );
      },
    );
  }
}

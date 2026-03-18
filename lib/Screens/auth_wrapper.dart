import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'login_screen.dart';
import 'employee_clock_screen.dart';
import 'admin_dashboard.dart';
import 'home_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  int _retryCount = 0;
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 800);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        debugPrint('🔄 Auth state changed → hasUser: ${snapshot.hasData}');

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.data == null) {
          debugPrint('✅ Showing LoginScreen');
          return const LoginScreen();
        }

        final user = snapshot.data!;
        debugPrint('👤 Logged in: ${user.email} (UID: ${user.uid})');

        // Retry logic for first-time read
        return FutureBuilder<DocumentSnapshot>(
          future: _fetchUserWithRetry(user.uid),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              debugPrint(
                  '⏳ Fetching role (retry $_retryCount/$_maxRetries)...');
              return const Scaffold(
                  body: Center(child: CircularProgressIndicator()));
            }

            if (roleSnapshot.hasError) {
              debugPrint('❌ Firestore error: ${roleSnapshot.error}');
              return Scaffold(
                body: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 80, color: Colors.red),
                        const SizedBox(height: 24),
                        Text('Error loading profile:\n${roleSnapshot.error}'),
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

            if (!roleSnapshot.hasData || !roleSnapshot.data!.exists) {
              debugPrint('⚠️ No user document found for UID: ${user.uid}');
              if (_retryCount < _maxRetries) {
                _retryCount++;
                Future.delayed(
                    _retryDelay, () => setState(() {})); // trigger retry
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }

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

            // Success
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

  Future<DocumentSnapshot> _fetchUserWithRetry(String uid) async {
    try {
      return await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
    } catch (e) {
      if (_retryCount < _maxRetries) {
        await Future.delayed(_retryDelay);
        return _fetchUserWithRetry(uid); // recursive retry
      }
      rethrow;
    }
  }
}

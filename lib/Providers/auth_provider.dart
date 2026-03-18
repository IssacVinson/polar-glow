import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthProvider with ChangeNotifier {
  User? _user;
  String? _role; // 'customer', 'employee', 'admin', or null

  User? get user => _user;
  String? get role => _role;
  bool get isLoggedIn => _user != null;

  AuthProvider() {
    // Listen to auth state changes (login/logout)
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      _user = user;

      if (user != null) {
        // Fetch role from Firestore
        try {
          final doc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          _role = doc.data()?['role'] as String? ?? 'customer';
        } catch (e) {
          debugPrint('Error fetching role: $e');
          _role = 'customer'; // fallback
        }
      } else {
        _role = null;
      }

      notifyListeners();
    });
  }

  /// Sign in with email and password
  Future<String?> signIn(String email, String password) async {
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      return null; // success = no error
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Login failed';
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  /// Sign up with email and password (defaults to 'customer' role)
  Future<String?> signUp(String email, String password) async {
    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: email.trim(),
            password: password.trim(),
          );

      // Create user document with default role
      await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .set({
            'email': email.trim(),
            'role': 'customer',
            'createdAt': FieldValue.serverTimestamp(),
          });

      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign up failed';
    } catch (e) {
      return 'An error occurred: $e';
    }
  }

  /// Sign out
  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
  }
}

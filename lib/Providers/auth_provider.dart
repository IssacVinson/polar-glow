import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../core/services/firestore_service.dart';
import '../core/models/app_user.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirestoreService _firestore = FirestoreService();

  User? _user;
  AppUser? _appUser;
  bool _isLoading = false;

  User? get user => _user;
  AppUser? get appUser => _appUser;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;
      if (user != null) {
        _appUser = await _firestore.getUser(user.uid);
      } else {
        _appUser = null;
      }
      notifyListeners();
    });
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // signUp, signOut, etc. stay the same (just call _firestore.getUserRole if needed)
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

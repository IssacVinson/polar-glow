import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String role;
  final String? phoneNumber;

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.role,
    this.phoneNumber,
  });

  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      role: (data['role'] as String?)?.toLowerCase() ?? 'customer',
      phoneNumber: data['phone'],
    );
  }
}

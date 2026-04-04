import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String uid;
  final String email;
  final String? displayName;
  final String role;
  final String? phoneNumber;
  final double? hourlyRate; // NEW: for payroll + admin pay rate management

  AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    required this.role,
    this.phoneNumber,
    this.hourlyRate,
  });

  factory AppUser.fromDocument(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppUser(
      uid: doc.id,
      email: data['email'] ?? '',
      displayName: data['displayName'],
      role: (data['role'] as String?)?.toLowerCase() ?? 'customer',
      phoneNumber: data['phone'],
      hourlyRate: (data['hourlyRate'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'role': role,
      'phone': phoneNumber,
      'hourlyRate': hourlyRate,
    };
  }

  // Convenience getters for finance/payroll logic
  bool get isEmployee => role == 'employee' || role == 'admin';
  bool get isAdmin => role == 'admin';
  bool get isCustomer => role == 'customer';
}

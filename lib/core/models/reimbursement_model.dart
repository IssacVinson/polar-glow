// lib/core/models/reimbursement_model.dart
// UPDATED: Added receiptUrl support (used for receipt photos)

import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/alaska_date_utils.dart';

class ReimbursementModel {
  final String id;
  final String employeeId;
  final String title; // e.g. "Gas for customer run", "Supplies"
  final String description;
  final double amount;
  final DateTime dateSubmitted;
  final String status; // 'pending' | 'approved' | 'denied' | 'paid'
  final DateTime? approvedAt;
  final String? approvedBy; // admin UID who approved/denied
  final DateTime? paidAt;
  final String? paidBy; // admin UID who marked as paid
  final String? receiptUrl; // ← NEW: URL to the uploaded receipt image

  ReimbursementModel({
    required this.id,
    required this.employeeId,
    required this.title,
    required this.description,
    required this.amount,
    required this.dateSubmitted,
    this.status = 'pending',
    this.approvedAt,
    this.approvedBy,
    this.paidAt,
    this.paidBy,
    this.receiptUrl, // ← NEW
  });

  factory ReimbursementModel.fromMap(Map<String, dynamic> map, String id) {
    return ReimbursementModel(
      id: id,
      employeeId: map['employeeId'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      amount: (map['amount'] as num).toDouble(),
      dateSubmitted: AlaskaDateUtils.toAlaskaDayKey(
          (map['dateSubmitted'] as Timestamp).toDate()),
      status: map['status'] ?? 'pending',
      approvedAt: map['approvedAt'] != null
          ? (map['approvedAt'] as Timestamp).toDate()
          : null,
      approvedBy: map['approvedBy'],
      paidAt:
          map['paidAt'] != null ? (map['paidAt'] as Timestamp).toDate() : null,
      paidBy: map['paidBy'],
      receiptUrl: map['receiptUrl'], // ← NEW
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'title': title,
      'description': description,
      'amount': amount,
      'dateSubmitted': Timestamp.fromDate(
          AlaskaDateUtils.toAlaskaStorageDate(dateSubmitted)),
      'status': status,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'approvedBy': approvedBy,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paidBy': paidBy,
      'receiptUrl': receiptUrl, // ← NEW
    };
  }

  // Convenience getters
  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isDenied => status == 'denied';
  bool get isPaid => status == 'paid';
}

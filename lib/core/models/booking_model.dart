import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/alaska_date_utils.dart';

class BookingModel {
  final String id;
  final String customerId;
  final DateTime date;
  final List<Map<String, dynamic>> cars; // [{'vehicle': '...', 'time': '...'}]
  final List<Map<String, dynamic>> services;
  final double totalPrice;
  final String? assignedDetailerId;
  final String address;
  final String notes;
  final String status;

  // === NEW FINANCIAL TRACKING (clean unified structure) ===
  final String paymentMethod; // 'stripe' | 'cash'
  final String paymentStatus; // 'unpaid' | 'paid'
  final String? paymentIntentId; // only populated for Stripe payments
  final DateTime? paidAt; // when the payment was actually marked paid
  final String?
      paidBy; // UID of employee who marked cash payment as paid (audit trail)

  // === NEW: Operation completion tracking (consistency with reimbursement pattern) ===
  final DateTime? completedAt; // when employee marks the detail as completed
  final String? completedBy; // UID of employee who completed the job

  BookingModel({
    required this.id,
    required this.customerId,
    required this.date,
    required this.cars,
    required this.services,
    required this.totalPrice,
    this.assignedDetailerId,
    required this.address,
    required this.notes,
    this.status = 'pending',
    required this.paymentMethod, // must be set at booking time
    this.paymentStatus = 'unpaid',
    this.paymentIntentId,
    this.paidAt,
    this.paidBy,
    this.completedAt,
    this.completedBy,
  });

  factory BookingModel.fromMap(Map<String, dynamic> map, String id) {
    return BookingModel(
      id: id,
      customerId: map['customerId'] ?? '',
      date: AlaskaDateUtils.toAlaskaDayKey((map['date'] as Timestamp).toDate()),
      cars: List<Map<String, dynamic>>.from(map['cars'] ?? []),
      services: List<Map<String, dynamic>>.from(map['services'] ?? []),
      totalPrice: (map['totalPrice'] as num).toDouble(),
      assignedDetailerId: map['assignedDetailerId'],
      address: map['address'] ?? '',
      notes: map['notes'] ?? '',
      status: map['status'] ?? 'pending',
      // Finance fields
      paymentMethod: map['paymentMethod'] ?? 'cash',
      paymentStatus: map['paymentStatus'] ?? 'unpaid',
      paymentIntentId: map['paymentIntentId'],
      paidAt:
          map['paidAt'] != null ? (map['paidAt'] as Timestamp).toDate() : null,
      paidBy: map['paidBy'],
      // Completion fields (new tweak)
      completedAt: map['completedAt'] != null
          ? (map['completedAt'] as Timestamp).toDate()
          : null,
      completedBy: map['completedBy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'date': Timestamp.fromDate(AlaskaDateUtils.toAlaskaStorageDate(date)),
      'cars': cars,
      'services': services,
      'totalPrice': totalPrice,
      'assignedDetailerId': assignedDetailerId,
      'address': address,
      'notes': notes,
      'status': status,
      // Finance fields
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
      'paymentIntentId': paymentIntentId,
      'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
      'paidBy': paidBy,
      // Completion fields
      'completedAt':
          completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'completedBy': completedBy,
    };
  }

  // Convenience getters for the new finance + operations logic
  bool get isPaid => paymentStatus == 'paid';
  bool get isStripePayment => paymentMethod == 'stripe';
  bool get isCashPayment => paymentMethod == 'cash';
  bool get isCompleted => completedAt != null;
}

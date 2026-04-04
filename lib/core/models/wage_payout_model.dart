import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/alaska_date_utils.dart';

class WagePayoutModel {
  final String id;
  final String employeeId;
  final double totalHours;
  final double hourlyRate;
  final double grossPay;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime paidAt;
  final String paidBy; // admin UID

  WagePayoutModel({
    required this.id,
    required this.employeeId,
    required this.totalHours,
    required this.hourlyRate,
    required this.grossPay,
    required this.periodStart,
    required this.periodEnd,
    required this.paidAt,
    required this.paidBy,
  });

  factory WagePayoutModel.fromMap(Map<String, dynamic> map, String id) {
    return WagePayoutModel(
      id: id,
      employeeId: map['employeeId'] ?? '',
      totalHours: (map['totalHours'] as num).toDouble(),
      hourlyRate: (map['hourlyRate'] as num).toDouble(),
      grossPay: (map['grossPay'] as num).toDouble(),
      periodStart: AlaskaDateUtils.toAlaskaDayKey(
          (map['periodStart'] as Timestamp).toDate()),
      periodEnd: AlaskaDateUtils.toAlaskaDayKey(
          (map['periodEnd'] as Timestamp).toDate()),
      paidAt: (map['paidAt'] as Timestamp).toDate(),
      paidBy: map['paidBy'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'employeeId': employeeId,
      'totalHours': totalHours,
      'hourlyRate': hourlyRate,
      'grossPay': grossPay,
      'periodStart':
          Timestamp.fromDate(AlaskaDateUtils.toAlaskaStorageDate(periodStart)),
      'periodEnd':
          Timestamp.fromDate(AlaskaDateUtils.toAlaskaStorageDate(periodEnd)),
      'paidAt': Timestamp.fromDate(paidAt),
      'paidBy': paidBy,
    };
  }
}

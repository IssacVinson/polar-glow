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
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'date': Timestamp.fromDate(
          AlaskaDateUtils.toAlaskaStorageDate(date)), // Stores correct AKST day
      'cars': cars,
      'services': services,
      'totalPrice': totalPrice,
      'assignedDetailerId': assignedDetailerId,
      'address': address,
      'notes': notes,
      'status': status,
    };
  }
}

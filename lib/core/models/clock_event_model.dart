import 'package:cloud_firestore/cloud_firestore.dart';

class ClockEventModel {
  final String id;
  final String type; // 'clock_in' or 'clock_out'
  final DateTime timestamp;
  final String date; // yyyy-MM-dd for grouping

  ClockEventModel({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.date,
  });

  factory ClockEventModel.fromMap(Map<String, dynamic> map, String id) {
    return ClockEventModel(
      id: id,
      type: map['type'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      date: map['date'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'date': date,
    };
  }
}

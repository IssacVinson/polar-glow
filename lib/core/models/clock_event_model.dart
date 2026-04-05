// lib/core/models/clock_event_model.dart
// UPDATED: Added payoutId so we can permanently flag events as already paid out

import 'package:cloud_firestore/cloud_firestore.dart';

class ClockEventModel {
  final String id;
  final String type; // 'in' or 'out' (or legacy 'clock_in'/'clock_out')
  final DateTime timestamp;
  final String date; // yyyy-MM-dd Alaska date string
  final String?
      payoutId; // NEW: null = still unpaid, otherwise references wage_payouts doc

  ClockEventModel({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.date,
    this.payoutId,
  });

  factory ClockEventModel.fromMap(Map<String, dynamic> map, String id) {
    return ClockEventModel(
      id: id,
      type: map['type'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      date: map['date'] ?? '',
      payoutId: map['payoutId'], // can be null
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'timestamp': Timestamp.fromDate(timestamp),
      'date': date,
      if (payoutId != null) 'payoutId': payoutId,
    };
  }
}

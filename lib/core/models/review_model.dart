// lib/core/models/review_model.dart
// NEW FILE — Create this exact path/file in your project

import 'package:cloud_firestore/cloud_firestore.dart';

enum ReviewType {
  service, // review tied to a specific booking + detailer
  management, // general feedback about customer service / management
  app, // feedback specifically about the Polar Glow app
}

class ReviewModel {
  final String id; // Firestore document ID
  final String customerId;
  final String customerName; // for easy display in admin/employee views
  final ReviewType type;
  final String? bookingId; // only for service reviews
  final String? detailerId; // only for service reviews
  final String? detailerName; // only for service reviews
  final int rating; // 1–5 stars (overall for the selected type)
  final String comment; // free-text feedback
  final DateTime createdAt;
  final String status; // 'pending' | 'approved' (for future moderation)

  ReviewModel({
    required this.id,
    required this.customerId,
    required this.customerName,
    required this.type,
    this.bookingId,
    this.detailerId,
    this.detailerName,
    required this.rating,
    required this.comment,
    required this.createdAt,
    this.status = 'pending',
  });

  // Factory to create from Firestore document
  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      id: doc.id,
      customerId: data['customerId'] ?? '',
      customerName: data['customerName'] ?? 'Anonymous Customer',
      type: _parseReviewType(data['type']),
      bookingId: data['bookingId'],
      detailerId: data['detailerId'],
      detailerName: data['detailerName'],
      rating: data['rating'] ?? 5,
      comment: data['comment'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: data['status'] ?? 'pending',
    );
  }

  // Convert to Map for Firestore writes
  Map<String, dynamic> toFirestore() {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'type': type.name, // "service", "management", or "app"
      if (bookingId != null) 'bookingId': bookingId,
      if (detailerId != null) 'detailerId': detailerId,
      if (detailerName != null) 'detailerName': detailerName,
      'rating': rating,
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
      'status': status,
    };
  }

  // Helper to parse string back to enum
  static ReviewType _parseReviewType(String? typeStr) {
    switch (typeStr) {
      case 'service':
        return ReviewType.service;
      case 'management':
        return ReviewType.management;
      case 'app':
        return ReviewType.app;
      default:
        return ReviewType.app; // fallback
    }
  }
}

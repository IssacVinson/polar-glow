// lib/Screens/reviews_screen.dart
// FULLY CLEANED FILE — Replace your entire reviews_screen.dart with this exact code
// (Both lints fixed: removed unused isEmployee + _ReviewCard constructor updated)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart' as app_auth;
import '../core/models/review_model.dart';

class ReviewsScreen extends StatefulWidget {
  const ReviewsScreen({super.key});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final currentUser = authProvider.user;
    final appUser = authProvider.appUser;

    if (currentUser == null || appUser == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view reviews')),
      );
    }

    final isAdmin = appUser.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(isAdmin ? 'All Reviews' : 'My Reviews'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: isAdmin
            // Admins see EVERYTHING
            ? FirebaseFirestore.instance
                .collection('reviews')
                .orderBy('createdAt', descending: true)
                .snapshots()
            // Employees see only service reviews where they are the detailer
            : FirebaseFirestore.instance
                .collection('reviews')
                .where('detailerId', isEqualTo: currentUser.uid)
                .where('type', isEqualTo: 'service')
                .orderBy('createdAt', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.rate_review,
                      size: 80, color: Colors.white54),
                  const SizedBox(height: 16),
                  Text(
                    isAdmin
                        ? 'No reviews yet'
                        : 'No reviews for your services yet',
                    style: const TextStyle(fontSize: 20, color: Colors.white70),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Reviews will appear here automatically',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            );
          }

          final reviews = snapshot.data!.docs
              .map((doc) => ReviewModel.fromFirestore(doc))
              .toList();

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: reviews.length,
            itemBuilder: (context, index) {
              final review = reviews[index];
              return _ReviewCard(review: review, isAdmin: isAdmin);
            },
          );
        },
      ),
    );
  }
}

// Fixed constructor — explicit Key? + super(key: key) removes the lint
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isAdmin;

  const _ReviewCard({
    Key? key,
    required this.review,
    required this.isAdmin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final typeLabel = review.type == ReviewType.service
        ? 'Service Review'
        : review.type == ReviewType.management
            ? 'Management Review'
            : 'App Review';

    final dateFormatted =
        DateFormat('MMM d, yyyy • h:mm a').format(review.createdAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  review.type == ReviewType.service
                      ? Icons.car_repair
                      : review.type == ReviewType.management
                          ? Icons.support_agent
                          : Icons.phone_android,
                  color: Colors.amber,
                ),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const Spacer(),
                Text(
                  '${review.rating} ★',
                  style: const TextStyle(
                    fontSize: 18,
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Customer + date
            Text(
              'By ${review.customerName} • $dateFormatted',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.7),
              ),
            ),

            if (review.type == ReviewType.service &&
                review.bookingId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Booking #${review.bookingId!.substring(0, 8)}',
                style: const TextStyle(fontSize: 13, color: Colors.cyan),
              ),
            ],

            const Divider(height: 24),

            // Comment
            Text(
              review.comment.isNotEmpty
                  ? review.comment
                  : 'No additional comment provided',
              style: const TextStyle(fontSize: 15, height: 1.4),
            ),

            // Only admins see a small "Delete" action
            if (isAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Delete'),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Review?'),
                        content: const Text('This cannot be undone.'),
                        actions: [
                          TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel')),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Delete',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await FirebaseFirestore.instance
                          .collection('reviews')
                          .doc(review.id)
                          .delete();
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

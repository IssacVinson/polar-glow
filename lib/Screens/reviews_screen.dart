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
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<app_auth.AuthProvider>();
    final currentUser = authProvider.user;
    final appUser = authProvider.appUser;

    if (currentUser == null || appUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: const Center(
          child: Text(
            'Please sign in to view reviews',
            style: TextStyle(color: Colors.white70, fontSize: 18),
          ),
        ),
      );
    }

    final isAdmin = appUser.role == 'admin';
    final currentUserId = currentUser.uid;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          isAdmin ? 'All Reviews' : 'My Reviews',
          style:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Simple query that never needs a composite index
        stream: FirebaseFirestore.instance
            .collection('reviews')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error: ${snapshot.error}',
                style: const TextStyle(color: Colors.white70),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState(isAdmin);
          }

          // Filter client-side
          var reviews = snapshot.data!.docs
              .map((doc) => ReviewModel.fromFirestore(doc))
              .toList();

          if (!isAdmin) {
            reviews = reviews
                .where((review) =>
                    review.detailerId == currentUserId &&
                    review.type == ReviewType.service)
                .toList();
          }

          if (reviews.isEmpty) {
            return _buildEmptyState(isAdmin);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(24),
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

  Widget _buildEmptyState(bool isAdmin) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.rate_review,
              size: 90, color: _accentColor.withOpacity(0.3)),
          const SizedBox(height: 24),
          Text(
            isAdmin ? 'No reviews yet' : 'No reviews for your services yet',
            style: const TextStyle(fontSize: 22, color: Colors.white70),
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
}

// Premium Review Card (unchanged)
class _ReviewCard extends StatelessWidget {
  final ReviewModel review;
  final bool isAdmin;

  const _ReviewCard({
    required this.review,
    required this.isAdmin,
  });

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
      margin: const EdgeInsets.only(bottom: 20),
      elevation: 12,
      shadowColor: const Color(0xFF00E5FF).withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  review.type == ReviewType.service
                      ? Icons.car_repair
                      : review.type == ReviewType.management
                          ? Icons.support_agent
                          : Icons.phone_android,
                  color: const Color(0xFF00E5FF),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  typeLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                Text(
                  '${review.rating} ★',
                  style: const TextStyle(
                    fontSize: 22,
                    color: Color(0xFFFFD700),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'By ${review.customerName} • $dateFormatted',
              style: const TextStyle(fontSize: 14, color: Colors.white54),
            ),
            if (review.type == ReviewType.service &&
                review.bookingId != null) ...[
              const SizedBox(height: 4),
              Text(
                'Booking #${review.bookingId!.substring(0, 8)}',
                style: const TextStyle(fontSize: 14, color: Color(0xFF00E5FF)),
              ),
            ],
            const Divider(height: 28, color: Colors.white24),
            Text(
              review.comment.isNotEmpty
                  ? review.comment
                  : 'No additional comment provided',
              style: const TextStyle(
                  fontSize: 16, height: 1.5, color: Colors.white),
            ),
            if (isAdmin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Delete Review'),
                  style:
                      TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.grey[900],
                        title: const Text('Delete Review?',
                            style: TextStyle(color: Colors.white)),
                        content: const Text('This action cannot be undone.',
                            style: TextStyle(color: Colors.white70)),
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

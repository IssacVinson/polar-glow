// lib/Screens/feedback_screen.dart
// UPDATED: Scroll box for completed bookings is now smaller (height reduced from 260 → 200)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart' as app_auth;
import '../core/models/review_model.dart';

class CustomerFeedbackScreen extends StatefulWidget {
  final String? preselectedBookingId;

  const CustomerFeedbackScreen({
    super.key,
    this.preselectedBookingId,
  });

  @override
  State<CustomerFeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<CustomerFeedbackScreen> {
  late ReviewType _selectedType;
  String? _selectedBookingId;
  String? _selectedDetailerId;
  String? _selectedDetailerName;
  int _rating = 5;
  final _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedType = ReviewType.service;
    _selectedBookingId = widget.preselectedBookingId;
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final authProvider = context.read<app_auth.AuthProvider>();
    final currentUser = authProvider.user;
    final appUser = authProvider.appUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to submit a review')),
      );
      return;
    }

    final customerName = appUser?.displayName ??
        currentUser.email?.split('@')[0] ??
        'Anonymous Customer';

    if (_selectedType == ReviewType.service && _selectedBookingId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please select a completed booking first')),
      );
      return;
    }

    final review = ReviewModel(
      id: '',
      customerId: currentUser.uid,
      customerName: customerName,
      type: _selectedType,
      bookingId:
          _selectedType == ReviewType.service ? _selectedBookingId : null,
      detailerId:
          _selectedType == ReviewType.service ? _selectedDetailerId : null,
      detailerName:
          _selectedType == ReviewType.service ? _selectedDetailerName : null,
      rating: _rating,
      comment: _commentController.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      await FirebaseFirestore.instance
          .collection('reviews')
          .add(review.toFirestore());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you! Your review has been submitted ❤️'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit review: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Give Feedback'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What would you like to review?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildTypeSelector(),
            const SizedBox(height: 32),
            if (_selectedType == ReviewType.service) ...[
              const Text(
                'Which service would you like to review?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              _buildCompletedBookingsPicker(),
              const SizedBox(height: 32),
            ],
            const Text(
              'Overall rating',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Center(
              child: _StarRating(
                value: _rating,
                onChanged: (val) => setState(() => _rating = val),
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: _commentController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Tell us more (optional but super helpful)',
                border: OutlineInputBorder(),
                hintText: 'What did you love? What could be better?',
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text(
                  'Submit Review',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  backgroundColor: Colors.amber[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _submitReview,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeSelector() {
    return Row(
      children: [
        _buildTypeCard(
            ReviewType.service, 'Detailing Service', Icons.car_repair),
        const SizedBox(width: 12),
        _buildTypeCard(
            ReviewType.management, 'Management', Icons.support_agent),
        const SizedBox(width: 12),
        _buildTypeCard(ReviewType.app, 'The App', Icons.phone_android),
      ],
    );
  }

  Widget _buildTypeCard(ReviewType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectedType = type),
        child: Card(
          elevation: isSelected ? 6 : 2,
          color: isSelected ? Colors.cyan.withOpacity(0.15) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 36,
                  color: isSelected ? Colors.cyan : Colors.white70,
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedBookingsPicker() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return const Text('Please sign in');

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .where('customerId', isEqualTo: currentUser.uid)
          .where('completed', isEqualTo: true)
          .orderBy('date', descending: true)
          .limit(12)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          final error = snapshot.error.toString();
          if (error.contains('requires an index')) {
            return Card(
              color: Colors.amber[100],
              child: const Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 48, color: Colors.amber),
                    SizedBox(height: 12),
                    Text(
                      'One-time setup needed',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Firebase needs a composite index for this query.\n'
                      'Click the link in the terminal (or search "Firestore indexes" in console) and create it.\n'
                      'It usually takes under 60 seconds.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return Center(child: Text('Error: $error'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: Text(
                  'No completed bookings yet.\nBook a service and come back!',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          );
        }

        return SizedBox(
          height: 200, // ← REDUCED from 260 → 200 (much shorter scroll box)
          child: ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bookingId = doc.id;
              final date = (data['date'] as Timestamp).toDate();
              final timeSlot =
                  data['cars']?[0]?['time'] ?? data['timeSlot'] ?? '';
              final detailerName = data['assignedDetailerName'] ??
                  data['assignedEmployeeName'] ??
                  'Detailer';

              final isSelected = _selectedBookingId == bookingId;

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                color: isSelected ? Colors.cyan.withOpacity(0.2) : null,
                child: ListTile(
                  leading: const Icon(Icons.check_circle, color: Colors.green),
                  title: Text(
                    DateFormat('EEEE, MMM d').format(date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    timeSlot.isNotEmpty
                        ? '$timeSlot • $detailerName'
                        : detailerName,
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Colors.cyan)
                      : null,
                  onTap: () {
                    setState(() {
                      _selectedBookingId = bookingId;
                      _selectedDetailerId = data['assignedDetailerId'] ??
                          data['assignedEmployeeId'];
                      _selectedDetailerName = detailerName;
                    });
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// Star rating widget (unchanged)
class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _StarRating({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        return IconButton(
          iconSize: 48,
          icon: Icon(
            i < value ? Icons.star : Icons.star_border,
            color: Colors.amber,
          ),
          onPressed: () => onChanged(i + 1),
        );
      }),
    );
  }
}

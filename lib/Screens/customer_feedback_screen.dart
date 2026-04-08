import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart' as app_auth;
import '../core/models/review_model.dart';
import '../core/utils/alaska_date_utils.dart';

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

  Color get _accentColor => const Color(0xFF00E5FF);
  Color get _goldColor => const Color(0xFFFFD700);

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
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Give Feedback',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  Icon(Icons.favorite_rounded, size: 64, color: _accentColor),
                  const SizedBox(height: 12),
                  Text('Your opinion matters',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.3),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text('Help us make Polar Glow even better',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 40),
            Text('What would you like to review?',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 16),
            _buildTypeSelector(),
            const SizedBox(height: 40),
            if (_selectedType == ReviewType.service) ...[
              Text('Which service would you like to review?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.white)),
              const SizedBox(height: 16),
              _buildCompletedBookingsPicker(),
              const SizedBox(height: 40),
            ],
            Text('Overall rating',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 16),
            Center(
                child: _StarRating(
                    value: _rating,
                    onChanged: (val) => setState(() => _rating = val),
                    screenWidth: screenWidth)),
            const SizedBox(height: 40),
            Text('Tell us more (optional but super helpful)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 12),
            TextField(
              controller: _commentController,
              maxLines: 7,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'What did you love? What could be better?',
                hintStyle: const TextStyle(color: Colors.white38),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Colors.white24)),
                filled: true,
                fillColor: Colors.black12,
                contentPadding: const EdgeInsets.all(20),
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.send_rounded, size: 28),
                label: const Text('Submit Review',
                    style:
                        TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                style: FilledButton.styleFrom(
                    backgroundColor: _goldColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    elevation: 16,
                    shadowColor: _goldColor.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24))),
                onPressed: _submitReview,
              ),
            ),
            const SizedBox(height: 32),
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
        borderRadius: BorderRadius.circular(24),
        onTap: () => setState(() => _selectedType = type),
        child: Card(
          elevation: isSelected ? 16 : 6,
          shadowColor: isSelected
              ? _accentColor.withOpacity(0.6)
              : Colors.black.withOpacity(0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.grey[850],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 28),
            child: Column(
              children: [
                Icon(icon,
                    size: 48,
                    color: isSelected ? _accentColor : Colors.white70),
                const SizedBox(height: 14),
                Text(label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 15.5,
                        color: isSelected ? Colors.white : Colors.white70)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletedBookingsPicker() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Text('Please sign in',
          style: TextStyle(color: Colors.white70));
    }

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
          return Center(
              child: Text('Error: ${snapshot.error}',
                  style: const TextStyle(color: Colors.white70)));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)));
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Card(
            color: Colors.grey[850],
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Text(
                    'No completed bookings yet.\nBook a service and come back!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 16)),
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final bookingId = doc.id;

            // FIXED: Use same Alaska timezone conversion as My Bookings screen
            final utcDate = (data['date'] as Timestamp).toDate();
            final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);

            final timeSlot =
                data['cars']?[0]?['time'] ?? data['timeSlot'] ?? '';
            final detailerName = data['assignedDetailerName'] ??
                data['assignedEmployeeName'] ??
                'Detailer';

            final isSelected = _selectedBookingId == bookingId;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: isSelected ? 12 : 4,
              shadowColor: isSelected
                  ? _accentColor.withOpacity(0.5)
                  : Colors.black.withOpacity(0.3),
              color: isSelected ? Colors.grey[800] : Colors.grey[850],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(
                  DateFormat('EEEE, MMM d')
                      .format(alaskaDate), // now matches My Bookings
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      fontSize: 16),
                ),
                subtitle: Text(
                  timeSlot.isNotEmpty
                      ? '$timeSlot • $detailerName'
                      : detailerName,
                  style: const TextStyle(color: Colors.white70),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: _accentColor, size: 28)
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
        );
      },
    );
  }
}

// Responsive Star Rating (unchanged)
class _StarRating extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final double screenWidth;

  const _StarRating(
      {required this.value,
      required this.onChanged,
      required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final starSize = (screenWidth / 9).clamp(42.0, 52.0);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        return IconButton(
          iconSize: starSize,
          icon: Icon(i < value ? Icons.star : Icons.star_border,
              color: const Color(0xFFFFD700),
              shadows: [
                Shadow(
                    color: const Color(0xFFFFD700).withOpacity(0.7),
                    blurRadius: 14)
              ]),
          onPressed: () => onChanged(i + 1),
        );
      }),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/alaska_date_utils.dart';
import 'customer_feedback_screen.dart';

class CustomerMyBookingsScreen extends StatefulWidget {
  const CustomerMyBookingsScreen({super.key});

  @override
  State<CustomerMyBookingsScreen> createState() =>
      _CustomerMyBookingsScreenState();
}

class _CustomerMyBookingsScreenState extends State<CustomerMyBookingsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Color get _accentColor => const Color(0xFF00E5FF);
  Color get _goldColor => const Color(0xFFFFD700);

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return Scaffold(
        backgroundColor: Colors.grey[900],
        body: const Center(
          child: Text('Please sign in',
              style: TextStyle(color: Colors.white70, fontSize: 18)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'My Bookings',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: _currentUser!.uid)
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.calendar_today,
                        size: 80, color: _accentColor.withOpacity(0.4)),
                    const SizedBox(height: 24),
                    const Text(
                      'No bookings yet',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Tap "Book an Appointment" on the dashboard\nto get started!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.white70,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: bookings.length,
            itemBuilder: (context, index) {
              final doc = bookings[index];
              final data = doc.data() as Map<String, dynamic>;
              final bookingId = doc.id;
              final utcDate = (data['date'] as Timestamp).toDate();
              final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);
              final timeSlot =
                  data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'No time';
              final totalPrice = (data['totalPrice'] ?? 0.0).toDouble();
              final servicesCount = (data['services'] as List?)?.length ?? 0;
              final isPaid =
                  data['paid'] == true || data['paymentStatus'] == 'paid';
              final isCompleted = data['completed'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                elevation: 10,
                shadowColor: _accentColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                color: Colors.grey[850],
                child: ListTile(
                  contentPadding: const EdgeInsets.all(20),
                  leading: Icon(
                    Icons.event,
                    size: 52,
                    color: _accentColor,
                  ),
                  title: Text(
                    DateFormat('EEEE, MMMM d').format(alaskaDate),
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Text(
                        '$timeSlot • $servicesCount service${servicesCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '\$${totalPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: _accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          if (isPaid)
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 18),
                          if (isPaid) const SizedBox(width: 6),
                          Text(
                            isPaid ? 'Paid' : 'Unpaid',
                            style: TextStyle(
                              color: isPaid ? Colors.green : Colors.orange,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 16),
                          if (isCompleted)
                            const Icon(Icons.check_circle,
                                color: Colors.blue, size: 18),
                          if (isCompleted) const SizedBox(width: 6),
                          Text(
                            isCompleted ? 'Completed' : 'Upcoming',
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing:
                      const Icon(Icons.chevron_right, color: Colors.white54),
                  onTap: () => _showBookingDetails(
                      context, bookingId, data, isCompleted),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── Updated helper methods ──
  Future<String> _getEmployeeName(String? employeeId) async {
    if (employeeId == null || employeeId.isEmpty) return 'Unassigned';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return data['displayName'] ??
            data['fullName'] ??
            data['name'] ??
            (data['email']?.split('@')[0] ?? 'Unknown Employee');
      }
    } catch (_) {}
    return 'Unassigned';
  }

  Future<Map<String, String>> _getCustomerFullInfo(String? customerId) async {
    if (customerId == null || customerId.isEmpty)
      return {'name': 'Unknown', 'phone': 'N/A', 'email': 'N/A'};
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'name': data['displayName'] ??
              data['fullName'] ??
              data['name'] ??
              'No Name',
          'phone': data['phoneNumber'] ?? data['phone'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
        };
      }
    } catch (_) {}
    return {'name': 'Unknown', 'phone': 'N/A', 'email': 'N/A'};
  }

  void _showBookingDetails(BuildContext context, String bookingId,
      Map<String, dynamic> data, bool isCompleted) async {
    await _getCustomerFullInfo(data['customerId'] ?? data['customerEmail']);
    final employeeName = await _getEmployeeName(
        data['assignedEmployeeId'] ?? data['assignedDetailerId']);

    final addressController =
        TextEditingController(text: data['address'] ?? '');
    final notesController = TextEditingController(text: data['notes'] ?? '');

    if (!mounted) return;

    // FIXED: Convert to Alaska time so date matches the list view
    final utcDate = (data['date'] as Timestamp).toDate();
    final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Booking Details',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 24),
            _detailRow('Date',
                DateFormat('EEEE, MMMM d, yyyy').format(alaskaDate)), // ← FIXED
            _detailRow(
                'Time', data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'),
            _detailRow('Assigned to', employeeName),
            const SizedBox(height: 28),
            TextField(
              controller: addressController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Address',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Colors.black12,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: notesController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Notes',
                labelStyle: const TextStyle(color: Colors.white70),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                filled: true,
                fillColor: Colors.black12,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      await FirebaseFirestore.instance
                          .collection('bookings')
                          .doc(bookingId)
                          .update({
                        'address': addressController.text.trim(),
                        'notes': notesController.text.trim(),
                      });
                      if (mounted) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('✅ Booking updated')));
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: _accentColor,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),
            if (isCompleted) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.star, size: 26),
                  label: const Text(
                    'Write a Review',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _goldColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    elevation: 14,
                    shadowColor: _goldColor.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerFeedbackScreen(
                          preselectedBookingId: bookingId,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white54,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

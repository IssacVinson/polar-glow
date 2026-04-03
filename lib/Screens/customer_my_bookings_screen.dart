// lib/screens/customer_my_bookings_screen.dart
// UPDATED FILE — Replace your entire customer_my_bookings_screen.dart with this exact code

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/alaska_date_utils.dart';
import 'customer_feedback_screen.dart'; // ← NEW: hybrid feedback screen

class CustomerMyBookingsScreen extends StatefulWidget {
  const CustomerMyBookingsScreen({super.key});

  @override
  State<CustomerMyBookingsScreen> createState() =>
      _CustomerMyBookingsScreenState();
}

class _CustomerMyBookingsScreenState extends State<CustomerMyBookingsScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null) {
      return const Scaffold(body: Center(child: Text('Please sign in')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Bookings'),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('bookings')
            .where('customerId', isEqualTo: _currentUser!.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'You have no bookings yet.\nTap "Book an Appointment" to get started!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
            );
          }

          final bookings = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
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
              final isPaid = data['paid'] == true;
              final isCompleted = data['completed'] == true;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  leading:
                      const Icon(Icons.event, size: 48, color: Colors.cyan),
                  title: Text(
                    DateFormat('EEEE, MMMM d').format(alaskaDate),
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          '$timeSlot • $servicesCount service${servicesCount == 1 ? '' : 's'}'),
                      Text('\$${totalPrice.toStringAsFixed(2)}'),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          if (isPaid)
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 16),
                          if (isPaid) const SizedBox(width: 4),
                          Text(isPaid ? 'Paid' : 'Unpaid',
                              style: TextStyle(
                                  color:
                                      isPaid ? Colors.green : Colors.orange)),
                          const SizedBox(width: 12),
                          if (isCompleted)
                            const Icon(Icons.check_circle,
                                color: Colors.blue, size: 16),
                          if (isCompleted) const SizedBox(width: 4),
                          Text(isCompleted ? 'Completed' : '',
                              style: const TextStyle(color: Colors.blue)),
                        ],
                      ),
                    ],
                  ),
                  trailing: const Icon(Icons.chevron_right),
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

  // ── UPDATED: Now fetches real employee name ──
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

  void _showBookingDetails(BuildContext context, String bookingId,
      Map<String, dynamic> data, bool isCompleted) async {
    await _getCustomerFullInfo(data['customerId'] ?? data['customerEmail']);
    final employeeName = await _getEmployeeName(
        data['assignedEmployeeId'] ?? data['assignedDetailerId']);

    final addressController =
        TextEditingController(text: data['address'] ?? '');
    final notesController = TextEditingController(text: data['notes'] ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
                'Date: ${DateFormat('EEEE, MMMM d, yyyy').format((data['date'] as Timestamp).toDate())}'),
            Text(
                'Time: ${data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'}'),
            Text('Assigned to: $employeeName'), // ← Now shows real name!
            const SizedBox(height: 20),

            TextField(
              controller: addressController,
              decoration: const InputDecoration(
                  labelText: 'Address', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Notes', border: OutlineInputBorder()),
            ),

            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Cancel'))),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
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
                    child: const Text('Save Changes'),
                  ),
                ),
              ],
            ),

            if (isCompleted) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.star),
                  label: const Text('Write a Review'),
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.amber),
                  onPressed: () {
                    Navigator.pop(ctx); // close the details modal
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomerFeedbackScreen(
                          preselectedBookingId: bookingId, // ← hybrid magic
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
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
}

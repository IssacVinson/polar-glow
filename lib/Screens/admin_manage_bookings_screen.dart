import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/alaska_date_utils.dart';
import 'admin_schedule_calendar_screen.dart';

class AdminManageBookingsScreen extends StatefulWidget {
  const AdminManageBookingsScreen({super.key});

  @override
  State<AdminManageBookingsScreen> createState() =>
      _AdminManageBookingsScreenState();
}

class _AdminManageBookingsScreenState extends State<AdminManageBookingsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<String> _getCustomerDisplay(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return 'Unknown Customer';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final displayName =
            data['displayName'] ?? data['fullName'] ?? data['name'] ?? '';
        final email = data['email'] ?? '';
        if (displayName.isNotEmpty) return displayName;
        if (email.isNotEmpty && email.contains('@')) return email;
      }
    } catch (_) {}
    return customerId.length > 12
        ? '${customerId.substring(0, 12)}...'
        : customerId;
  }

  Future<Map<String, String>> _getCustomerFullInfo(String? customerId) async {
    if (customerId == null || customerId.isEmpty) {
      return {'name': 'Unknown', 'phone': 'N/A', 'email': 'N/A'};
    }
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
    return 'Unknown Employee';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Bookings'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            tooltip: 'Overall Schedule',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const AdminScheduleCalendarScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by customer name or email',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              onChanged: (value) =>
                  setState(() => _searchQuery = value.toLowerCase().trim()),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('bookings')
                  .orderBy('date', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No bookings yet'));
                }

                final bookings = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email =
                      (data['customerEmail'] ?? data['customerId'] ?? '')
                          .toString()
                          .toLowerCase();
                  return email.contains(_searchQuery);
                }).toList();

                if (bookings.isEmpty) {
                  return const Center(child: Text('No matching bookings'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: bookings.length,
                  itemBuilder: (context, index) {
                    final doc = bookings[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final bookingId = doc.id;
                    final customerId =
                        data['customerId'] ?? data['customerEmail'];
                    final utcDate = (data['date'] as Timestamp).toDate();
                    final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);
                    final timeSlot = data['cars']?[0]?['time'] ??
                        data['timeSlot'] ??
                        'No time';
                    final assignedEmployeeId = data['assignedEmployeeId'] ??
                        data['assignedDetailerId'];
                    final totalPrice = (data['totalPrice'] ?? 0.0).toDouble();
                    final servicesCount =
                        (data['services'] as List?)?.length ?? 0;
                    final isPaid = data['paid'] == true;
                    final isCompleted = data['completed'] == true;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: isCompleted
                          ? Colors.blue.withOpacity(0.08)
                          : (isPaid ? Colors.green.withOpacity(0.08) : null),
                      child: FutureBuilder<String>(
                        future: _getCustomerDisplay(customerId),
                        builder: (context, displaySnapshot) {
                          final displayName =
                              displaySnapshot.data ?? 'Loading...';

                          return ListTile(
                            leading: const Icon(Icons.event, size: 40),
                            title: Text(displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${DateFormat('MMM d, yyyy').format(alaskaDate)} at $timeSlot\n'
                              '$servicesCount service${servicesCount == 1 ? '' : 's'} • \$${totalPrice.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCompleted)
                                  const Icon(Icons.check_circle,
                                      color: Colors.blue, size: 20),
                                if (isPaid && !isCompleted)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 20),
                                const SizedBox(width: 8),
                                FutureBuilder<String>(
                                  future: _getEmployeeName(assignedEmployeeId),
                                  builder: (context, empSnapshot) {
                                    final employeeDisplay =
                                        empSnapshot.data ?? 'Loading...';
                                    return Text(employeeDisplay,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold));
                                  },
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'assign') {
                                      await _showAssignDialog(
                                          bookingId, assignedEmployeeId);
                                    } else if (value == 'paid') {
                                      await _togglePaid(bookingId, true);
                                    } else if (value == 'unpaid') {
                                      await _togglePaid(bookingId, false);
                                    } else if (value == 'complete') {
                                      await _toggleComplete(bookingId, true);
                                    } else if (value == 'incomplete') {
                                      await _toggleComplete(bookingId, false);
                                    } else if (value == 'cancel') {
                                      await _cancelBooking(bookingId);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'assign',
                                        child: Text('Assign Employee')),
                                    PopupMenuItem(
                                      value: isPaid ? 'unpaid' : 'paid',
                                      child: Text(
                                          isPaid
                                              ? 'Mark as Unpaid'
                                              : 'Mark as Paid',
                                          style: const TextStyle(
                                              color: Colors.green)),
                                    ),
                                    PopupMenuItem(
                                      value: isCompleted
                                          ? 'incomplete'
                                          : 'complete',
                                      child: Text(
                                          isCompleted
                                              ? 'Mark as Incomplete'
                                              : 'Mark as Complete',
                                          style: const TextStyle(
                                              color: Colors.blue)),
                                    ),
                                    const PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel Booking',
                                            style:
                                                TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _showBookingDetails(context, data,
                                displayName, customerId, assignedEmployeeId),
                          );
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _togglePaid(String bookingId, bool paid) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'paid': paid,
      'paidAt': paid ? FieldValue.serverTimestamp() : null,
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(paid ? '✅ Marked as Paid' : 'Marked as Unpaid')));
  }

  Future<void> _toggleComplete(String bookingId, bool completed) async {
    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'completed': completed,
      'completedAt': completed ? FieldValue.serverTimestamp() : null,
    });
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              completed ? '✅ Marked as Complete' : 'Marked as Incomplete')));
  }

  // Enhanced details modal with phone, address, assigned employee
  void _showBookingDetails(
    BuildContext context,
    Map<String, dynamic> data,
    String displayName,
    String? customerId,
    String? assignedEmployeeId,
  ) async {
    final customerInfo = await _getCustomerFullInfo(customerId);
    final employeeName = await _getEmployeeName(assignedEmployeeId);
    final utcDate = (data['date'] as Timestamp).toDate();
    final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Customer: ${customerInfo['name']}'),
            Text('Email: ${customerInfo['email']}'),
            Text('Phone: ${customerInfo['phone']}'),
            if (data['address'] != null) Text('Address: ${data['address']}'),
            Text('Date: ${DateFormat('MMM d, yyyy').format(alaskaDate)}'),
            Text(
                'Time: ${data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'}'),
            Text('Assigned to: $employeeName'),
            Text(
                'Total: \$${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}'),
            const SizedBox(height: 16),
            const Text('Services:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...((data['services'] as List?) ?? [])
                .map((s) => Text('• ${s['name']} (\$${s['price']})')),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              Text('Notes: ${data['notes']}'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close')),
            ),
          ],
        ),
      ),
    );
  }

  // Keep your existing _showAssignDialog and _cancelBooking (unchanged)
  Future<void> _showAssignDialog(
      String bookingId, String? currentEmployeeId) async {
    /* your original code */
  }
  Future<void> _cancelBooking(String bookingId) async {/* your original code */}
}

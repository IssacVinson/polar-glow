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

  Future<String> _getCustomerEmail(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return 'Unknown Customer';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final email = userDoc.data()?['email'] as String?;
        if (email != null && email.contains('@')) return email;
      }
    } catch (_) {}
    return customerId.length > 12
        ? '${customerId.substring(0, 12)}...'
        : customerId;
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
                labelText: 'Search by customer email',
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

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: FutureBuilder<String>(
                        future: _getCustomerEmail(customerId),
                        builder: (context, emailSnapshot) {
                          final displayEmail =
                              emailSnapshot.data ?? 'Loading...';

                          return ListTile(
                            leading: const Icon(Icons.event, size: 40),
                            title: Text(displayEmail,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${DateFormat('MMM d, yyyy').format(alaskaDate)} at $timeSlot\n'
                              '$servicesCount service${servicesCount == 1 ? '' : 's'} • \$${totalPrice.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  assignedEmployeeId == null
                                      ? 'Unassigned'
                                      : 'Assigned',
                                  style: TextStyle(
                                    color: assignedEmployeeId == null
                                        ? Colors.orange
                                        : Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert),
                                  onSelected: (value) async {
                                    if (value == 'assign') {
                                      await _showAssignDialog(
                                          bookingId, assignedEmployeeId);
                                    } else if (value == 'cancel') {
                                      await _cancelBooking(bookingId);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                        value: 'assign',
                                        child: Text('Assign Employee')),
                                    const PopupMenuItem(
                                        value: 'cancel',
                                        child: Text('Cancel Booking',
                                            style:
                                                TextStyle(color: Colors.red))),
                                  ],
                                ),
                              ],
                            ),
                            onTap: () => _showBookingDetails(
                                context, data, displayEmail),
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

  Future<void> _showAssignDialog(
      String bookingId, String? currentEmployeeId) async {
    final employeesSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    final employees = employeesSnap.docs.map((doc) {
      return {
        'id': doc.id,
        'name': doc['email']?.split('@')[0] ?? 'Employee',
      };
    }).toList();

    String? selectedId = currentEmployeeId;

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Assign Employee'),
              content: SizedBox(
                width: double.maxFinite,
                child: DropdownButtonFormField<String>(
                  initialValue: selectedId,
                  decoration:
                      const InputDecoration(labelText: 'Select Employee'),
                  items: employees.map((e) {
                    return DropdownMenuItem<String>(
                      value: e['id'] as String,
                      child: Text(e['name'] as String),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedId = val);
                  },
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                TextButton(
                  onPressed: selectedId == null
                      ? null
                      : () async {
                          await FirebaseFirestore.instance
                              .collection('bookings')
                              .doc(bookingId)
                              .update({'assignedEmployeeId': selectedId});
                          if (mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('✅ Employee assigned')),
                            );
                          }
                        },
                  child: const Text('Assign'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _cancelBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cancel Booking?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('No')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Yes, Cancel',
                  style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Booking cancelled')));
      }
    }
  }

  void _showBookingDetails(
      BuildContext context, Map<String, dynamic> data, String displayEmail) {
    final utcDate = (data['date'] as Timestamp).toDate();
    final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Customer: $displayEmail'),
            Text('Date: ${DateFormat('MMM d, yyyy').format(alaskaDate)}'),
            Text(
                'Time: ${data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'}'),
            Text(
                'Total: \$${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}'),
            const SizedBox(height: 24),
            const Text('Services:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...((data['services'] as List?) ?? [])
                .map((s) => Text('• ${s['name']} (\$${s['price']})')),
            if (data['address'] != null) Text('Address: ${data['address']}'),
            if (data['notes'] != null) Text('Notes: ${data['notes']}'),
          ],
        ),
      ),
    );
  }
}

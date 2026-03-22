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

  // ── UPDATED: Now prefers displayName (e.g. "Cassie"), falls back to email ──
  Future<String> _getCustomerDisplay(String? customerId) async {
    if (customerId == null || customerId.isEmpty) return 'Unknown Customer';

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final displayName = data['displayName'] ?? data['fullName'] ?? '';
        final email = data['email'] ?? '';

        if (displayName.isNotEmpty) return displayName;
        if (email.isNotEmpty && email.contains('@')) return email;
      }
    } catch (_) {}
    return customerId.length > 12
        ? '${customerId.substring(0, 12)}...'
        : customerId;
  }

  // (kept for employee name display – unchanged)
  Future<String> _getEmployeeName(String? employeeId) async {
    if (employeeId == null || employeeId.isEmpty) return 'Unassigned';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final name = data['displayName'] ??
            data['fullName'] ??
            data['name'] ??
            (data['email']?.split('@')[0] ?? 'Unknown Employee');
        return name;
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
                labelText: 'Search by customer name',
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

                final allBookings = snapshot.data!.docs;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: allBookings.length,
                  itemBuilder: (context, index) {
                    final doc = allBookings[index];
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

                    return FutureBuilder<String>(
                      future: _getCustomerDisplay(customerId),
                      builder: (context, displaySnapshot) {
                        final displayText =
                            displaySnapshot.data ?? 'Loading...';

                        // ── FIXED SEARCH: Only show after we resolve real name/email ──
                        if (_searchQuery.isNotEmpty &&
                            !displayText.toLowerCase().contains(_searchQuery)) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            leading: const Icon(Icons.event, size: 40),
                            title: Text(displayText,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${DateFormat('MMM d, yyyy').format(alaskaDate)} at $timeSlot\n'
                              '$servicesCount service${servicesCount == 1 ? '' : 's'} • \$${totalPrice.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FutureBuilder<String>(
                                  future: _getEmployeeName(assignedEmployeeId),
                                  builder: (context, empSnapshot) {
                                    final employeeDisplay =
                                        empSnapshot.data ?? 'Loading...';
                                    final isAssigned =
                                        assignedEmployeeId != null;
                                    return Text(
                                      employeeDisplay,
                                      style: TextStyle(
                                        color: isAssigned
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    );
                                  },
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
                            onTap: () =>
                                _showBookingDetails(context, data, displayText),
                          ),
                        );
                      },
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
      BuildContext context, Map<String, dynamic> data, String displayText) {
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
            Text('Customer: $displayText'),
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

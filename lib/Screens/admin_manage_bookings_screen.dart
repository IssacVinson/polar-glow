// lib/Screens/admin_manage_bookings_screen.dart
// UPGRADED: Premium dark theme with glowing cards + cyan accents
// FIXED + COMPLETED: Full implementation of _showAssignDialog and _cancelBooking
// Fully consistent with EmployeeDashboard + all upgraded admin screens

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

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Manage Bookings',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_rounded),
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
          // Premium glowing search bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shadowColor: _accentColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Colors.grey[850],
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                onChanged: (value) =>
                    setState(() => _searchQuery = value.toLowerCase().trim()),
                decoration: InputDecoration(
                  labelText: 'Search by customer name or email',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: _accentColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[850],
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
              ),
            ),
          ),

          // Bookings list
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
                  return const Center(
                      child: Text('No bookings yet',
                          style: TextStyle(color: Colors.white70)));
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
                  return const Center(
                      child: Text('No matching bookings',
                          style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 16,
                      shadowColor: _accentColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      color: Colors.grey[850],
                      child: FutureBuilder<String>(
                        future: _getCustomerDisplay(customerId),
                        builder: (context, displaySnapshot) {
                          final displayName =
                              displaySnapshot.data ?? 'Loading...';

                          return ListTile(
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 20 : 24,
                                vertical: isSmallScreen ? 12 : 16),
                            leading: Icon(Icons.event_rounded,
                                size: 42, color: _accentColor),
                            title: Text(
                              displayName,
                              style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white),
                            ),
                            subtitle: Text(
                              '${DateFormat('MMM d, yyyy').format(alaskaDate)} at $timeSlot\n'
                              '$servicesCount service${servicesCount == 1 ? '' : 's'} • \$${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCompleted)
                                  const Icon(Icons.check_circle,
                                      color: Colors.blue, size: 22),
                                if (isPaid && !isCompleted)
                                  const Icon(Icons.check_circle,
                                      color: Colors.green, size: 22),
                                const SizedBox(width: 12),
                                FutureBuilder<String>(
                                  future: _getEmployeeName(assignedEmployeeId),
                                  builder: (context, empSnapshot) {
                                    final employeeDisplay =
                                        empSnapshot.data ?? 'Unassigned';
                                    return Text(
                                      employeeDisplay,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white70),
                                    );
                                  },
                                ),
                                const SizedBox(width: 8),
                                PopupMenuButton<String>(
                                  icon: const Icon(Icons.more_vert,
                                      color: Colors.white70),
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

  // Enhanced details modal
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            Text('Customer: ${customerInfo['name']}',
                style: const TextStyle(color: Colors.white70)),
            Text('Email: ${customerInfo['email']}',
                style: const TextStyle(color: Colors.white70)),
            Text('Phone: ${customerInfo['phone']}',
                style: const TextStyle(color: Colors.white70)),
            if (data['address'] != null)
              Text('Address: ${data['address']}',
                  style: const TextStyle(color: Colors.white70)),
            Text('Date: ${DateFormat('MMM d, yyyy').format(alaskaDate)}',
                style: const TextStyle(color: Colors.white70)),
            Text(
                'Time: ${data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.white70)),
            Text('Assigned to: $employeeName',
                style: const TextStyle(color: Colors.white70)),
            Text('Total: \$${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(color: _accentColor, fontSize: 18)),
            const SizedBox(height: 20),
            const Text('Services:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            ...((data['services'] as List?) ?? []).map((s) => Text(
                '• ${s['name']} (\$${s['price']})',
                style: const TextStyle(color: Colors.white70))),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              Text('Notes: ${data['notes']}',
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── COMPLETE: Assign Employee Dialog ──
  Future<void> _showAssignDialog(
      String bookingId, String? currentEmployeeId) async {
    final employeesSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    if (!mounted) return;

    final selectedEmployee = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Assign Employee',
            style: TextStyle(color: Colors.white)),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: employeesSnap.docs.length,
            itemBuilder: (context, index) {
              final emp = employeesSnap.docs[index];
              final empId = emp.id;
              final name = emp['displayName'] ?? emp['email'] ?? 'Employee';
              final isSelected = empId == currentEmployeeId;

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: _accentColor.withOpacity(0.2),
                  child: Text(name[0].toUpperCase(),
                      style: TextStyle(color: _accentColor)),
                ),
                title: Text(name, style: const TextStyle(color: Colors.white)),
                trailing: isSelected
                    ? Icon(Icons.check_circle, color: _accentColor)
                    : null,
                onTap: () => Navigator.pop(ctx, empId),
              );
            },
          ),
        ),
      ),
    );

    if (selectedEmployee == null || !mounted) return;

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({'assignedEmployeeId': selectedEmployee});

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Employee assigned')));
    }
  }

  // ── COMPLETE: Cancel Booking ──
  Future<void> _cancelBooking(String bookingId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Cancel Booking?',
            style: TextStyle(color: Colors.white)),
        content: const Text(
            'This action cannot be undone.\nThe booking will be marked as cancelled.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Keep Booking')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Booking',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('✅ Booking cancelled')));
    }
  }
}

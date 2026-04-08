// lib/Screens/admin_schedule_calendar_screen.dart
// FIXED: Now automatically loads details for the initially selected day (today/focused day)
// No more "No bookings on this day" on first load when opening Overall Schedule
// Green bubbles = available slots | Orange bubbles = bookings

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../core/utils/alaska_date_utils.dart';

class AdminScheduleCalendarScreen extends StatefulWidget {
  const AdminScheduleCalendarScreen({
    super.key,
    this.employeeId,
    this.showAppBar = true,
  });

  final String? employeeId;
  final bool showAppBar;

  @override
  State<AdminScheduleCalendarScreen> createState() =>
      _AdminScheduleCalendarScreenState();
}

class _AdminScheduleCalendarScreenState
    extends State<AdminScheduleCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, int> _bookingCounts = {};
  Map<DateTime, int> _availabilitySlotCounts = {};

  List<Map<String, dynamic>> _bookingsForSelectedDay = [];
  List<Map<String, dynamic>> _availabilityForSelectedDay = [];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllCalendarData();
    _loadDayDetails(_selectedDay!); // ← Auto-loads today on first open
  }

  Future<void> _loadAllCalendarData() async {
    final startStorage = AlaskaDateUtils.toAlaskaStorageDate(
        _focusedDay.subtract(const Duration(days: 365)));
    final endStorage = AlaskaDateUtils.toAlaskaStorageDate(
        _focusedDay.add(const Duration(days: 365)));

    final Map<DateTime, int> bookingCounts = {};
    final Map<DateTime, int> slotCounts = {};

    final bookingsSnapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startStorage))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endStorage))
        .get();

    for (var doc in bookingsSnapshot.docs) {
      final data = doc.data();
      final ts = (data['date'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      if (widget.employeeId != null &&
          data['assignedDetailerId'] != widget.employeeId) continue;

      final dayKey = AlaskaDateUtils.toAlaskaDayKey(ts);
      bookingCounts[dayKey] = (bookingCounts[dayKey] ?? 0) + 1;
    }

    final employeesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    for (var empDoc in employeesSnapshot.docs) {
      if (widget.employeeId != null && empDoc.id != widget.employeeId) continue;
      final availabilitySnapshot =
          await empDoc.reference.collection('availability').get();

      for (var availDoc in availabilitySnapshot.docs) {
        final slots = List<String>.from(availDoc.data()['timeSlots'] ?? []);
        if (slots.isNotEmpty) {
          final date = DateTime.parse(availDoc.id);
          final dayKey = DateTime(date.year, date.month, date.day);
          slotCounts[dayKey] = (slotCounts[dayKey] ?? 0) + slots.length;
        }
      }
    }

    if (mounted) {
      setState(() {
        _bookingCounts = bookingCounts;
        _availabilitySlotCounts = slotCounts;
      });
    }
  }

  Future<void> _loadDayDetails(DateTime day) async {
    final storageDate = AlaskaDateUtils.toAlaskaStorageDate(day);

    var bookingQuery = FirebaseFirestore.instance
        .collection('bookings')
        .where('date', isEqualTo: Timestamp.fromDate(storageDate));

    if (widget.employeeId != null) {
      bookingQuery = bookingQuery.where('assignedDetailerId',
          isEqualTo: widget.employeeId);
    }

    final bookingSnap = await bookingQuery.get();

    final List<Map<String, dynamic>> bookings = [];
    for (var doc in bookingSnap.docs) {
      final data = doc.data();

      // Real customer name
      String customerName = data['customerEmail'] ?? 'Unknown';
      final customerId = data['customerId'] as String?;
      if (customerId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (userDoc.exists) {
          final u = userDoc.data()!;
          customerName =
              u['displayName'] ?? u['fullName'] ?? u['email'] ?? customerName;
        }
      }

      // Real detailer name
      String detailerName = 'Unassigned';
      final assignedId = data['assignedDetailerId'] as String?;
      if (assignedId != null) {
        final empDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(assignedId)
            .get();
        if (empDoc.exists) {
          final e = empDoc.data()!;
          detailerName =
              e['displayName'] ?? e['fullName'] ?? e['email'] ?? 'Unassigned';
        }
      }

      bookings.add({
        'id': doc.id,
        ...data,
        'customerName': customerName,
        'detailerName': detailerName,
      });
    }

    // Availability
    final List<Map<String, dynamic>> availList = [];
    final employeesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    for (var empDoc in employeesSnapshot.docs) {
      if (widget.employeeId != null && empDoc.id != widget.employeeId) continue;

      final dateStr = AlaskaDateUtils.toDateString(day);
      final availDoc =
          await empDoc.reference.collection('availability').doc(dateStr).get();

      if (availDoc.exists) {
        final slots = List<String>.from(availDoc.data()?['timeSlots'] ?? []);
        if (slots.isNotEmpty) {
          final name = empDoc.data()['displayName'] ??
              empDoc.data()['fullName'] ??
              empDoc.data()['email'] ??
              'Unknown Employee';

          availList.add({
            'employeeName': name,
            'slots': slots,
          });
        }
      }
    }

    if (mounted) {
      setState(() {
        _bookingsForSelectedDay = bookings;
        _availabilityForSelectedDay = availList;
      });
    }
  }

  void _showBookingDetails(Map<String, dynamic> booking) async {
    final customerId = booking['customerId'] as String?;
    String customerName =
        booking['customerName'] ?? booking['customerEmail'] ?? 'Unknown';
    String customerPhone = '';
    String customerEmail = booking['customerEmail'] ?? '';

    String detailerName = booking['detailerName'] ?? 'Unassigned';

    if (customerId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final u = userDoc.data()!;
        customerName = u['displayName'] ?? u['fullName'] ?? customerName;
        customerPhone = u['phoneNumber'] ?? u['phone'] ?? '';
        customerEmail = u['email'] ?? customerEmail;
      }
    }

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: SingleChildScrollView(
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
              const SizedBox(height: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy • h:mm a').format(
                  AlaskaDateUtils.toAlaskaDayKey(
                      (booking['date'] as Timestamp).toDate()),
                ),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              _detailRow('Customer', customerName),
              if (customerPhone.isNotEmpty) _detailRow('Phone', customerPhone),
              if (customerEmail.isNotEmpty) _detailRow('Email', customerEmail),
              _detailRow('Detailer', detailerName),
              _detailRow('Address', booking['address'] ?? '—'),
              const Divider(height: 32),
              const Text('Services',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...(booking['services'] as List? ?? []).map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• ${s['name']} (\$${s['price']})',
                      style: const TextStyle(color: Colors.white70),
                    ),
                  )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Total', style: TextStyle(fontSize: 18)),
                  Text(
                    '\$${(booking['totalPrice'] ?? 0.0).toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ],
              ),
              if (booking['notes']?.toString().isNotEmpty == true) ...[
                const SizedBox(height: 24),
                const Text('Notes',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(booking['notes'],
                    style: const TextStyle(color: Colors.white70)),
              ],
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close'),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: Colors.white54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final calendarCard = Card(
      margin: const EdgeInsets.all(16),
      elevation: 8,
      shadowColor: const Color(0xFF00E5FF).withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            _loadDayDetails(selectedDay);
          },
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
          calendarFormat: CalendarFormat.month,
          calendarBuilders: CalendarBuilders(
            markerBuilder: (context, day, _) {
              final dayKey = DateTime(day.year, day.month, day.day);
              final bookingCount = _bookingCounts[dayKey] ?? 0;
              final slotCount = _availabilitySlotCounts[dayKey] ?? 0;

              if (bookingCount == 0 && slotCount == 0) return null;

              return Positioned(
                right: 4,
                top: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (slotCount > 0)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          slotCount.toString(),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 2),
                    if (bookingCount > 0)
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          bookingCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );

    final content = _selectedDay == null
        ? const Center(child: Text('Select a day above'))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.employeeId == null
                      ? 'All Employees'
                      : 'Employee Schedule',
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF00E5FF)),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                if (_bookingsForSelectedDay.isNotEmpty) ...[
                  const Text('📅 Scheduled Bookings',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._bookingsForSelectedDay.map((data) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.grey[850],
                        child: ListTile(
                          leading: const Icon(Icons.event_busy,
                              color: Colors.orange),
                          title: Text(
                              '${data['cars']?[0]?['time'] ?? 'No time'} — ${data['customerName']}'),
                          subtitle: Text(
                              'Detailer: ${data['detailerName']} \n${data['cars']?[0]?['vehicle'] ?? ''} • \$${data['totalPrice'] ?? 0}'),
                          onTap: () => _showBookingDetails(data),
                        ),
                      )),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No bookings on this day'),
                  ),
                if (_availabilityForSelectedDay.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('🟢 Available Time Slots',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00E5FF))),
                  const SizedBox(height: 12),
                  ..._availabilityForSelectedDay.map((emp) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp['employeeName'],
                            style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white70),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: (emp['slots'] as List<String>)
                                .map((slot) => Chip(
                                      label: Text(slot),
                                      backgroundColor:
                                          Colors.green.withOpacity(0.2),
                                      labelStyle:
                                          const TextStyle(color: Colors.white),
                                    ))
                                .toList(),
                          ),
                          const SizedBox(height: 16),
                        ],
                      )),
                ],
              ],
            ),
          );

    if (!widget.showAppBar) {
      return Column(
        children: [calendarCard, Expanded(child: content)],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeId == null
            ? 'Overall Schedule'
            : 'Employee Schedule'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          calendarCard,
          Expanded(child: content),
        ],
      ),
    );
  }
}

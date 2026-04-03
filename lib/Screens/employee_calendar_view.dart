import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';
import '../core/utils/alaska_date_utils.dart';
import 'employee_availability_screen.dart';

class EmployeeCalendarView extends StatefulWidget {
  const EmployeeCalendarView({super.key});

  @override
  State<EmployeeCalendarView> createState() => _EmployeeCalendarViewState();
}

class _EmployeeCalendarViewState extends State<EmployeeCalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Map<String, dynamic>> _bookingsForSelectedDay = [];
  Map<DateTime, int> _bookingCounts = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllBookingCounts();
  }

  Future<void> _loadAllBookingCounts() async {
    final uid = context.read<AuthProvider>().user!.uid;

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .get();

    final Map<DateTime, int> counts = {};

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final timestamp = (data['date'] as Timestamp?)?.toDate();
      if (timestamp == null) continue;

      final alaskaDay = AlaskaDateUtils.toAlaskaDayKey(timestamp);
      final dayKey = DateTime(alaskaDay.year, alaskaDay.month, alaskaDay.day);

      counts[dayKey] = (counts[dayKey] ?? 0) + 1;
    }

    if (mounted) {
      setState(() {
        _bookingCounts = counts;
      });
    }
  }

  Future<void> _loadBookingsForDay(DateTime day) async {
    final uid = context.read<AuthProvider>().user!.uid;
    final storageDate = AlaskaDateUtils.toAlaskaStorageDate(day);

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .where('date', isEqualTo: Timestamp.fromDate(storageDate))
        .get();

    final List<Map<String, dynamic>> loaded = [];

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final customerId = data['customerId'] as String?;

      String customerName = 'Unknown';
      String customerPhone = '';
      String customerEmail = '';

      if (customerId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (userDoc.exists) {
          final u = userDoc.data()!;
          customerName = u['displayName'] ?? u['username'] ?? 'Unknown';
          customerPhone = u['phoneNumber'] ?? '';
          customerEmail = u['email'] ?? '';
        }
      }

      loaded.add({
        'id': doc.id,
        'time': data['cars']?[0]?['time'] ?? data['time'] ?? 'No time',
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'address': data['address'] ?? 'No address',
        'car': data['cars']?[0]?['vehicle'] ?? 'No car',
        'services':
            (data['services'] as List?)?.map((s) => s['name']).join(', ') ??
                'No services',
        'total': (data['totalPrice'] ?? 0.0).toStringAsFixed(2),
        'notes': data['notes'] ?? '',
      });
    }

    if (mounted) {
      setState(() {
        _bookingsForSelectedDay = loaded;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeAvailabilityScreen()),
        ).then((_) {
          _loadAllBookingCounts();
          if (_selectedDay != null) _loadBookingsForDay(_selectedDay!);
        }),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Recurring Availability'),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: TableCalendar(
                    firstDay: DateTime.now().subtract(const Duration(days: 60)),
                    lastDay: DateTime.now().add(const Duration(days: 400)),
                    focusedDay: _focusedDay,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      _loadBookingsForDay(selectedDay);
                    },
                    headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                    ),
                    calendarFormat: CalendarFormat.month,
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, _) {
                        final count = _bookingCounts[
                                DateTime(day.year, day.month, day.day)] ??
                            0;
                        if (count > 0) {
                          return Positioned(
                            right: 4,
                            top: 4,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.orange,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                count.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }
                        return null;
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 8),
                child: Text(
                  _selectedDay != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)
                      : 'Select a day to view bookings',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
          if (_selectedDay != null && _bookingsForSelectedDay.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final booking = _bookingsForSelectedDay[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ExpansionTile(
                        leading:
                            const Icon(Icons.event_busy, color: Colors.orange),
                        title: Text(
                            '${booking['time']} - ${booking['customerName']}'),
                        subtitle:
                            Text('${booking['car']} • \$${booking['total']}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Customer: ${booking['customerName']}'),
                                if (booking['customerPhone'].isNotEmpty)
                                  Text('Phone: ${booking['customerPhone']}'),
                                if (booking['customerEmail'].isNotEmpty)
                                  Text('Email: ${booking['customerEmail']}'),
                                Text('Address: ${booking['address']}'),
                                Text('Car: ${booking['car']}'),
                                Text('Services: ${booking['services']}'),
                                if (booking['notes'].isNotEmpty)
                                  Text('Notes: ${booking['notes']}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: _bookingsForSelectedDay.length,
                ),
              ),
            )
          else if (_selectedDay != null)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No bookings on this day'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

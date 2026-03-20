import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

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

  // Bookings and availability stored by consistent UTC day key
  Map<DateTime, List<Map<String, dynamic>>> _bookings = {};
  Map<DateTime, List<String>> _availabilitySlots = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  // Create a consistent UTC day key (midnight) to prevent timezone shifts
  DateTime _toDayKey(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day);
  }

  Future<void> _loadEvents() async {
    final start = _focusedDay.subtract(const Duration(days: 30));
    final end = _focusedDay.add(const Duration(days: 30));

    final Map<DateTime, List<Map<String, dynamic>>> newBookings = {};
    final Map<DateTime, List<String>> newAvailability = {};

    try {
      // Load Bookings
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end))
          .get();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp;
        final date = timestamp.toDate();
        final dayKey = _toDayKey(date); // ← FIXED: consistent UTC key

        if (widget.employeeId == null ||
            data['assignedDetailerId'] == widget.employeeId) {
          newBookings.update(
            dayKey,
            (list) => list..add(data),
            ifAbsent: () => [data],
          );
        }
      }

      // Load Availability
      final employeesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      for (var empDoc in employeesSnapshot.docs) {
        if (widget.employeeId != null && empDoc.id != widget.employeeId)
          continue;

        final availabilitySnapshot =
            await empDoc.reference.collection('availability').get();

        for (var availDoc in availabilitySnapshot.docs) {
          final dateStr = availDoc.id;
          final date = DateTime.parse(dateStr);
          if (date.isBefore(start) || date.isAfter(end)) continue;

          final data = availDoc.data();
          final slots = List<String>.from(data['timeSlots'] ?? []);

          if (slots.isNotEmpty) {
            final dayKey = _toDayKey(date);
            newAvailability.update(
              dayKey,
              (list) => list..addAll(slots),
              ifAbsent: () => List.from(slots),
            );
          }
        }
      }

      if (mounted) {
        setState(() {
          _bookings = newBookings;
          _availabilitySlots = newAvailability;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  int _getBookingCount(DateTime day) {
    final dayKey = _toDayKey(day);
    return _bookings[dayKey]?.length ?? 0;
  }

  List<Map<String, dynamic>> _getBookingsForDay(DateTime day) {
    final dayKey = _toDayKey(day);
    return _bookings[dayKey] ?? [];
  }

  List<String> _getAvailabilityForDay(DateTime day) {
    final dayKey = _toDayKey(day);
    return _availabilitySlots[dayKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final body = Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: TableCalendar(
            firstDay: DateTime.now().subtract(const Duration(days: 7)),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, _) {
                final bookingCount = _getBookingCount(day);
                if (bookingCount > 0) {
                  return Positioned(
                    right: 6,
                    top: 6,
                    child: Container(
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
                  );
                }
                return null;
              },
            ),
          ),
        ),
        if (_selectedDay != null) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),

          // Scheduled Bookings
          if (_getBookingCount(_selectedDay!) > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('📅 Scheduled Bookings',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _getBookingsForDay(_selectedDay!).length,
                itemBuilder: (context, index) {
                  final data = _getBookingsForDay(_selectedDay!)[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading:
                          const Icon(Icons.event_busy, color: Colors.orange),
                      title: Text(
                          '${data['cars']?[0]?['time'] ?? 'No time'} — ${data['customerEmail'] ?? 'Customer'}'),
                      subtitle: Text(
                          '${data['cars']?[0]?['vehicle'] ?? ''} • \$${data['totalPrice'] ?? 0}'),
                    ),
                  );
                },
              ),
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No bookings on this day'),
            ),

          // Open Availability
          if (_getAvailabilityForDay(_selectedDay!).isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('🟢 Open Availability',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Wrap(
                spacing: 8,
                children: _getAvailabilityForDay(_selectedDay!)
                    .map((slot) => Chip(
                          label: Text(slot),
                          backgroundColor: Colors.green.withOpacity(0.2),
                        ))
                    .toList(),
              ),
            ),
          ],
        ],
      ],
    );

    if (!widget.showAppBar) return body;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.employeeId == null
            ? 'Overall Schedule'
            : 'Employee Schedule'),
        centerTitle: true,
      ),
      body: body,
    );
  }
}

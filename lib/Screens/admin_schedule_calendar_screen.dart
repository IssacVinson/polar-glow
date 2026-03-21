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

  Map<DateTime, List<Map<String, dynamic>>> _bookings = {};
  Map<DateTime, List<String>> _availabilitySlots = {};

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final startDate = _focusedDay.subtract(const Duration(days: 30));
    final endDate = _focusedDay.add(const Duration(days: 30));

    final startStorage = AlaskaDateUtils.toAlaskaStorageDate(startDate);
    final endStorage = AlaskaDateUtils.toAlaskaStorageDate(endDate);

    final Map<DateTime, List<Map<String, dynamic>>> newBookings = {};
    final Map<DateTime, List<String>> newAvailability = {};

    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startStorage))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endStorage))
          .get();

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['date'] as Timestamp;
        final date = timestamp.toDate();
        final dayKey = AlaskaDateUtils.toAlaskaDayKey(date);

        if (widget.employeeId == null ||
            data['assignedDetailerId'] == widget.employeeId) {
          newBookings.update(
            dayKey,
            (list) => list..add(data),
            ifAbsent: () => [data],
          );
        }
      }

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
          try {
            final date = DateTime.parse(dateStr);
            if (date.isBefore(startDate) || date.isAfter(endDate)) continue;

            final data = availDoc.data();
            final slots = List<String>.from(data['timeSlots'] ?? []);

            if (slots.isNotEmpty) {
              final dayKey = DateTime.parse(dateStr);
              newAvailability.update(
                dayKey,
                (list) => list..addAll(slots),
                ifAbsent: () => List.from(slots),
              );
            }
          } catch (_) {}
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

  List<String> _getAvailabilityForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    final rawSlots = _availabilitySlots[dayKey] ?? [];

    final sorted = List<String>.from(rawSlots);
    sorted.sort((a, b) {
      final minutesA = _parseStartMinutes(a);
      final minutesB = _parseStartMinutes(b);
      return minutesA.compareTo(minutesB);
    });

    return sorted;
  }

  int _parseStartMinutes(String slot) {
    try {
      final parts = slot.split(' – ');
      final startStr = parts[0].trim();
      final format = DateFormat('h:mm a');
      final dt = format.parse(startStr);
      return dt.hour * 60 + dt.minute;
    } catch (_) {
      return 0;
    }
  }

  int _getBookingCount(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _bookings[dayKey]?.length ?? 0;
  }

  List<Map<String, dynamic>> _getBookingsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _bookings[dayKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final calendarCard = Card(
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
    );

    final content = _selectedDay == null
        ? const Center(child: Text('Select a day above'))
        : SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                if (_getBookingCount(_selectedDay!) > 0) ...[
                  const Text('📅 Scheduled Bookings',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ..._getBookingsForDay(_selectedDay!).map((data) => Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const Icon(Icons.event_busy,
                              color: Colors.orange),
                          title: Text(
                              '${data['cars']?[0]?['time'] ?? 'No time'} — ${data['customerEmail'] ?? 'Customer'}'),
                          subtitle: Text(
                              '${data['cars']?[0]?['vehicle'] ?? ''} • \$${data['totalPrice'] ?? 0}'),
                        ),
                      )),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No bookings on this day'),
                  ),
                if (_getAvailabilityForDay(_selectedDay!).isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('🟢 Open Availability',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _getAvailabilityForDay(_selectedDay!)
                        .map((slot) => Chip(
                              label: Text(slot),
                              backgroundColor: Colors.green.withOpacity(0.2),
                            ))
                        .toList(),
                  ),
                ],
              ],
            ),
          );

    // Embedded mode (used inside employee details tab)
    if (!widget.showAppBar) {
      return Column(
        children: [
          calendarCard,
          Expanded(child: content),
        ],
      );
    }

    // Full screen mode
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

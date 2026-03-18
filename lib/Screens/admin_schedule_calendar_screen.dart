import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

class AdminScheduleCalendarScreen extends StatefulWidget {
  const AdminScheduleCalendarScreen({super.key, this.employeeId});

  final String? employeeId; // null for overall, specific ID for per-employee

  @override
  State<AdminScheduleCalendarScreen> createState() =>
      _AdminScheduleCalendarScreenState();
}

class _AdminScheduleCalendarScreenState
    extends State<AdminScheduleCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Map<DateTime, List<dynamic>> _events =
      {}; // date → list of bookings/availability

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final start = _focusedDay.subtract(const Duration(days: 30));
    final end = _focusedDay.add(const Duration(days: 30));

    try {
      final bookingsSnapshot = await FirebaseFirestore.instance
          .collection('bookings')
          .where('date', isGreaterThanOrEqualTo: start)
          .where('date', isLessThanOrEqualTo: end)
          .get();

      Map<DateTime, List<dynamic>> events = {};

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dayKey = DateTime(date.year, date.month, date.day);

        if (widget.employeeId == null ||
            data['assignedEmployeeId'] == widget.employeeId) {
          events.update(
            dayKey,
            (list) => list..add({'type': 'booking', 'data': data}),
            ifAbsent: () => [
              {'type': 'booking', 'data': data},
            ],
          );
        }
      }

      // Add availability (per employee or all)
      final employeesSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      for (var empDoc in employeesSnapshot.docs) {
        if (widget.employeeId != null && empDoc.id != widget.employeeId) {
          continue;
        }

        final availabilitySnapshot = await empDoc.reference
            .collection('availability')
            .get();

        for (var availDoc in availabilitySnapshot.docs) {
          final date = DateTime.parse(availDoc.id); // id = 'yyyy-MM-dd'
          if (date.isAfter(start) && date.isBefore(end)) {
            final data = availDoc.data();
            events.update(
              date,
              (list) => list
                ..add({
                  'type': 'availability',
                  'data': data,
                  'employeeId': empDoc.id,
                }),
              ifAbsent: () => [
                {'type': 'availability', 'data': data, 'employeeId': empDoc.id},
              ],
            );
          }
        }
      }

      if (mounted) {
        setState(() => _events = events);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final dayKey = DateTime(day.year, day.month, day.day);
    return _events[dayKey] ?? [];
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.employeeId == null ? 'Overall Schedule' : 'Employee Schedule',
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.now(),
              lastDay: DateTime.now().add(const Duration(days: 90)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              eventLoader: _getEventsForDay,
              calendarStyle: CalendarStyle(
                weekendTextStyle: TextStyle(color: colorScheme.error),
                todayDecoration: BoxDecoration(
                  color: colorScheme.primary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          if (_selectedDay != null) ...[
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _getEventsForDay(_selectedDay!).length,
                itemBuilder: (context, index) {
                  final event = _getEventsForDay(_selectedDay!)[index];
                  if (event['type'] == 'booking') {
                    final data = event['data'];
                    return ListTile(
                      title: Text('Booking at ${data['time']}'),
                      subtitle: Text('Customer: ${data['customerEmail']}'),
                    );
                  } else if (event['type'] == 'availability') {
                    final data = event['data'];
                    return ListTile(
                      title: Text('Availability'),
                      subtitle: Text('Slots: ${data['timeSlots'].join(', ')}'),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

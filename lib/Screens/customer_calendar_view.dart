import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/utils/alaska_date_utils.dart';

class CustomerCalendarView extends StatefulWidget {
  final String selectedRegion;
  final Function(DateTime, DateTime) onDaySelected;
  final DateTime? selectedDay;
  final DateTime focusedDay;

  const CustomerCalendarView({
    super.key,
    required this.selectedRegion,
    required this.onDaySelected,
    required this.selectedDay,
    required this.focusedDay,
  });

  @override
  State<CustomerCalendarView> createState() => _CustomerCalendarViewState();
}

class _CustomerCalendarViewState extends State<CustomerCalendarView> {
  Map<DateTime, int> _availableSlotCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailableSlotCounts();
  }

  Future<void> _loadAvailableSlotCounts() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 2, 0);

    final Map<DateTime, int> counts = {};

    final employeeSnap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    for (var empDoc in employeeSnap.docs) {
      final empId = empDoc.id;

      final availSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(empId)
          .collection('availability')
          .where(FieldPath.documentId,
              isGreaterThanOrEqualTo: AlaskaDateUtils.toDateString(start))
          .where(FieldPath.documentId,
              isLessThanOrEqualTo: AlaskaDateUtils.toDateString(end))
          .get();

      for (var doc in availSnap.docs) {
        final data = doc.data();
        final regions = List<String>.from(data['regions'] ?? []);
        final timeSlots = List<String>.from(data['timeSlots'] ?? []);

        if (!regions.contains(widget.selectedRegion) || timeSlots.isEmpty)
          continue;

        final dateStr = doc.id;
        final date = DateTime.parse(dateStr);
        final dayKey = DateTime(date.year, date.month, date.day);

        final storageDate = AlaskaDateUtils.toAlaskaStorageDate(date);
        final bookedSnap = await FirebaseFirestore.instance
            .collection('bookings')
            .where('assignedDetailerId', isEqualTo: empId)
            .where('date', isEqualTo: Timestamp.fromDate(storageDate))
            .get();

        final freeSlots = timeSlots.length - bookedSnap.size;
        if (freeSlots > 0) {
          counts[dayKey] = (counts[dayKey] ?? 0) + freeSlots;
        }
      }
    }

    if (mounted) {
      setState(() {
        _availableSlotCounts = counts;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return TableCalendar(
      firstDay: DateTime.now(),
      lastDay: DateTime.now().add(const Duration(days: 365)),
      focusedDay: widget.focusedDay,
      selectedDayPredicate: (day) => isSameDay(widget.selectedDay, day),
      onDaySelected: widget.onDaySelected,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
      ),
      calendarFormat: CalendarFormat.month,
      availableGestures: AvailableGestures
          .none, // ← ONLY chevron buttons work for month change
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, day, _) {
          final count =
              _availableSlotCounts[DateTime(day.year, day.month, day.day)] ?? 0;
          if (count > 0) {
            return Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.green,
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
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        selectedDecoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

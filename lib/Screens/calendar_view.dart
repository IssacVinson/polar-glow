import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarView extends StatefulWidget {
  final String? selectedDetailerId;

  const CalendarView({super.key, this.selectedDetailerId});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _selectedDay = DateTime.now();
  Map<String, int> _availableDetailers = {}; // slot: count

  @override
  void initState() {
    super.initState();
    _loadAvailableSlots(_selectedDay);
  }

  Future<void> _loadAvailableSlots(DateTime day) async {
    final formattedDate = DateFormat('yyyy-MM-DD').format(day);
    final employeesSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    Map<String, int> slotCounts = {};
    for (var employeeDoc in employeesSnapshot.docs) {
      if (widget.selectedDetailerId != null &&
          employeeDoc.id != widget.selectedDetailerId) {
        continue;
      }

      final availabilityDoc = await employeeDoc.reference
          .collection('availability')
          .doc(formattedDate)
          .get();
      if (availabilityDoc.exists) {
        final slots = List<String>.from(availabilityDoc['slots'] ?? []);
        for (var slot in slots) {
          slotCounts.update(slot, (count) => count + 1, ifAbsent: () => 1);
        }
      }
    }

    setState(() => _availableDetailers = slotCounts);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.now(),
          lastDay: DateTime.now().add(const Duration(days: 90)),
          focusedDay: _selectedDay,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() => _selectedDay = selectedDay);
            _loadAvailableSlots(selectedDay);
          },
        ),
        const SizedBox(height: 16),
        if (_availableDetailers.isEmpty)
          const Text('No available slots on this day')
        else
          Expanded(
            child: ListView.builder(
              itemCount: _availableDetailers.length,
              itemBuilder: (context, index) {
                final slot = _availableDetailers.keys.toList()[index];
                final count = _availableDetailers[slot]!;
                return ListTile(
                  title: Text(slot),
                  trailing: Text(
                    '$count detailer${count > 1 ? 's' : ''} available',
                  ),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Selected $slot with $count detailer${count > 1 ? 's' : ''} available',
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
      ],
    );
  }
}

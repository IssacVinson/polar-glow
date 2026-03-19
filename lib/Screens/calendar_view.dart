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
    final formattedDate = DateFormat('yyyy-MM-dd').format(day);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const SizedBox(height: 8),
          TableCalendar(
            firstDay: DateTime.now(),
            lastDay: DateTime.now().add(const Duration(days: 90)),
            focusedDay: _selectedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() => _selectedDay = selectedDay);
              _loadAvailableSlots(selectedDay);
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              selectedDecoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _availableDetailers.isEmpty
                ? const Center(child: Text('No available slots on this day'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _availableDetailers.length,
                    itemBuilder: (context, index) {
                      final slot = _availableDetailers.keys.toList()[index];
                      final count = _availableDetailers[slot]!;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          title: Text(slot,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          trailing: Text(
                            '$count detailer${count > 1 ? 's' : ''} available',
                            style: TextStyle(
                                color: count > 0 ? Colors.green : Colors.red),
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
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

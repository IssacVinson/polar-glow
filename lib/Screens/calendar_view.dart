import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';
import 'employee_availability_screen.dart';

class CalendarView extends StatefulWidget {
  const CalendarView({super.key});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<String> _myTimeSlots = [];
  List<String> _myRegions = [];
  List<Map<String, dynamic>> _bookings = [];

  final List<String> _allRegions = [
    'Anchorage',
    'Wasilla',
    'Eagle River',
    'Base (JBER)'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadDayData(_selectedDay!);
  }

  Future<void> _loadDayData(DateTime day) async {
    final uid = context.read<AuthProvider>().user!.uid;
    final dateStr = DateFormat('yyyy-MM-dd').format(day);

    // Load availability
    final availDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('availability')
        .doc(dateStr)
        .get();

    // Load bookings
    final bookingSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .where('date', isEqualTo: Timestamp.fromDate(day))
        .get();

    final List<Map<String, dynamic>> loadedBookings = [];

    for (var doc in bookingSnap.docs) {
      final data = doc.data();
      final customerId = data['customerId'] as String?;

      String customerName = 'No data';
      String customerPhone = 'No data';
      String customerEmail = 'No data';

      if (customerId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (userDoc.exists) {
          final u = userDoc.data()!;
          customerName = u['displayName'] ?? u['username'] ?? 'No data';
          customerPhone = u['phoneNumber'] ?? 'No data';
          customerEmail = u['email'] ?? 'No data';
        }
      }

      loadedBookings.add({
        'id': doc.id,
        'time': data['cars']?[0]?['time'] ?? 'No time',
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
        'address': data['address'] ?? 'No data',
        'car': data['cars']?[0]?['vehicle'] ?? 'No data',
        'services':
            (data['services'] as List?)?.map((s) => s['name']).join(', ') ??
                'No services',
        'total': (data['totalPrice'] ?? 0.0).toStringAsFixed(2),
        'notes': data['notes'] ?? '',
      });
    }

    if (mounted) {
      setState(() {
        _myTimeSlots = List<String>.from(availDoc.data()?['timeSlots'] ?? []);
        _myRegions = List<String>.from(availDoc.data()?['regions'] ?? []);
        _bookings = loadedBookings;
      });
    }
  }

  int _getBookingCount(DateTime day) {
    // For marker only — we already loaded the selected day
    return _selectedDay != null && isSameDay(day, _selectedDay!)
        ? _bookings.length
        : 0;
  }

  // Keep your existing overlap + edit logic (unchanged)
  bool _hasOverlappingSlots(List<String> slots) {
    if (slots.length < 2) return false;
    List<(int, int)> intervals = [];
    for (String slot in slots) {
      final parts = slot.split(' – ');
      if (parts.length != 2) continue;
      final start = _parseTimeToMinutes(parts[0].trim());
      final end = _parseTimeToMinutes(parts[1].trim());
      if (start == null || end == null || start >= end) continue;
      intervals.add((start, end));
    }
    intervals.sort((a, b) => a.$1.compareTo(b.$1));
    for (int i = 1; i < intervals.length; i++) {
      if (intervals[i].$1 < intervals[i - 1].$2) return true;
    }
    return false;
  }

  int? _parseTimeToMinutes(String timeStr) {
    try {
      final format = DateFormat('h:mm a');
      final dt = format.parse(timeStr);
      return dt.hour * 60 + dt.minute;
    } catch (_) {
      return null;
    }
  }

  Future<void> _editSelectedDay() async {
    if (_selectedDay == null) return;

    final uid = context.read<AuthProvider>().user!.uid;
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDay!);

    List<String> editingSlots = List<String>.from(_myTimeSlots);
    List<String> editingRegions = List<String>.from(_myRegions);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  const Text('Time Slots',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...editingSlots.map((slot) => Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: const Icon(Icons.access_time),
                          title: Text(slot),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                setModalState(() => editingSlots.remove(slot)),
                          ),
                        ),
                      )),
                  Center(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Time Slot'),
                      onPressed: () async {
                        final start = await showTimePicker(
                            context: context,
                            initialTime: const TimeOfDay(hour: 9, minute: 0));
                        if (start == null) return;
                        final end = await showTimePicker(
                            context: context,
                            initialTime: start.replacing(hour: start.hour + 3));
                        if (end == null) return;
                        final slot =
                            '${start.format(context)} – ${end.format(context)}';
                        if (!editingSlots.contains(slot)) {
                          setModalState(() => editingSlots.add(slot));
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Regions',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: _allRegions.map((r) {
                      final selected = editingRegions.contains(r);
                      return FilterChip(
                        label: Text(r),
                        selected: selected,
                        onSelected: (sel) => setModalState(() {
                          if (sel)
                            editingRegions.add(r);
                          else
                            editingRegions.remove(r);
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                          child: TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'))),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (_hasOverlappingSlots(editingSlots)) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '❌ Overlapping time slots! Please fix before saving.'),
                                      backgroundColor: Colors.red));
                              return;
                            }

                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(uid)
                                .collection('availability')
                                .doc(dateStr)
                                .set({
                              'timeSlots': editingSlots,
                              'regions': editingRegions,
                              'updatedAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true));

                            Navigator.pop(ctx);
                            await _loadDayData(_selectedDay!);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('✅ Day updated!')));
                            }
                          },
                          child: const Text('Save Day'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('My Schedule'), centerTitle: true),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const EmployeeAvailabilityScreen())).then(
            (_) => _selectedDay != null ? _loadDayData(_selectedDay!) : null),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Set Recurring Availability'),
      ),
      body: Column(
        children: [
          Card(
            margin: const EdgeInsets.all(16),
            child: TableCalendar(
              firstDay: DateTime.now().subtract(const Duration(days: 30)),
              lastDay: DateTime.now().add(const Duration(days: 365)),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
                _loadDayData(selectedDay);
              },
              calendarBuilders: CalendarBuilders(
                markerBuilder: (context, day, _) {
                  final count = _getBookingCount(day);
                  if (count > 0) {
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
                          count.toString(),
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

          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedDay != null
                      ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)
                      : 'Tap a day',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (_selectedDay != null)
                  TextButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Availability'),
                    onPressed: _editSelectedDay,
                  ),
              ],
            ),
          ),

          // Scheduled Bookings
          if (_bookings.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('📅 Scheduled Bookings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _bookings.length,
                itemBuilder: (context, index) {
                  final b = _bookings[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ExpansionTile(
                      leading:
                          const Icon(Icons.event_busy, color: Colors.orange),
                      title: Text('${b['time']} — ${b['customerName']}'),
                      subtitle: Text('${b['car']} • \$${b['total']}'),
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Customer: ${b['customerName']}'),
                              Text('Phone: ${b['customerPhone']}'),
                              Text('Email: ${b['customerEmail']}'),
                              Text('Address: ${b['address']}'),
                              Text('Car: ${b['car']}'),
                              Text('Services: ${b['services']}'),
                              if (b['notes'].isNotEmpty)
                                Text('Notes: ${b['notes']}'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ] else if (_selectedDay != null) ...[
            const Center(child: Text('No bookings on this day')),
          ],

          // Open Availability
          if (_myTimeSlots.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('🟢 Open Availability',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            ..._myTimeSlots.map((slot) => ListTile(
                  leading: const Icon(Icons.access_time),
                  title: Text(slot),
                )),
          ],
        ],
      ),
    );
  }
}

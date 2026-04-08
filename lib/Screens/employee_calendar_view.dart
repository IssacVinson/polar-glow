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
  List<String> _availabilitySlotsForSelectedDay = [];

  Map<DateTime, int> _bookingCounts = {};
  Map<DateTime, int> _availabilitySlotCounts = {};

  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllCalendarData();
  }

  Future<void> _loadAllCalendarData() async {
    final uid = context.read<AuthProvider>().user!.uid;

    final bookingSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .get();

    final Map<DateTime, int> bookingCounts = {};
    for (var doc in bookingSnap.docs) {
      final data = doc.data();
      final ts = (data['date'] as Timestamp?)?.toDate();
      if (ts == null) continue;
      final alaskaDay = AlaskaDateUtils.toAlaskaDayKey(ts);
      final dayKey = DateTime(alaskaDay.year, alaskaDay.month, alaskaDay.day);
      bookingCounts[dayKey] = (bookingCounts[dayKey] ?? 0) + 1;
    }

    final availSnap = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('availability')
        .get();

    final Map<DateTime, int> slotCounts = {};
    for (var doc in availSnap.docs) {
      final data = doc.data();
      final slots = List<String>.from(data['timeSlots'] ?? []);
      if (slots.isNotEmpty) {
        final date = DateTime.parse(doc.id);
        final dayKey = DateTime(date.year, date.month, date.day);
        slotCounts[dayKey] = slots.length;
      }
    }

    if (mounted) {
      setState(() {
        _bookingCounts = bookingCounts;
        _availabilitySlotCounts = slotCounts;
      });
    }
  }

  Future<void> _loadBookingsAndAvailabilityForDay(DateTime day) async {
    final uid = context.read<AuthProvider>().user!.uid;
    final storageDate = AlaskaDateUtils.toAlaskaStorageDate(day);

    final bookingSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .where('date', isEqualTo: Timestamp.fromDate(storageDate))
        .get();

    final List<Map<String, dynamic>> bookings = [];
    for (var doc in bookingSnap.docs) {
      final data = doc.data();
      final customerId = data['customerId'] as String?;

      String customerName = 'Unknown';
      if (customerId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(customerId)
            .get();
        if (userDoc.exists) {
          final u = userDoc.data()!;
          customerName =
              u['displayName'] ?? u['fullName'] ?? u['email'] ?? 'Unknown';
        }
      }

      bookings.add({
        'id': doc.id,
        ...data,
        'customerName': customerName,
      });
    }

    final dateStr = AlaskaDateUtils.toDateString(day);
    final availDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('availability')
        .doc(dateStr)
        .get();

    final List<String> slots =
        List<String>.from(availDoc.data()?['timeSlots'] ?? []);

    if (mounted) {
      setState(() {
        _bookingsForSelectedDay = bookings;
        _availabilitySlotsForSelectedDay = slots;
      });
    }
  }

  // ── PREMIUM EDIT MODAL ──
  Future<void> _editAvailabilityForSelectedDay() async {
    if (_selectedDay == null) return;

    final uid = context.read<AuthProvider>().user!.uid;
    final dateStr = AlaskaDateUtils.toDateString(_selectedDay!);
    List<String> editingSlots =
        List<String>.from(_availabilitySlotsForSelectedDay);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
              left: 24,
              right: 24,
              top: 24,
            ),
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
                  'Edit Time Slots',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),

                const SizedBox(height: 32),

                const Text(
                  'Current Slots',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 17),
                ),
                const SizedBox(height: 12),

                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: editingSlots
                      .map((slot) => Chip(
                            label: Text(slot,
                                style: const TextStyle(fontSize: 15)),
                            backgroundColor: Colors.grey[800],
                            deleteIconColor: Colors.redAccent,
                            onDeleted: () =>
                                setModalState(() => editingSlots.remove(slot)),
                          ))
                      .toList(),
                ),

                const SizedBox(height: 32),

                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add New Time Slot'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _accentColor,
                      side: BorderSide(color: _accentColor),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: () async {
                      final slot = await _showAddTimeSlotDialog();
                      if (slot != null && !editingSlots.contains(slot)) {
                        setModalState(() => editingSlots.add(slot));
                      }
                    },
                  ),
                ),

                const SizedBox(height: 32),

                // ── PREMIUM BUTTONS ──
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white70,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Cancel',
                            style: TextStyle(fontSize: 16)),
                      ),
                    ),
                    Expanded(
                      child: FilledButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('availability')
                              .doc(dateStr)
                              .set({
                            'timeSlots': editingSlots,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          Navigator.pop(ctx);
                          await _loadBookingsAndAvailabilityForDay(
                              _selectedDay!);
                          await _loadAllCalendarData();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('✅ Time slots updated')),
                            );
                          }
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: _accentColor,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Save Changes',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<String?> _showAddTimeSlotDialog() async {
    final start = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
    );
    if (start == null) return null;

    final end = await showTimePicker(
      context: context,
      initialTime: start.replacing(hour: (start.hour + 3) % 24),
    );
    if (end == null) return null;

    return '${start.format(context)} – ${end.format(context)}';
  }

  void _showBookingDetails(Map<String, dynamic> booking) async {
    String customerName = booking['customerName'] ?? 'Unknown';
    String customerPhone = '';
    String customerEmail = booking['customerEmail'] ?? '';

    final customerId = booking['customerId'] as String?;
    if (customerId != null) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final u = userDoc.data()!;
        customerName = u['displayName'] ?? u['fullName'] ?? customerName;
        customerPhone = u['phoneNumber'] ?? '';
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
                AlaskaDateUtils.toDateString(
                    (booking['date'] as Timestamp).toDate()),
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              _detailRow('Customer', customerName),
              if (customerPhone.isNotEmpty) _detailRow('Phone', customerPhone),
              if (customerEmail.isNotEmpty) _detailRow('Email', customerEmail),
              _detailRow('Address', booking['address'] ?? '—'),
              _detailRow('Car', booking['cars']?[0]?['vehicle'] ?? 'No car'),
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
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EmployeeAvailabilityScreen()),
        ).then((_) {
          _loadAllCalendarData();
          if (_selectedDay != null)
            _loadBookingsAndAvailabilityForDay(_selectedDay!);
        }),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Recurring Availability'),
        backgroundColor: _accentColor,
        foregroundColor: Colors.black,
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Calendar
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 16,
                shadowColor: _accentColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28)),
                color: Colors.grey[850],
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
                      _loadBookingsAndAvailabilityForDay(selectedDay);
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
              ),
            ),
          ),

          // Selected Day Header
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: Card(
                elevation: 12,
                shadowColor: _accentColor.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                color: Colors.grey[850],
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    _selectedDay != null
                        ? DateFormat('EEEE, MMMM d, yyyy').format(_selectedDay!)
                        : 'Select a day to view details',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white),
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 8)),

          // Bookings
          if (_selectedDay != null && _bookingsForSelectedDay.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final b = _bookingsForSelectedDay[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 8,
                      shadowColor: Colors.orange.withOpacity(0.3),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      color: Colors.grey[850],
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: const Icon(Icons.event_busy,
                            color: Colors.orange, size: 32),
                        title: Text(
                            '${b['previewTime'] ?? b['cars']?[0]?['time'] ?? 'No time'} - ${b['customerName']}'),
                        subtitle: Text(
                            '${b['previewCar'] ?? b['cars']?[0]?['vehicle'] ?? ''} • \$${b['previewTotal'] ?? b['totalPrice'] ?? 0}'),
                        onTap: () => _showBookingDetails(b),
                      ),
                    );
                  },
                  childCount: _bookingsForSelectedDay.length,
                ),
              ),
            ),

          // Availability Card
          if (_selectedDay != null &&
              _availabilitySlotsForSelectedDay.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              sliver: SliverToBoxAdapter(
                child: Card(
                  elevation: 12,
                  shadowColor: _accentColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  color: Colors.grey[850],
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Available Time Slots',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF)),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _availabilitySlotsForSelectedDay
                              .map((slot) => Chip(
                                    label: Text(slot),
                                    backgroundColor:
                                        Colors.green.withOpacity(0.2),
                                    labelStyle:
                                        const TextStyle(color: Colors.white),
                                  ))
                              .toList(),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Edit Time Slots for this day'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: _accentColor,
                              side: BorderSide(color: _accentColor),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            onPressed: _editAvailabilityForSelectedDay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_selectedDay != null &&
              _bookingsForSelectedDay.isEmpty &&
              _availabilitySlotsForSelectedDay.isEmpty)
            const SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: Text(
                    'No bookings or availability on this day',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 80)),
        ],
      ),
    );
  }
}

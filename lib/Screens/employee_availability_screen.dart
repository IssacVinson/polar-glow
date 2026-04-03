// lib/screens/employee_availability_screen.dart
// FIXED: Removed 'const' from BoxDecoration (Colors.grey[900] is not a compile-time constant)
// FULL PREMIUM UPGRADE: Polar Glow dark theme + luxurious layout
// - Icy cyan glow accents + elevated glowing cards everywhere
// - Modern premium typography, generous spacing, and visual hierarchy
// - All original logic, overlap validation, preview, editing, Firestore writes, etc. preserved 100%

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/alaska_date_utils.dart';

class EmployeeAvailabilityScreen extends StatefulWidget {
  const EmployeeAvailabilityScreen({super.key});

  @override
  State<EmployeeAvailabilityScreen> createState() =>
      _EmployeeAvailabilityScreenState();
}

class _EmployeeAvailabilityScreenState
    extends State<EmployeeAvailabilityScreen> {
  final List<String> _selectedDaysOfWeek = [];
  final List<String> _selectedTimeSlots = [];
  final List<String> _selectedRegions = [];
  int _applyForWeeks = 4;

  final List<String> _allRegions = [
    'Anchorage',
    'Wasilla',
    'Eagle River',
    'Base (JBER)'
  ];

  final DateFormat _dateFormat = DateFormat('EEE, MMM d');

  List<Map<String, dynamic>> _previewDays = [];
  bool _isApplying = false;

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _refreshPreview();
  }

  Future<void> _refreshPreview() async {
    final data = await _getNext30DaysWithStatus();
    if (mounted) {
      setState(() => _previewDays = data);
    }
  }

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

  Future<void> _applyAvailability() async {
    if (_isApplying) return;

    if (_hasOverlappingSlots(_selectedTimeSlots)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '❌ Overlapping time slots detected! Please fix before saving.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isApplying = true);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      setState(() => _isApplying = false);
      return;
    }

    try {
      final now = DateTime.now();
      int updatedCount = 0;

      for (int week = 0; week < _applyForWeeks; week++) {
        for (int offset = 0; offset < 7; offset++) {
          final targetDate = now.add(Duration(days: week * 7 + offset));
          if (targetDate.isBefore(now.subtract(const Duration(days: 1)))) {
            continue;
          }

          final dateStr = AlaskaDateUtils.toDateString(targetDate);

          final docRef = FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('availability')
              .doc(dateStr);

          if (_selectedDaysOfWeek.contains(targetDate.weekday.toString())) {
            await docRef.set({
              'timeSlots': _selectedTimeSlots,
              'regions': _selectedRegions,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } else {
            await docRef.set({
              'timeSlots': [],
              'regions': [],
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          }
          updatedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Updated availability for $updatedCount days!'),
            backgroundColor: Colors.green,
          ),
        );
        await _refreshPreview();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  Future<void> _editDay(DateTime date) async {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final dateStr = AlaskaDateUtils.toDateString(date);

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('availability')
        .doc(dateStr)
        .get();

    List<String> editingSlots =
        List<String>.from(doc.data()?['timeSlots'] ?? []);
    List<String> editingRegions =
        List<String>.from(doc.data()?['regions'] ?? []);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                left: 24,
                right: 24,
                top: 24,
              ),
              decoration: BoxDecoration(
                // ← const removed to fix invalid constant error
                color: Colors.grey[900],
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(32)),
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
                    _dateFormat.format(date),
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Time Slots',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ...editingSlots.map(
                        (slot) => Chip(
                          label: Text(slot),
                          backgroundColor: Colors.grey[800],
                          deleteIconColor: _accentColor,
                          onDeleted: () =>
                              setModalState(() => editingSlots.remove(slot)),
                        ),
                      ),
                      ActionChip(
                        avatar: Icon(Icons.add, color: _accentColor),
                        label: const Text('Add Slot'),
                        backgroundColor: Colors.grey[800],
                        onPressed: () async {
                          final slot = await _showAddTimeSlotDialog();
                          if (slot != null && !editingSlots.contains(slot)) {
                            setModalState(() => editingSlots.add(slot));
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Regions',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: _allRegions.map((r) {
                      final selected = editingRegions.contains(r);
                      return FilterChip(
                        label: Text(r),
                        selected: selected,
                        selectedColor: _accentColor.withOpacity(0.2),
                        checkmarkColor: _accentColor,
                        onSelected: (sel) {
                          setModalState(() {
                            if (sel) {
                              editingRegions.add(r);
                            } else {
                              editingRegions.remove(r);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection('users')
                              .doc(userId)
                              .collection('availability')
                              .doc(dateStr)
                              .set({
                            'timeSlots': editingSlots,
                            'regions': editingRegions,
                            'updatedAt': FieldValue.serverTimestamp(),
                          }, SetOptions(merge: true));

                          Navigator.pop(context);
                          await _refreshPreview();

                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Day availability updated')),
                            );
                          }
                        },
                        child: const Text('Save Day'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getNext30DaysWithStatus() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return [];

    final now = DateTime.now();
    final List<Map<String, dynamic>> result = [];

    for (int i = 0; i < 30; i++) {
      final date = now.add(Duration(days: i));
      final dateStr = AlaskaDateUtils.toDateString(date);
      final storageDate = AlaskaDateUtils.toAlaskaStorageDate(date);

      final availSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('availability')
          .doc(dateStr)
          .get();

      final bookingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('assignedDetailerId', isEqualTo: userId)
          .where('date', isEqualTo: Timestamp.fromDate(storageDate))
          .limit(1)
          .get();

      String status = 'unset';
      int bookingCount = bookingSnap.size;

      if (bookingCount > 0) {
        status = 'scheduled';
      } else if (availSnap.exists &&
          (availSnap.data()?['timeSlots'] as List?)?.isNotEmpty == true) {
        status = 'available';
      }

      result.add({
        'date': date,
        'status': status,
        'bookingCount': bookingCount,
      });
    }
    return result;
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

  Future<void> _addTimeSlot() async {
    final slot = await _showAddTimeSlotDialog();
    if (slot != null && !_selectedTimeSlots.contains(slot)) {
      setState(() => _selectedTimeSlots.add(slot));
    }
  }

  @override
  Widget build(BuildContext context) {
    final canApply = _selectedDaysOfWeek.isNotEmpty &&
        _selectedTimeSlots.isNotEmpty &&
        _selectedRegions.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Set Availability',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Recurring Availability Card
            Card(
              elevation: 12,
              shadowColor: _accentColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28),
              ),
              color: Colors.grey[850],
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            color: _accentColor, size: 28),
                        const SizedBox(width: 12),
                        Text(
                          'Set Recurring Availability',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Applies to selected days only. All other days in the period will be cleared.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Colors.white70),
                    ),
                    const SizedBox(height: 32),
                    const Text('Days of the Week',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (int i = 1; i <= 7; i++)
                          FilterChip(
                            label: Text([
                              'Mon',
                              'Tue',
                              'Wed',
                              'Thu',
                              'Fri',
                              'Sat',
                              'Sun'
                            ][i - 1]),
                            selected:
                                _selectedDaysOfWeek.contains(i.toString()),
                            selectedColor: _accentColor.withOpacity(0.2),
                            checkmarkColor: _accentColor,
                            onSelected: (selected) {
                              setState(() {
                                final dayStr = i.toString();
                                if (selected) {
                                  _selectedDaysOfWeek.add(dayStr);
                                } else {
                                  _selectedDaysOfWeek.remove(dayStr);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('Time Slots',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ..._selectedTimeSlots.map(
                          (slot) => Chip(
                            label: Text(slot),
                            backgroundColor: Colors.grey[800],
                            deleteIconColor: _accentColor,
                            onDeleted: () =>
                                setState(() => _selectedTimeSlots.remove(slot)),
                          ),
                        ),
                        ActionChip(
                          avatar: Icon(Icons.add, color: _accentColor),
                          label: const Text('Add Slot'),
                          backgroundColor: Colors.grey[800],
                          onPressed: _addTimeSlot,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Text('Regions',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _allRegions.map((r) {
                        final selected = _selectedRegions.contains(r);
                        return FilterChip(
                          label: Text(r),
                          selected: selected,
                          selectedColor: _accentColor.withOpacity(0.2),
                          checkmarkColor: _accentColor,
                          onSelected: (sel) {
                            setState(() {
                              if (sel) {
                                _selectedRegions.add(r);
                              } else {
                                _selectedRegions.remove(r);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        const Text('Apply to next',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                        const SizedBox(width: 12),
                        DropdownButton<int>(
                          value: _applyForWeeks,
                          dropdownColor: Colors.grey[850],
                          style: const TextStyle(color: Colors.white),
                          items: [2, 4, 6, 8, 12]
                              .map((w) => DropdownMenuItem(
                                  value: w, child: Text('$w weeks')))
                              .toList(),
                          onChanged: (v) => v != null
                              ? setState(() => _applyForWeeks = v)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: _isApplying
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.black, strokeWidth: 2))
                            : const Icon(Icons.save),
                        label: Text(_isApplying
                            ? 'Saving...'
                            : 'Apply Recurring Availability'),
                        style: FilledButton.styleFrom(
                          backgroundColor: canApply && !_isApplying
                              ? _accentColor
                              : Colors.grey[600],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        onPressed: canApply && !_isApplying
                            ? _applyAvailability
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Preview
            Text(
              'Next 30 Days Preview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
            const SizedBox(height: 12),

            _previewDays.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _previewDays.length,
                    itemBuilder: (context, index) {
                      final day = _previewDays[index];
                      final date = day['date'] as DateTime;
                      final status = day['status'] as String;
                      final bookingCount = day['bookingCount'] as int;

                      final bool hasAvailability = status == 'available';
                      final bool isScheduled = status == 'scheduled';

                      Color color = isScheduled
                          ? Colors.orange
                          : hasAvailability
                              ? const Color(0xFF00E5FF)
                              : Colors.redAccent;

                      IconData icon = isScheduled
                          ? Icons.event_busy
                          : hasAvailability
                              ? Icons.check_circle
                              : Icons.cancel_outlined;

                      String subtitle = isScheduled
                          ? '$bookingCount booking${bookingCount == 1 ? '' : 's'} scheduled'
                          : hasAvailability
                              ? 'Available'
                              : 'No availability';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        color: Colors.grey[850],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: ListTile(
                          onTap: () => _editDay(date),
                          leading: Icon(icon, color: color),
                          title: Text(
                            _dateFormat.format(date),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(color: Colors.white70),
                          ),
                          trailing: const Icon(Icons.edit,
                              size: 20, color: Colors.white54),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}

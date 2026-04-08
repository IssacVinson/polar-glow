// lib/screens/employee_clock_screen.dart
// FIXED: Clocked-in detection now works correctly with newest-first query
// - Robust pairing logic (handles descending order from Firestore)
// - Supports both 'in'/'out' and legacy 'clock_in'/'clock_out'
// - Live timer, premium UI, and all original features preserved
// NEW: Entire screen is now ONE single scrollable area (no inner ListView)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/models/clock_event_model.dart';
import '../core/services/firestore_service.dart';
import '../Providers/auth_provider.dart' as app_auth;

class EmployeeClockScreen extends StatefulWidget {
  const EmployeeClockScreen({super.key});

  @override
  State<EmployeeClockScreen> createState() => _EmployeeClockScreenState();
}

class _EmployeeClockScreenState extends State<EmployeeClockScreen> {
  bool _isClockedIn = false;
  bool _isLoading = false;
  DateTime? _lastClockInTime;
  List<ClockEventModel> _recentEvents = [];

  Timer? _liveTimer;
  final FirestoreService _firestore = FirestoreService();

  @override
  void initState() {
    super.initState();
    _refreshClockData();
  }

  @override
  void dispose() {
    _liveTimer?.cancel();
    super.dispose();
  }

  void _startLiveTimer() {
    _liveTimer?.cancel();
    _liveTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _refreshClockData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final uid = context.read<app_auth.AuthProvider>().user!.uid;
      final events = await _firestore.getClockEventsFuture(uid);

      // ── FIXED: Correctly detect if currently clocked in ──
      // We make a chronological copy (oldest first) for pairing logic
      final chronological = List<ClockEventModel>.from(events)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      DateTime? openIn;
      for (var event in chronological) {
        final type = event.type.toLowerCase();
        if (type == 'in' || type == 'clock_in') {
          openIn = event.timestamp;
        } else if ((type == 'out' || type == 'clock_out') && openIn != null) {
          openIn = null;
        }
      }

      if (mounted) {
        setState(() {
          _recentEvents = events; // keep newest-first for UI
          _isClockedIn = openIn != null;
          _lastClockInTime = openIn;
          _isLoading = false;
        });

        if (_isClockedIn) {
          _startLiveTimer();
        } else {
          _liveTimer?.cancel();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  Future<void> _toggleClock() async {
    final uid = context.read<app_auth.AuthProvider>().user!.uid;
    final now = DateTime.now();
    final type = _isClockedIn ? 'out' : 'in';

    // Optimistic UI update
    setState(() {
      _isClockedIn = !_isClockedIn;
      _recentEvents.insert(
        0,
        ClockEventModel(
          id: 'temp',
          type: type,
          timestamp: now,
          date: DateFormat('yyyy-MM-dd').format(now),
        ),
      );
      if (type == 'in') {
        _lastClockInTime = now;
      } else {
        _lastClockInTime = null;
      }
    });

    try {
      await _firestore.addClockEvent(uid, type);
      await _refreshClockData();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('✅ Clocked $type')));
      }
    } catch (e) {
      // Revert optimistic update on failure
      if (mounted) {
        setState(() {
          _isClockedIn = !_isClockedIn;
          _recentEvents.removeAt(0);
          if (type == 'in') {
            _lastClockInTime = null;
          } else {
            _lastClockInTime = now;
          }
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  // Rest of your methods unchanged (edit, validation, formatting, etc.)
  Future<void> _editEventTime(String docId, DateTime currentTime) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (newDate == null || !mounted) return;

    final newTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
    );
    if (newTimeOfDay == null || !mounted) return;

    final newDateTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTimeOfDay.hour,
      newTimeOfDay.minute,
    );

    final uid = context.read<app_auth.AuthProvider>().user!.uid;

    if (!_validateNoOverlaps(_recentEvents, newDateTime, docId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Invalid time: causes overlap or duplicate clock in')),
        );
      }
      return;
    }

    await _firestore.updateClockEventTimestamp(uid, docId, newDateTime);
    await _refreshClockData();

    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Event time updated')));
    }
  }

  bool _validateNoOverlaps(
      List<ClockEventModel> events, DateTime newTime, String editId) {
    final tempEvents = events
        .map((e) => {'id': e.id, 'type': e.type, 'time': e.timestamp})
        .toList();

    bool found = false;
    for (var e in tempEvents) {
      if (e['id'] == editId) {
        e['time'] = newTime;
        found = true;
        break;
      }
    }
    if (!found) return false;

    tempEvents.sort(
        (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime));

    DateTime? lastIn;
    for (var e in tempEvents) {
      final type = (e['type'] as String).toLowerCase();
      final time = e['time'] as DateTime;

      if (type == 'in' || type == 'clock_in') {
        if (lastIn != null) return false;
        lastIn = time;
      } else if (type == 'out' || type == 'clock_out') {
        if (lastIn == null) return false;
        if (time.isBefore(lastIn)) return false;
        lastIn = null;
      }
    }
    return true;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    final parts = <String>[];
    if (hours > 0) parts.add('$hours h');
    if (minutes > 0 || hours > 0) parts.add('$minutes m');
    parts.add('$seconds s');
    return parts.join(' ');
  }

  Duration _calculateCurrentTotal() {
    Duration total = Duration.zero;
    DateTime? openIn;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayEvents =
        _recentEvents.where((e) => !e.timestamp.isBefore(todayStart)).toList();

    for (var event in todayEvents.reversed) {
      final type = event.type.toLowerCase();
      if (type == 'in' || type == 'clock_in') {
        openIn ??= event.timestamp;
      } else if ((type == 'out' || type == 'clock_out') && openIn != null) {
        total += event.timestamp.difference(openIn);
        openIn = null;
      }
    }

    if (openIn != null) {
      total += DateTime.now().difference(openIn);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStr = DateFormat('EEEE, MMMM d, yyyy').format(now);
    final currentTotal = _calculateCurrentTotal();

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Clock In / Out',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshClockData,
        child: SingleChildScrollView(
          // This makes the ENTIRE screen one unified scrollable area
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  todayStr,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white70,
                      ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 40),

                // Main Clock Status Card
                Card(
                  elevation: 16,
                  shadowColor: _isClockedIn
                      ? const Color(0xFF00E5FF).withOpacity(0.5)
                      : Colors.red.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(32),
                  ),
                  color: Colors.grey[850],
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        if (_isLoading)
                          const CircularProgressIndicator(
                              color: Color(0xFF00E5FF))
                        else ...[
                          Text(
                            _isClockedIn ? 'CLOCKED IN' : 'CLOCKED OUT',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                              color: _isClockedIn
                                  ? const Color(0xFF00E5FF)
                                  : Colors.redAccent,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 24),
                          if (_isClockedIn && _lastClockInTime != null) ...[
                            Text(
                              'Since ${DateFormat('HH:mm:ss').format(_lastClockInTime!)}',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _formatDuration(
                                  DateTime.now().difference(_lastClockInTime!)),
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w300,
                                color: Color(0xFF00E5FF),
                                letterSpacing: -1,
                              ),
                            ),
                          ] else
                            const Text(
                              'Ready to start your day',
                              style: TextStyle(
                                  fontSize: 18, color: Colors.white54),
                            ),
                          const SizedBox(height: 40),
                          FilledButton.icon(
                            icon: Icon(
                              _isClockedIn ? Icons.logout : Icons.login,
                              size: 32,
                            ),
                            label: Text(
                              _isClockedIn ? 'Clock Out' : 'Clock In',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: _isClockedIn
                                  ? Colors.redAccent
                                  : const Color(0xFF00E5FF),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 64, vertical: 24),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 12,
                            ),
                            onPressed: _toggleClock,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                  decoration: BoxDecoration(
                    color: Colors.grey[850],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        "Today's Total",
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatDuration(currentTotal),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Recent Clock History',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 12),

                // History is now part of the SAME Column → one scroll area
                if (_recentEvents.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(
                        'No recent events yet',
                        style: TextStyle(color: Colors.white54),
                      ),
                    ),
                  )
                else
                  ..._recentEvents.map((e) => Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        color: Colors.grey[850],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          leading: Icon(
                            (e.type.toLowerCase() == 'in' ||
                                    e.type.toLowerCase() == 'clock_in')
                                ? Icons.login
                                : Icons.logout,
                            color: (e.type.toLowerCase() == 'in' ||
                                    e.type.toLowerCase() == 'clock_in')
                                ? const Color(0xFF00E5FF)
                                : Colors.redAccent,
                            size: 32,
                          ),
                          title: Text(
                            (e.type.toLowerCase() == 'in' ||
                                    e.type.toLowerCase() == 'clock_in')
                                ? 'Clocked In'
                                : 'Clocked Out',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          subtitle: Text(
                            DateFormat('MMM d, yyyy • HH:mm:ss')
                                .format(e.timestamp),
                            style: const TextStyle(color: Colors.white54),
                          ),
                          onTap: () => _editEventTime(e.id, e.timestamp),
                        ),
                      )),

                const SizedBox(height: 40), // extra bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }
}

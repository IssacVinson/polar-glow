import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeClockScreen extends StatefulWidget {
  const EmployeeClockScreen({super.key});

  @override
  State<EmployeeClockScreen> createState() => _EmployeeClockScreenState();
}

class _EmployeeClockScreenState extends State<EmployeeClockScreen> {
  bool _isClockedIn = false;
  bool _isLoading = false;
  DateTime? _lastClockInTime;
  List<Map<String, dynamic>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _refreshClockData();
  }

  Future<void> _refreshClockData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('clock_events')
          .orderBy('timestamp')
          .limitToLast(200)
          .get();

      final events = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'],
          'time': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();

      DateTime? openIn;
      for (var event in events) {
        final time = event['time'] as DateTime;
        final type = event['type'] as String;

        if (type == 'in') {
          openIn = time;
        } else if (type == 'out' && openIn != null) {
          openIn = null;
        }
      }

      if (mounted) {
        setState(() {
          _recentEvents = events.reversed.toList(); // newest first
          _isClockedIn = openIn != null;
          _lastClockInTime = openIn;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load: $e')));
      }
    }
  }

  Future<void> _toggleClock() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final now = DateTime.now();
    final type = _isClockedIn ? 'out' : 'in';

    setState(() {
      _isClockedIn = !_isClockedIn;
      _recentEvents.insert(0, {'type': type, 'time': now});
      if (type == 'in') {
        _lastClockInTime = now;
      } else {
        _lastClockInTime = null;
      }
    });

    try {
      final newDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('clock_events')
          .add({
            'type': type,
            'timestamp': Timestamp.fromDate(now),
            'date': DateFormat('yyyy-MM-dd').format(now),
          });

      _recentEvents[0]['id'] = newDoc.id;

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Clocked $type')));
      }
    } catch (e) {
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _editEventTime(
    String docId,
    String type,
    DateTime currentTime,
  ) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime(2000),
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

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final allSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('clock_events')
        .orderBy('timestamp')
        .get();

    final allEvents = allSnapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'type': data['type'],
        'time': (data['timestamp'] as Timestamp).toDate(),
      };
    }).toList();

    if (!_validateNoOverlaps(allEvents, newDateTime, docId)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid time: causes overlap or duplicate clock in'),
          ),
        );
      }
      return;
    }

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('clock_events')
        .doc(docId)
        .update({
          'timestamp': Timestamp.fromDate(newDateTime),
          'date': DateFormat('yyyy-MM-dd').format(newDateTime),
        });

    await _refreshClockData();

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Event time updated')));
    }
  }

  bool _validateNoOverlaps(
    List<Map<String, dynamic>> events,
    DateTime newTime,
    String editId,
  ) {
    final tempEvents = events.map((e) => Map<String, dynamic>.from(e)).toList();

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
      (a, b) => (a['time'] as DateTime).compareTo(b['time'] as DateTime),
    );

    DateTime? lastIn;
    for (var e in tempEvents) {
      final type = e['type'] as String;
      final time = e['time'] as DateTime;

      if (type == 'in') {
        if (lastIn != null) return false;
        lastIn = time;
      } else if (type == 'out') {
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

    final todayEvents = _recentEvents.where((e) {
      final time = e['time'] as DateTime;
      return !time.isBefore(todayStart);
    }).toList();

    for (var event in todayEvents.reversed) {
      final time = event['time'] as DateTime;
      final type = event['type'] as String;

      if (type == 'in') {
        openIn ??= time;
      } else if (type == 'out' && openIn != null) {
        total += time.difference(openIn);
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
    final todayStr = DateFormat('d MMMM yyyy').format(now);
    final currentTotal = _calculateCurrentTotal();

    return Scaffold(
      appBar: AppBar(title: const Text('Clock In/Out')),
      body: RefreshIndicator(
        onRefresh: _refreshClockData,
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                todayStr,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      if (_isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        Text(
                          _isClockedIn ? 'CLOCKED IN' : 'CLOCKED OUT',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _isClockedIn ? Colors.green : Colors.red,
                          ),
                        ),
                        if (_isClockedIn && _lastClockInTime != null) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Since ${DateFormat('d MMMM yyyy HH:mm:ss').format(_lastClockInTime!)}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Duration: ${_formatDuration(DateTime.now().difference(_lastClockInTime!))}',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                        ],
                        const SizedBox(height: 32),
                        FilledButton.icon(
                          icon: Icon(_isClockedIn ? Icons.logout : Icons.login),
                          label: Text(_isClockedIn ? 'Clock Out' : 'Clock In'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isClockedIn
                                ? Colors.red
                                : Colors.green,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 48,
                              vertical: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _toggleClock,
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              Text(
                'Today\'s Total: ${_formatDuration(currentTotal)}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Recent Clock History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: _recentEvents.isEmpty
                    ? const Center(child: Text('No recent events'))
                    : ListView.builder(
                        itemCount: _recentEvents.length,
                        itemBuilder: (context, index) {
                          final e = _recentEvents[index];
                          return ListTile(
                            leading: Icon(
                              e['type'] == 'in' ? Icons.login : Icons.logout,
                              color: e['type'] == 'in'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(
                              e['type'] == 'in' ? 'Clock In' : 'Clock Out',
                            ),
                            subtitle: Text(
                              DateFormat(
                                'd MMMM yyyy HH:mm:ss',
                              ).format(e['time']),
                            ),
                            onTap: () =>
                                _editEventTime(e['id'], e['type'], e['time']),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

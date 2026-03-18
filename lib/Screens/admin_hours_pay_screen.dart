import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminHoursPayScreen extends StatefulWidget {
  final String employeeId;

  const AdminHoursPayScreen({super.key, required this.employeeId});

  @override
  State<AdminHoursPayScreen> createState() => _AdminHoursPayScreenState();
}

class _AdminHoursPayScreenState extends State<AdminHoursPayScreen> {
  List<Map<String, dynamic>> _payPeriodEvents = [];
  Duration _totalHours = Duration.zero;
  double _totalPay = 0.0; // $20/hr – consider making dynamic later
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPayPeriodData();
  }

  Future<void> _loadPayPeriodData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final now = DateTime.now();
      final startOfPeriod = now.subtract(const Duration(days: 14));
      final dayStart = Timestamp.fromDate(startOfPeriod);

      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('clock_events')
          .where('timestamp', isGreaterThanOrEqualTo: dayStart)
          .orderBy('timestamp')
          .get();

      final events = snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'type': data['type'],
          'time': (data['timestamp'] as Timestamp).toDate(),
        };
      }).toList();

      Duration total = Duration.zero;
      DateTime? openIn;

      for (var event in events) {
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

      if (mounted) {
        setState(() {
          _payPeriodEvents = events;
          _totalHours = total;
          _totalPay = (total.inMinutes / 60) * 20.0;
          _isLoading = false;
        });
      }
    } on FirebaseException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.code == 'permission-denied'
              ? 'Permission denied: Check Firebase security rules.'
              : 'Failed to load data: ${e.message}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Unexpected error: $e';
        });
      }
    }
  }

  Future<void> _editEventTime(
    String eventId,
    String type,
    DateTime currentTime,
  ) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (newDate == null || !mounted) return;

    final newTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
      helpText: 'Edit $type Time',
    );

    if (newTimeOfDay == null || !mounted) return;

    final proposedTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTimeOfDay.hour,
      newTimeOfDay.minute,
    );

    // Fetch ALL clock events for this employee to validate sequence
    final allSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
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

    // Validate the new sequence
    if (!_isValidSequenceAfterEdit(allEvents, eventId, proposedTime)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invalid edit: would cause overlapping clock-ins or invalid sequence',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('clock_events')
          .doc(eventId)
          .update({
            'timestamp': Timestamp.fromDate(proposedTime),
            'edited': true,
            'originalTimestamp': Timestamp.fromDate(currentTime),
            'editedAt': FieldValue.serverTimestamp(),
          });

      await _loadPayPeriodData();

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Event time updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update: $e')));
      }
    }
  }

  bool _isValidSequenceAfterEdit(
    List<Map<String, dynamic>> events,
    String editedEventId,
    DateTime newTime,
  ) {
    // Create a copy and replace the edited event's time
    final updatedEvents = events.map((e) {
      if (e['id'] == editedEventId) {
        return {...e, 'time': newTime};
      }
      return e;
    }).toList();

    // Sort by time (ascending)
    updatedEvents.sort((a, b) {
      return (a['time'] as DateTime).compareTo(b['time'] as DateTime);
    });

    DateTime? lastIn;

    for (var event in updatedEvents) {
      final type = event['type'] as String;
      final time = event['time'] as DateTime;

      if (type == 'in') {
        // Two consecutive ins without out → invalid
        if (lastIn != null) {
          return false;
        }
        lastIn = time;
      } else if (type == 'out') {
        // Out without preceding in → invalid
        if (lastIn == null) {
          return false;
        }
        // Out before its in → invalid
        if (time.isBefore(lastIn)) {
          return false;
        }
        lastIn = null;
      }
    }

    // If we end with an open "in" that's fine (still clocked in)
    return true;
  }

  String _formatDuration(Duration d) {
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    return '$hours h $minutes m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Hours: ${_formatDuration(_totalHours)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Estimated Pay: \$${_totalPay.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Clock Events (last 14 days)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _payPeriodEvents.isEmpty
                  ? const Center(child: Text('No events in this period'))
                  : ListView.builder(
                      itemCount: _payPeriodEvents.length,
                      itemBuilder: (context, index) {
                        final e = _payPeriodEvents[index];
                        final isIn = e['type'] == 'in';
                        final timeStr = DateFormat(
                          'MMM d HH:mm',
                        ).format(e['time']);
                        final typeLabel = isIn ? 'In' : 'Out';
                        final barColor = isIn ? Colors.green : Colors.red;

                        return IntrinsicHeight(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Container(
                                width: 6,
                                color: barColor,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                              ),
                              Expanded(
                                child: InkWell(
                                  onTap: () => _editEventTime(
                                    e['id'],
                                    e['type'],
                                    e['time'],
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 4,
                                    ),
                                    leading: Icon(
                                      isIn ? Icons.login : Icons.logout,
                                      color: barColor,
                                      size: 28,
                                    ),
                                    title: Text(
                                      '$typeLabel at $timeStr',
                                      style: TextStyle(
                                        color: isIn
                                            ? Colors.green[800]
                                            : Colors.red[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    hoverColor: colorScheme.primary.withOpacity(
                                      0.08,
                                    ),
                                    splashColor: colorScheme.primary
                                        .withOpacity(0.12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}

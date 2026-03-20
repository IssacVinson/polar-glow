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
  double _hourlyRate = 20.0;
  double _totalPay = 0.0;
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
      // Load clock events
      final now = DateTime.now();
      final startOfPeriod = now.subtract(const Duration(days: 14));
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('clock_events')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
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

      // Calculate hours
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
      if (openIn != null) total += DateTime.now().difference(openIn);

      // Load employee's hourly rate
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .get();
      final rate = (userDoc.data()?['hourlyRate'] ?? 20.0).toDouble();

      if (mounted) {
        setState(() {
          _payPeriodEvents = events;
          _totalHours = total;
          _hourlyRate = rate;
          _totalPay = (total.inMinutes / 60) * rate;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: $e';
        });
      }
    }
  }

  Future<void> _editEventTime(
      String eventId, String type, DateTime currentTime) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: currentTime,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (newDate == null || !mounted) return;

    final newTimeOfDay = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(currentTime),
      helpText: 'New $type Time',
    );
    if (newTimeOfDay == null || !mounted) return;

    final proposedTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTimeOfDay.hour,
      newTimeOfDay.minute,
    );

    // Quick validation (very relaxed for now while you clean up test data)
    final validationResult = _validateSequenceAfterEdit(eventId, proposedTime);
    if (validationResult != null) {
      final shouldForce = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invalid Sequence'),
          content: Text(validationResult),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Force Save Anyway'),
            ),
          ],
        ),
      );
      if (shouldForce != true) return;
    }

    // Save change
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Time updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  String? _validateSequenceAfterEdit(String editedEventId, DateTime newTime) {
    // Relaxed for now — you can force-save anything
    return null;
  }

  Future<void> _changeHourlyRate() async {
    final ctrl = TextEditingController(text: _hourlyRate.toStringAsFixed(2));
    final newRate = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Hourly Rate'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Hourly Rate (\$)'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final val = double.tryParse(ctrl.text);
              Navigator.pop(ctx, val);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newRate == null || newRate == _hourlyRate) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .update({'hourlyRate': newRate});

      setState(() {
        _hourlyRate = newRate;
        _totalPay = (_totalHours.inMinutes / 60) * newRate;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rate updated to \$$newRate/hr')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Failed to save rate: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  String _formatDuration(Duration d) {
    return '${d.inHours} h ${d.inMinutes % 60} m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hours & Pay'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Center(
                  child: Text(_errorMessage!,
                      style: const TextStyle(color: Colors.red)))
            else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Hours: ${_formatDuration(_totalHours)}',
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _changeHourlyRate,
                            icon: const Icon(Icons.edit, size: 18),
                            label:
                                Text('\$${_hourlyRate.toStringAsFixed(2)}/hr'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Estimated Pay: \$${_totalPay.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                  'Tip: Tap any event below to edit time. Use Force Save for test data.'),
              const SizedBox(height: 8),
              const Text('Clock Events (last 14 days)',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Expanded(
                child: _payPeriodEvents.isEmpty
                    ? const Center(child: Text('No clock events yet'))
                    : ListView.builder(
                        itemCount: _payPeriodEvents.length,
                        itemBuilder: (context, index) {
                          final e = _payPeriodEvents[index];
                          final isIn = e['type'] == 'in';
                          final timeStr =
                              DateFormat('MMM d HH:mm').format(e['time']);
                          final barColor = isIn ? Colors.green : Colors.red;

                          return IntrinsicHeight(
                            child: Row(
                              children: [
                                Container(
                                    width: 6,
                                    color: barColor,
                                    margin: const EdgeInsets.symmetric(
                                        vertical: 4)),
                                Expanded(
                                  child: InkWell(
                                    onTap: () => _editEventTime(
                                        e['id'], e['type'], e['time']),
                                    child: ListTile(
                                      leading: Icon(
                                          isIn ? Icons.login : Icons.logout,
                                          color: barColor,
                                          size: 28),
                                      title: Text(
                                          '${isIn ? "In" : "Out"} at $timeStr',
                                          style: TextStyle(
                                              color: isIn
                                                  ? Colors.green[800]
                                                  : Colors.red[800])),
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
      ),
    );
  }
}

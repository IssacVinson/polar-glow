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
  // Clock events
  List<Map<String, dynamic>> _payPeriodEvents = [];
  Duration _totalHours = Duration.zero;
  double _hourlyRate = 20.0;
  double _totalPay = 0.0;

  // Mileage claims
  List<Map<String, dynamic>> _mileageClaims = [];
  double _totalMileageReimbursement = 0.0;

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadClockEvents(), _loadMileageClaims()]);
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load data: $e';
        });
      }
    }
  }

  Future<void> _loadClockEvents() async {
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
      });
    }
  }

  Future<void> _loadMileageClaims() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
        .collection('mileageClaims')
        .orderBy('date', descending: true)
        .get();

    final claims = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'date': (data['date'] as Timestamp).toDate(),
        'milesDriven': (data['milesDriven'] ?? 0.0).toDouble(),
        'reimbursement': (data['reimbursement'] ?? 0.0).toDouble(),
        'notes': data['notes'] ?? '',
        'status': data['status'] ?? 'pending',
      };
    }).toList();

    final approvedTotal = claims
        .where((c) => c['status'] == 'approved')
        .fold<double>(0.0, (sum, c) => sum + c['reimbursement']);

    if (mounted) {
      setState(() {
        _mileageClaims = claims;
        _totalMileageReimbursement = approvedTotal;
      });
    }
  }

  // ── NEW: Mark Employee Paid ──
  Future<void> _markEmployeePaid() async {
    final grandTotal = _totalPay + _totalMileageReimbursement;
    if (grandTotal <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to pay yet')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark Employee Paid?'),
        content: Text(
            'Pay \$${grandTotal.toStringAsFixed(2)} to this employee?\n\n'
            '(Hours: \$${_totalPay.toStringAsFixed(2)} + Mileage: \$${_totalMileageReimbursement.toStringAsFixed(2)})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Mark Paid'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('payouts')
          .add({
        'date': Timestamp.now(),
        'amount': grandTotal,
        'hoursPay': _totalPay,
        'mileagePay': _totalMileageReimbursement,
        'type': 'hours_and_mileage',
        'status': 'paid',
        'notes': 'Full period payout (last 14 days)',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('✅ Employee paid \$${grandTotal.toStringAsFixed(2)}'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to record payout: $e'),
              backgroundColor: Colors.red),
        );
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
    );
    if (newTimeOfDay == null || !mounted) return;

    final proposedTime = DateTime(
      newDate.year,
      newDate.month,
      newDate.day,
      newTimeOfDay.hour,
      newTimeOfDay.minute,
    );

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

      await _loadAllData();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('✅ Time updated')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Update failed: $e'), backgroundColor: Colors.red));
      }
    }
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
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
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
          SnackBar(content: Text('Rate updated to \$$newRate/hr')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save rate: $e'),
          backgroundColor: Colors.red));
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
                      Text(
                          'Estimated Pay (hours): \$${_totalPay.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mileage Reimbursement (approved)'),
                          Text(
                              '\$${_totalMileageReimbursement.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                          'Grand Total: \$${(_totalPay + _totalMileageReimbursement).toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _markEmployeePaid,
                          icon: const Icon(Icons.payment),
                          label: const Text('Mark Employee Paid'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
              const SizedBox(height: 24),
              const Text('Mileage Claims',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18)),
              const SizedBox(height: 8),
              _mileageClaims.isEmpty
                  ? const Center(child: Text('No mileage claims yet'))
                  : Expanded(
                      child: ListView.builder(
                        itemCount: _mileageClaims.length,
                        itemBuilder: (context, index) {
                          final claim = _mileageClaims[index];
                          final dateStr =
                              DateFormat('MMM d, yyyy').format(claim['date']);
                          final isApproved = claim['status'] == 'approved';
                          final isPending = claim['status'] == 'pending';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(dateStr,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600)),
                                      Text(
                                          '\$${claim['reimbursement'].toStringAsFixed(2)}',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isApproved
                                                  ? Colors.green
                                                  : Colors.orange)),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${claim['milesDriven'].toStringAsFixed(1)} miles'),
                                  if (claim['notes'].isNotEmpty)
                                    Text('Note: ${claim['notes']}',
                                        style: const TextStyle(
                                            color: Colors.grey)),
                                  const SizedBox(height: 12),
                                  if (isPending)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim['id'], 'approved'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.green),
                                            child: const Text('Approve'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: ElevatedButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim['id'], 'denied'),
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red),
                                            child: const Text('Deny'),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Chip(
                                      label: Text(
                                          isApproved ? 'Approved' : 'Denied'),
                                      backgroundColor: isApproved
                                          ? Colors.green.withOpacity(0.2)
                                          : Colors.red.withOpacity(0.2),
                                    ),
                                ],
                              ),
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

  Future<void> _updateClaimStatus(String claimId, String newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('mileageClaims')
          .doc(claimId)
          .update({'status': newStatus});
      await _loadMileageClaims();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(newStatus == 'approved'
                  ? '✅ Claim approved'
                  : '❌ Claim denied')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

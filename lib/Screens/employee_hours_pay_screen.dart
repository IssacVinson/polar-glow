import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeHoursPayScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeHoursPayScreen({super.key, required this.employeeId});

  @override
  State<EmployeeHoursPayScreen> createState() => _EmployeeHoursPayScreenState();
}

class _EmployeeHoursPayScreenState extends State<EmployeeHoursPayScreen> {
  List<Map<String, dynamic>> _payPeriodEvents = [];
  Duration _totalHours = Duration.zero;
  double _hourlyRate = 20.0;
  double _totalPay = 0.0;

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
                          Text('\$${_hourlyRate.toStringAsFixed(2)}/hr',
                              style: const TextStyle(
                                  fontSize: 16, color: Colors.grey)),
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
                                  Chip(
                                    label: Text(isApproved
                                        ? 'Approved'
                                        : (isPending ? 'Pending' : 'Denied')),
                                    backgroundColor: isApproved
                                        ? Colors.green.withOpacity(0.2)
                                        : (isPending
                                            ? Colors.orange.withOpacity(0.2)
                                            : Colors.red.withOpacity(0.2)),
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
}

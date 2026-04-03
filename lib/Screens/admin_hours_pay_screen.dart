// lib/Screens/admin_hours_pay_screen.dart
// UPGRADED: Premium dark theme with glowing cards + cyan accents
// FIXED: Updated from old 'mileageClaims' → new 'reimbursements' collection
// Fully consistent with EmployeeDashboard + all upgraded admin screens

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

  // Reimbursements (formerly mileage)
  List<Map<String, dynamic>> _reimbursements = [];
  double _totalReimbursement = 0.0;

  bool _isLoading = true;
  String? _errorMessage;

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([_loadClockEvents(), _loadReimbursements()]);
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

  Future<void> _loadReimbursements() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
        .collection('reimbursements') // ← Updated to new collection
        .orderBy('submittedAt', descending: true)
        .get();

    final claims = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'date': (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        'amount': (data['amount'] ?? 0.0).toDouble(),
        'title': data['title'] ?? 'Reimbursement',
        'description': data['description'] ?? '',
        'status': data['status'] ?? 'submitted',
        'receiptUrl': data['receiptUrl'],
      };
    }).toList();

    final approvedTotal = claims
        .where((c) => c['status'] == 'paid' || c['status'] == 'accepted')
        .fold<double>(0.0, (sum, c) => sum + c['amount']);

    if (mounted) {
      setState(() {
        _reimbursements = claims;
        _totalReimbursement = approvedTotal;
      });
    }
  }

  // ── Mark Employee Paid ──
  Future<void> _markEmployeePaid() async {
    final grandTotal = _totalPay + _totalReimbursement;
    if (grandTotal <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nothing to pay yet')));
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Mark Employee Paid?',
            style: TextStyle(color: Colors.white)),
        content: Text(
            'Pay \$${grandTotal.toStringAsFixed(2)} to this employee?\n\n'
            '(Hours: \$${_totalPay.toStringAsFixed(2)} + Reimbursements: \$${_totalReimbursement.toStringAsFixed(2)})'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, Mark Paid',
                style: TextStyle(color: Color(0xFF00E5FF))),
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
        'reimbursementPay': _totalReimbursement, // ← updated field name
        'type': 'hours_and_reimbursements',
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
        backgroundColor: Colors.grey[850],
        title: const Text('Edit Hourly Rate',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'Hourly Rate (\$)',
            labelStyle: TextStyle(color: Colors.white70),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, double.tryParse(ctrl.text)),
            child:
                const Text('Save', style: TextStyle(color: Color(0xFF00E5FF))),
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
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Hours & Pay',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (_errorMessage != null)
              Expanded(
                  child: Center(
                      child: Text(_errorMessage!,
                          style: const TextStyle(color: Colors.red))))
            else ...[
              // Summary Card with glow
              Card(
                elevation: 16,
                shadowColor: _accentColor.withOpacity(0.4),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24)),
                color: Colors.grey[850],
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Hours: ${_formatDuration(_totalHours)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
                          ),
                          TextButton.icon(
                            onPressed: _changeHourlyRate,
                            icon: const Icon(Icons.edit,
                                size: 18, color: Color(0xFF00E5FF)),
                            label: Text(
                              '\$${_hourlyRate.toStringAsFixed(2)}/hr',
                              style: const TextStyle(color: Color(0xFF00E5FF)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Estimated Pay (hours): \$${_totalPay.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                      const Divider(height: 24, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reimbursements (approved)',
                              style: TextStyle(color: Colors.white70)),
                          Text(
                            '\$${_totalReimbursement.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Grand Total: \$${(_totalPay + _totalReimbursement).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF00E5FF)),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton.icon(
                          onPressed: _markEmployeePaid,
                          icon: const Icon(Icons.payment),
                          label: const Text('Mark Employee Paid'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Clock Events
              Text(
                'Clock Events (last 14 days)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 2,
                child: _payPeriodEvents.isEmpty
                    ? const Center(
                        child: Text('No clock events yet',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: _payPeriodEvents.length,
                        itemBuilder: (context, index) {
                          final e = _payPeriodEvents[index];
                          final isIn = e['type'] == 'in';
                          final timeStr =
                              DateFormat('MMM d HH:mm').format(e['time']);
                          final barColor = isIn ? Colors.green : Colors.red;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 12,
                            shadowColor: barColor.withOpacity(0.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            color: Colors.grey[850],
                            child: ListTile(
                              leading: Container(
                                width: 6,
                                height: double.infinity,
                                decoration: BoxDecoration(
                                  color: barColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              title: Text(
                                '${isIn ? "Clocked In" : "Clocked Out"} at $timeStr',
                                style: TextStyle(
                                    color: isIn ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.w600),
                              ),
                              onTap: () =>
                                  _editEventTime(e['id'], e['type'], e['time']),
                            ),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 24),

              // Reimbursements
              Text(
                'Reimbursements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              const SizedBox(height: 12),
              Expanded(
                flex: 2,
                child: _reimbursements.isEmpty
                    ? const Center(
                        child: Text('No reimbursements yet',
                            style: TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        itemCount: _reimbursements.length,
                        itemBuilder: (context, index) {
                          final claim = _reimbursements[index];
                          final dateStr =
                              DateFormat('MMM d, yyyy').format(claim['date']);
                          final isApproved = claim['status'] == 'paid' ||
                              claim['status'] == 'accepted';
                          final isPending = claim['status'] == 'submitted';

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 16,
                            shadowColor: _accentColor.withOpacity(0.4),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24)),
                            color: Colors.grey[850],
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(dateStr,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                      Text(
                                        '\$${claim['amount'].toStringAsFixed(2)}',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: isApproved
                                                ? Colors.green
                                                : Colors.orange),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(claim['title'],
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  if (claim['description'].isNotEmpty)
                                    Text('Note: ${claim['description']}',
                                        style: const TextStyle(
                                            color: Colors.white54)),
                                  const SizedBox(height: 16),
                                  if (isPending)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim['id'], 'accepted'),
                                            style: FilledButton.styleFrom(
                                                backgroundColor: Colors.green),
                                            child: const Text('Approve'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim['id'], 'denied'),
                                            style: FilledButton.styleFrom(
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
                                      labelStyle: TextStyle(
                                          color: isApproved
                                              ? Colors.green
                                              : Colors.red),
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
          .collection('reimbursements')
          .doc(claimId)
          .update({'status': newStatus});
      await _loadReimbursements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(newStatus == 'accepted' || newStatus == 'paid'
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

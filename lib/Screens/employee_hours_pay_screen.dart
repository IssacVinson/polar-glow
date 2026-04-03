// lib/screens/employee_hours_pay_screen.dart
// FULL PREMIUM UPGRADE: Polar Glow dark theme + luxurious layout
// - Hourly rate is now fully dynamic (pulled from admin-set 'hourlyRate' in user document)
// - Mileage section replaced with general Reimbursements (new collection)
// - Icy cyan glow accents + elevated glowing cards
// - Dramatic totals section with grand total
// - All original logic and Firestore queries preserved/adapted

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
  double _hourlyRate = 0.0; // Will be loaded from user document
  double _totalPay = 0.0;

  List<Map<String, dynamic>> _reimbursements = [];
  double _totalApprovedReimbursements = 0.0;

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

    // Load hourly rate from admin-set value in user document
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
        .collection('reimbursements')
        .orderBy('submittedAt', descending: true)
        .get();

    final claims = snapshot.docs.map((doc) {
      final data = doc.data();
      return {
        'id': doc.id,
        'date': (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        'amount': (data['amount'] ?? 0.0).toDouble(),
        'title': data['title'] ?? 'Reimbursement',
        'status': data['status'] ?? 'submitted',
      };
    }).toList();

    final approvedTotal = claims
        .where((c) => c['status'] == 'approved' || c['status'] == 'paid')
        .fold<double>(0.0, (sum, c) => sum + (c['amount'] as double));

    if (mounted) {
      setState(() {
        _reimbursements = claims;
        _totalApprovedReimbursements = approvedTotal;
      });
    }
  }

  String _formatDuration(Duration d) {
    return '${d.inHours} h ${d.inMinutes % 60} m';
  }

  @override
  Widget build(BuildContext context) {
    final grandTotal = _totalPay + _totalApprovedReimbursements;

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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                          color: Colors.redAccent, fontSize: 17),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Premium Totals Card
                      Card(
                        elevation: 16,
                        shadowColor: _accentColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        color: Colors.grey[850],
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Total Hours',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(
                                          color: Colors.white70,
                                        ),
                                  ),
                                  Text(
                                    _formatDuration(_totalHours),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '\$${_hourlyRate.toStringAsFixed(2)} / hr',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  Text(
                                    '\$${_totalPay.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: _accentColor,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(height: 32, color: Colors.white24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Approved Reimbursements',
                                    style: TextStyle(
                                        fontSize: 17, color: Colors.white70),
                                  ),
                                  Text(
                                    '\$${_totalApprovedReimbursements.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFFA726),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 16, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: Colors.black12,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Grand Total',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    Text(
                                      '\$${grandTotal.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                        color: _accentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Clock Events
                      Text(
                        'Clock Events (last 14 days)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),

                      _payPeriodEvents.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No clock events yet',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _payPeriodEvents.length,
                              itemBuilder: (context, index) {
                                final e = _payPeriodEvents[index];
                                final isIn = e['type'] == 'in';
                                final timeStr = DateFormat('MMM d • HH:mm')
                                    .format(e['time']);

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  color: Colors.grey[850],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: ListTile(
                                    leading: Icon(
                                      isIn ? Icons.login : Icons.logout,
                                      color: isIn
                                          ? const Color(0xFF00E5FF)
                                          : Colors.redAccent,
                                      size: 32,
                                    ),
                                    title: Text(
                                      isIn ? 'Clocked In' : 'Clocked Out',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Text(
                                      timeStr,
                                      style: const TextStyle(
                                          color: Colors.white54),
                                    ),
                                  ),
                                );
                              },
                            ),

                      const SizedBox(height: 40),

                      // Reimbursements
                      Text(
                        'Reimbursements',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),

                      _reimbursements.isEmpty
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32),
                                child: Text(
                                  'No reimbursement requests yet',
                                  style: TextStyle(color: Colors.white54),
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _reimbursements.length,
                              itemBuilder: (context, index) {
                                final claim = _reimbursements[index];
                                final dateStr = DateFormat('MMM d, yyyy')
                                    .format(claim['date']);
                                final isApproved =
                                    claim['status'] == 'approved' ||
                                        claim['status'] == 'paid';
                                final isPending =
                                    claim['status'] == 'submitted';

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  color: Colors.grey[850],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              dateStr,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '\$${claim['amount'].toStringAsFixed(2)}',
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: isApproved
                                                    ? Colors.green
                                                    : Colors.orange,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          claim['title'] ?? 'Reimbursement',
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                        const SizedBox(height: 12),
                                        Chip(
                                          label: Text(
                                            isApproved
                                                ? 'Approved'
                                                : (isPending
                                                    ? 'Pending'
                                                    : 'Denied'),
                                          ),
                                          backgroundColor: isApproved
                                              ? Colors.green.withOpacity(0.2)
                                              : (isPending
                                                  ? Colors.orange
                                                      .withOpacity(0.2)
                                                  : Colors.red
                                                      .withOpacity(0.2)),
                                          labelStyle: TextStyle(
                                            color: isApproved
                                                ? Colors.green
                                                : (isPending
                                                    ? Colors.orange
                                                    : Colors.red),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
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

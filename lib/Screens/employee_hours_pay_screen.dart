// lib/screens/employee/employee_hours_pay_screen.dart
// FIXED: All unused imports removed + fully synced with new finance path
// NEW: Fully responsive layout (no more overflow on any phone size)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/reimbursement_model.dart';
import '../../core/models/wage_payout_model.dart';
import '../../core/services/firestore_service.dart';

class EmployeeHoursPayScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeHoursPayScreen({super.key, required this.employeeId});

  @override
  State<EmployeeHoursPayScreen> createState() => _EmployeeHoursPayScreenState();
}

class _EmployeeHoursPayScreenState extends State<EmployeeHoursPayScreen> {
  final FirestoreService _firestore = FirestoreService();

  double _totalHours = 0.0;
  double _hourlyRate = 0.0;
  double _totalPay = 0.0;

  List<ReimbursementModel> _reimbursements = [];
  double _totalApprovedReimbursements = 0.0;

  List<WagePayoutModel> _payoutHistory = [];

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
      final payData = await _firestore.calculateEmployeePay(
        widget.employeeId,
        DateTime.now().subtract(const Duration(days: 14)),
        DateTime.now(),
      );

      final reimbList =
          await _firestore.getEmployeeReimbursements(widget.employeeId);
      final payoutList =
          await _firestore.getEmployeePayoutHistory(widget.employeeId);

      final approvedReimbTotal = reimbList
          .where((r) => r.isApproved || r.isPaid)
          .fold<double>(0.0, (sum, r) => sum + r.amount);

      if (mounted) {
        setState(() {
          _totalHours = payData['totalHours'] ?? 0.0;
          _hourlyRate = payData['hourlyRate'] ?? 0.0;
          _totalPay = payData['grossPay'] ?? 0.0;
          _reimbursements = reimbList;
          _totalApprovedReimbursements = approvedReimbTotal;
          _payoutHistory = payoutList;
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

  String _formatDuration(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 380;

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
                      // Premium Totals Card - now fully responsive
                      Card(
                        elevation: 16,
                        shadowColor: _accentColor.withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        color: Colors.grey[850],
                        child: Padding(
                          padding: EdgeInsets.all(isSmallScreen ? 20 : 32),
                          child: Column(
                            children: [
                              // Total Hours Row
                              Row(
                                children: [
                                  const Text(
                                    'Total Hours (14 days)',
                                    style: TextStyle(
                                        fontSize: 17, color: Colors.white70),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatDuration(_totalHours),
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Rate + Pay Row
                              Row(
                                children: [
                                  Text(
                                    '\$${_hourlyRate.toStringAsFixed(2)} / hr',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      color: Colors.white54,
                                    ),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        '\$${_totalPay.toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 22 : 24,
                                          fontWeight: FontWeight.bold,
                                          color: _accentColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const Divider(height: 32, color: Colors.white24),

                              // Approved Reimbursements
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

                              // Grand Total
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
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '\$${grandTotal.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: isSmallScreen ? 26 : 32,
                                            fontWeight: FontWeight.bold,
                                            color: _accentColor,
                                          ),
                                        ),
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

                      // Recent Payouts
                      if (_payoutHistory.isNotEmpty) ...[
                        Text(
                          'Recent Payouts',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 12),
                        ..._payoutHistory.map((payout) => Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              color: Colors.grey[850],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              child: ListTile(
                                leading: const Icon(Icons.payment,
                                    color: Color(0xFF4CAF50)),
                                title: Text(
                                    'Paid ${DateFormat('MMM d').format(payout.paidAt)}'),
                                subtitle: Text(
                                    '${payout.totalHours.toStringAsFixed(1)} hrs × \$${_hourlyRate.toStringAsFixed(2)}'),
                                trailing: Text(
                                  '\$${payout.grossPay.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF4CAF50),
                                  ),
                                ),
                              ),
                            )),
                        const SizedBox(height: 40),
                      ],

                      // Clock Events
                      Text(
                        'Clock Events (last 14 days)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Clock events are now calculated automatically.\n'
                          'Contact admin for detailed log if needed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
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
                                final isApproved =
                                    claim.isApproved || claim.isPaid;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  color: Colors.grey[850],
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20)),
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
                                              DateFormat('MMM d, yyyy')
                                                  .format(claim.dateSubmitted),
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white),
                                            ),
                                            Text(
                                              '\$${claim.amount.toStringAsFixed(2)}',
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
                                        Text(claim.title,
                                            style: const TextStyle(
                                                color: Colors.white70)),
                                        const SizedBox(height: 12),
                                        Chip(
                                          label: Text(
                                            claim.isPaid
                                                ? 'Paid'
                                                : claim.isApproved
                                                    ? 'Approved'
                                                    : claim.isDenied
                                                        ? 'Denied'
                                                        : 'Pending',
                                          ),
                                          backgroundColor: claim.isPaid
                                              ? Colors.blue.withOpacity(0.2)
                                              : claim.isApproved
                                                  ? Colors.green
                                                      .withOpacity(0.2)
                                                  : claim.isDenied
                                                      ? Colors.red
                                                          .withOpacity(0.2)
                                                      : Colors.orange
                                                          .withOpacity(0.2),
                                          labelStyle: TextStyle(
                                            color: claim.isPaid
                                                ? Colors.blue
                                                : claim.isApproved
                                                    ? Colors.green
                                                    : claim.isDenied
                                                        ? Colors.red
                                                        : Colors.orange,
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

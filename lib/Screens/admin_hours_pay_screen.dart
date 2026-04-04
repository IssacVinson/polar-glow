// lib/screens/admin/admin_hours_pay_screen.dart
// FINAL VERSION - All warnings fixed (unused _editEventTime removed)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/reimbursement_model.dart';
import '../../core/services/firestore_service.dart';
import '../../Providers/auth_provider.dart' as app_auth;

class AdminHoursPayScreen extends StatefulWidget {
  final String employeeId;

  const AdminHoursPayScreen({super.key, required this.employeeId});

  @override
  State<AdminHoursPayScreen> createState() => _AdminHoursPayScreenState();
}

class _AdminHoursPayScreenState extends State<AdminHoursPayScreen> {
  final FirestoreService _firestore = FirestoreService();

  // Payroll data from service
  double _totalHours = 0.0;
  double _hourlyRate = 20.0;
  double _totalPay = 0.0;

  // Reimbursements
  List<ReimbursementModel> _reimbursements = [];
  double _totalReimbursement = 0.0;

  bool _isLoading = true;
  String? _errorMessage;

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

      final approvedReimbTotal = reimbList
          .where((r) => r.isApproved || r.isPaid)
          .fold<double>(0.0, (sum, r) => sum + r.amount);

      if (mounted) {
        setState(() {
          _totalHours = payData['totalHours'] ?? 0.0;
          _hourlyRate = payData['hourlyRate'] ?? 20.0;
          _totalPay = payData['grossPay'] ?? 0.0;
          _reimbursements = reimbList;
          _totalReimbursement = approvedReimbTotal;
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
            'Pay \$${_totalPay.toStringAsFixed(2)} (hours) + \$${_totalReimbursement.toStringAsFixed(2)} (reimbursements)?\n\n'
            'Grand Total: \$${grandTotal.toStringAsFixed(2)}'),
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
      final adminId = context.read<app_auth.AuthProvider>().user!.uid;

      await _firestore.payEmployeeHours(
        employeeId: widget.employeeId,
        startDate: DateTime.now().subtract(const Duration(days: 14)),
        endDate: DateTime.now(),
        adminId: adminId,
      );

      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Employee paid \$${_totalPay.toStringAsFixed(2)} + \$${grandTotal.toStringAsFixed(2)} total'),
            backgroundColor: Colors.green,
          ),
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
      await _firestore.updateUserHourlyRate(widget.employeeId, newRate);

      setState(() {
        _hourlyRate = newRate;
        _totalPay = _totalHours * newRate;
      });

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rate updated to \$$newRate/hr')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to save rate: $e'),
          backgroundColor: Colors.red));
    }
  }

  String _formatDuration(double hours) {
    final h = hours.floor();
    final m = ((hours - h) * 60).round();
    return '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;
    final grandTotal = _totalPay + _totalReimbursement;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Hours & Pay',
            style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
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
              // Summary Card
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
                          Text('Total Hours: ${_formatDuration(_totalHours)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white)),
                          TextButton.icon(
                            onPressed: _changeHourlyRate,
                            icon: const Icon(Icons.edit,
                                size: 18, color: Color(0xFF00E5FF)),
                            label: Text(
                                '\$${_hourlyRate.toStringAsFixed(2)}/hr',
                                style:
                                    const TextStyle(color: Color(0xFF00E5FF))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'Estimated Pay (hours): \$${_totalPay.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                      const Divider(height: 24, color: Colors.white24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reimbursements (approved)',
                              style: TextStyle(color: Colors.white70)),
                          Text('\$${_totalReimbursement.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Grand Total: \$${grandTotal.toStringAsFixed(2)}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF00E5FF))),
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
                              foregroundColor: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Clock Events Section (simplified)
              Text('Clock Events (last 14 days)',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 12),
              const Expanded(
                flex: 2,
                child: Center(
                  child: Text(
                    'Clock events are automatically calculated.\nDetailed log available in employee view.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Reimbursements
              Text('Reimbursements',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white)),
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
                          final isApproved = claim.isApproved || claim.isPaid;
                          final isPending = claim.isPending;

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
                                      Text(
                                          DateFormat('MMM d, yyyy')
                                              .format(claim.dateSubmitted),
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white)),
                                      Text(
                                          '\$${claim.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: isApproved
                                                  ? Colors.green
                                                  : Colors.orange)),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(claim.title,
                                      style: const TextStyle(
                                          color: Colors.white70)),
                                  if (claim.description.isNotEmpty)
                                    Text('Note: ${claim.description}',
                                        style: const TextStyle(
                                            color: Colors.white54)),
                                  const SizedBox(height: 16),
                                  if (isPending)
                                    Row(
                                      children: [
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim.id, 'approved'),
                                            style: FilledButton.styleFrom(
                                                backgroundColor: Colors.green),
                                            child: const Text('Approve'),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: FilledButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim.id, 'denied'),
                                            style: FilledButton.styleFrom(
                                                backgroundColor: Colors.red),
                                            child: const Text('Deny'),
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Chip(
                                      label: Text(claim.isPaid
                                          ? 'Paid'
                                          : (claim.isApproved
                                              ? 'Approved'
                                              : 'Denied')),
                                      backgroundColor: claim.isPaid
                                          ? Colors.blue.withOpacity(0.2)
                                          : claim.isApproved
                                              ? Colors.green.withOpacity(0.2)
                                              : Colors.red.withOpacity(0.2),
                                      labelStyle: TextStyle(
                                          color: claim.isPaid
                                              ? Colors.blue
                                              : (claim.isApproved
                                                  ? Colors.green
                                                  : Colors.red)),
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
          .collection('reimbursements')
          .doc(claimId)
          .update({'status': newStatus});
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'approved' || newStatus == 'paid'
                ? '✅ Claim approved'
                : '❌ Claim denied'),
            backgroundColor: newStatus == 'approved' || newStatus == 'paid'
                ? Colors.green
                : Colors.red,
          ),
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

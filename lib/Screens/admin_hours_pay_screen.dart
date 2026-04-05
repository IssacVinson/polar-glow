// lib/screens/admin/admin_hours_pay_screen.dart
// UPDATED: YTD info moved to the very top of the summary card
// - Grand Total always includes approved (unpaid) reimbursements — even if $0
// - Clear section labels and layout for better readability
// - Full-screen scrollable (no inner scrolling)

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

  double _unpaidHours = 0.0;
  double _ytdHours = 0.0;
  double _ytdPay = 0.0;
  double _hourlyRate = 0.0;
  double _projectedPayout = 0.0;

  List<ReimbursementModel> _reimbursements = [];
  double _currentApprovedReimbursements = 0.0;

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
        DateTime.now(),
      );

      final reimbList =
          await _firestore.getEmployeeReimbursements(widget.employeeId);

      // Only currently APPROVED reimbursements count toward this payout
      final approvedReimbTotal = reimbList
          .where((r) => r.isApproved)
          .fold<double>(0.0, (sum, r) => sum + r.amount);

      if (mounted) {
        setState(() {
          _unpaidHours = payData['unpaidHours'] ?? 0.0;
          _ytdHours = payData['ytdHours'] ?? 0.0;
          _ytdPay = payData['ytdPay'] ?? 0.0;
          _hourlyRate = payData['hourlyRate'] ?? 0.0;
          _projectedPayout = payData['projectedPayout'] ?? 0.0;
          _reimbursements = reimbList;
          _currentApprovedReimbursements = approvedReimbTotal;
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
    final grandTotal = _projectedPayout + _currentApprovedReimbursements;
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
            'Pay \$${_projectedPayout.toStringAsFixed(2)} (unpaid hours) + \$${_currentApprovedReimbursements.toStringAsFixed(2)} (reimbursements)?\n\n'
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
          employeeId: widget.employeeId, adminId: adminId);
      await _loadAllData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ Employee paid \$${_projectedPayout.toStringAsFixed(2)} + \$${grandTotal.toStringAsFixed(2)} total'),
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
              labelStyle: TextStyle(color: Colors.white70)),
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
        _projectedPayout = _unpaidHours * newRate;
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
    final grandTotal = _projectedPayout + _currentApprovedReimbursements;

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                    // === YTD SECTION (moved to top as requested) ===
                    Text('This Year (YTD)',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white70)),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('YTD Hours',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                        Text(_formatDuration(_ytdHours),
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('YTD Pay',
                            style:
                                TextStyle(fontSize: 16, color: Colors.white)),
                        Text('\$${_ytdPay.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green)),
                      ],
                    ),

                    const Divider(height: 40, color: Colors.white24),

                    // === CURRENT PAYOUT SECTION ===
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Unpaid Hours (since last payout)',
                            style: TextStyle(
                                fontSize: 15.5, color: Colors.white70)),
                        Text(_formatDuration(_unpaidHours),
                            style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Hourly Rate',
                            style: TextStyle(
                                fontSize: 15.5, color: Colors.white70)),
                        TextButton.icon(
                          onPressed: _changeHourlyRate,
                          icon: const Icon(Icons.edit,
                              size: 18, color: Color(0xFF00E5FF)),
                          label: Text('\$${_hourlyRate.toStringAsFixed(2)}/hr',
                              style: const TextStyle(color: Color(0xFF00E5FF))),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    Text(
                        'Projected Payout: \$${_projectedPayout.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF00E5FF))),

                    const SizedBox(height: 16),

                    // Approved Reimbursements (always shown, even if $0)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Approved Reimbursements',
                            style: TextStyle(
                                fontSize: 15.5, color: Colors.white70)),
                        Text(
                            '\$${_currentApprovedReimbursements.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange)),
                      ],
                    ),

                    const Divider(height: 32, color: Colors.white24),

                    // Grand Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Grand Total (this payout)',
                            style:
                                TextStyle(fontSize: 17, color: Colors.white70)),
                        Text('\$${grandTotal.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF00E5FF))),
                      ],
                    ),

                    const SizedBox(height: 24),

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

            const SizedBox(height: 40),

            // Clock Events
            Text('Clock Events (last 14 days)',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),
            const Text(
              'Clock events are automatically calculated.\nDetailed log available in employee view.',
              style: TextStyle(color: Colors.white54),
            ),

            const SizedBox(height: 40),

            // Reimbursements
            Text('Reimbursements',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 12),

            _reimbursements.isEmpty
                ? const Center(
                    child: Text('No reimbursements yet',
                        style: TextStyle(color: Colors.white70)))
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
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
                                  Text('\$${claim.amount.toStringAsFixed(2)}',
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
                                  style:
                                      const TextStyle(color: Colors.white70)),
                              if (claim.description.isNotEmpty)
                                Text('Note: ${claim.description}',
                                    style:
                                        const TextStyle(color: Colors.white54)),
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
                                            child: const Text('Approve'))),
                                    const SizedBox(width: 12),
                                    Expanded(
                                        child: FilledButton(
                                            onPressed: () => _updateClaimStatus(
                                                claim.id, 'denied'),
                                            style: FilledButton.styleFrom(
                                                backgroundColor: Colors.red),
                                            child: const Text('Deny'))),
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

            const SizedBox(height: 80),
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(newStatus == 'approved' || newStatus == 'paid'
                ? '✅ Claim approved'
                : '❌ Claim denied'),
            backgroundColor: newStatus == 'approved' || newStatus == 'paid'
                ? Colors.green
                : Colors.red));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }
}

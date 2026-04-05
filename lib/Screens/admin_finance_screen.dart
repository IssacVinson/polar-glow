// lib/screens/admin/admin_finance_screen.dart
// UPDATED: New dynamic payroll system
// - Payroll tab now shows employee name (was just "Paid")
// - Uses new WagePayoutModel + employee lookup
// - All other tabs (Bookings / Reimbursements) unchanged
// - Premium Polar Glow dark theme preserved

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/booking_model.dart';
import '../../core/models/reimbursement_model.dart';
import '../../core/models/wage_payout_model.dart';
import '../../core/services/firestore_service.dart';
import '../../Providers/auth_provider.dart' as app_auth;
import '../../core/utils/alaska_date_utils.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  final FirestoreService _firestore = FirestoreService();

  double _moneyIn = 0.0;
  double _moneyOut = 0.0;
  double _netProfit = 0.0;

  List<BookingModel> _bookings = [];
  List<ReimbursementModel> _reimbursements = [];
  List<WagePayoutModel> _payouts = [];

  bool _isLoading = true;

  Color get _accentColor => const Color(0xFF00E5FF);

  int _currentTab = 0; // 0=Bookings, 1=Reimbursements, 2=Payroll

  @override
  void initState() {
    super.initState();
    _loadAllFinanceData();
  }

  Future<void> _loadAllFinanceData() async {
    setState(() => _isLoading = true);

    try {
      // Bookings (Money In)
      final bookingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('paymentStatus', isEqualTo: 'paid')
          .get();

      final bookings = bookingSnap.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList();

      final moneyIn =
          bookings.fold<double>(0.0, (sum, b) => sum + b.totalPrice);

      // Reimbursements
      final reimbList = await _firestore.getAllReimbursementsForAdmin();

      final moneyOutReimb = reimbList
          .where((r) => r.isPaid)
          .fold<double>(0.0, (sum, r) => sum + r.amount);

      // Payouts (wages)
      final payoutList = await _firestore.getAllPayoutsForAdmin();
      final moneyOutWages =
          payoutList.fold<double>(0.0, (sum, p) => sum + p.grossPay);

      if (mounted) {
        setState(() {
          _bookings = bookings;
          _reimbursements = reimbList;
          _payouts = payoutList;
          _moneyIn = moneyIn;
          _moneyOut = moneyOutReimb + moneyOutWages;
          _netProfit = moneyIn - _moneyOut;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error loading finance: $e')));
      }
    }
  }

  Future<void> _approveReimbursement(String id) async {
    final adminId = context.read<app_auth.AuthProvider>().user!.uid;
    await _firestore.approveReimbursement(
        reimbursementId: id, adminId: adminId);
    _loadAllFinanceData();
  }

  Future<void> _denyReimbursement(String id) async {
    final adminId = context.read<app_auth.AuthProvider>().user!.uid;
    await _firestore.denyReimbursement(reimbursementId: id, adminId: adminId);
    _loadAllFinanceData();
  }

  Future<void> _payReimbursement(String id) async {
    final adminId = context.read<app_auth.AuthProvider>().user!.uid;
    await _firestore.markReimbursementPaid(
        reimbursementId: id, adminId: adminId);
    _loadAllFinanceData();
  }

  // Helper to get employee name for payout display
  Future<String> _getEmployeeName(String employeeId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['displayName'] ??
            data['fullName'] ??
            data['email']?.split('@')[0] ??
            'Unknown';
      }
    } catch (_) {}
    return 'Unknown Employee';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('Finance Hub',
            style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      body: RefreshIndicator(
        onRefresh: _loadAllFinanceData,
        color: _accentColor,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : Column(
                children: [
                  // Summary Cards
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          child:
                              _summaryCard('Money In', _moneyIn, Colors.green),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryCard(
                              'Money Out', _moneyOut, Colors.orange),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _summaryCard('Net Profit', _netProfit,
                              _netProfit >= 0 ? Colors.cyan : Colors.red),
                        ),
                      ],
                    ),
                  ),

                  // Tabs
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: SegmentedButton<int>(
                      selected: {_currentTab},
                      onSelectionChanged: (set) =>
                          setState(() => _currentTab = set.first),
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Bookings')),
                        ButtonSegment(value: 1, label: Text('Reimbursements')),
                        ButtonSegment(value: 2, label: Text('Payroll')),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Tab Content
                  Expanded(
                    child: _currentTab == 0
                        ? _buildBookingsTab()
                        : _currentTab == 1
                            ? _buildReimbursementsTab()
                            : _buildPayrollTab(),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Card(
      elevation: 12,
      shadowColor: color.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookingsTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _bookings.length,
      itemBuilder: (context, i) {
        final b = _bookings[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey[850],
          child: ListTile(
            title: Text('Booking ${b.id.substring(0, 8)}'),
            subtitle: Text(
                '${AlaskaDateUtils.toDateString(b.date)} • \$${b.totalPrice.toStringAsFixed(2)}'),
            trailing: Chip(
              label: Text(b.isPaid ? 'PAID' : 'UNPAID'),
              backgroundColor: b.isPaid ? Colors.green : Colors.orange,
            ),
          ),
        );
      },
    );
  }

  Widget _buildReimbursementsTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _reimbursements.length,
      itemBuilder: (context, i) {
        final r = _reimbursements[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          color: Colors.grey[850],
          child: ListTile(
            title: Text(r.title),
            subtitle:
                Text('\$${r.amount.toStringAsFixed(2)} • ${r.employeeId}'),
            trailing: r.isPending
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: Colors.green),
                        onPressed: () => _approveReimbursement(r.id),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.red),
                        onPressed: () => _denyReimbursement(r.id),
                      ),
                    ],
                  )
                : r.isApproved
                    ? IconButton(
                        icon: const Icon(Icons.payment, color: Colors.blue),
                        onPressed: () => _payReimbursement(r.id),
                      )
                    : const Chip(label: Text('Paid')),
          ),
        );
      },
    );
  }

  Widget _buildPayrollTab() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      itemCount: _payouts.length,
      itemBuilder: (context, i) {
        final p = _payouts[i];
        return FutureBuilder<String>(
          future: _getEmployeeName(p.employeeId),
          builder: (context, nameSnapshot) {
            final employeeName = nameSnapshot.data ?? 'Loading...';

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              color: Colors.grey[850],
              child: ListTile(
                title: Text('Paid to $employeeName'),
                subtitle: Text(
                    '${DateFormat('MMM d, yyyy').format(p.paidAt)} • ${p.totalHours.toStringAsFixed(1)} hrs'),
                trailing: Text('\$${p.grossPay.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.green)),
              ),
            );
          },
        );
      },
    );
  }
}

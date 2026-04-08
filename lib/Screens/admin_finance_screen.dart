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

  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadAllFinanceData();
  }

  Future<void> _loadAllFinanceData() async {
    setState(() => _isLoading = true);

    try {
      final bookingSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('paymentStatus', isEqualTo: 'paid')
          .get();

      final bookings = bookingSnap.docs
          .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      final moneyIn =
          bookings.fold<double>(0.0, (total, b) => total + b.totalPrice);

      final reimbList = await _firestore.getAllReimbursementsForAdmin()
        ..sort((a, b) => b.dateSubmitted.compareTo(a.dateSubmitted));

      final moneyOutReimb = reimbList
          .where((r) => r.isPaid)
          .fold<double>(0.0, (total, r) => total + r.amount);

      final payoutList = await _firestore.getAllPayoutsForAdmin();
      final moneyOutWages =
          payoutList.fold<double>(0.0, (total, p) => total + p.grossPay);

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

  void _showBookingDetail(BookingModel booking) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking Details',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 8),
              Text(AlaskaDateUtils.toDateString(booking.date),
                  style: const TextStyle(fontSize: 18, color: Colors.white70)),
              const Divider(height: 32),
              FutureBuilder<String>(
                future: _getCustomerName(booking.customerId),
                builder: (context, snapshot) {
                  final name = snapshot.data ?? 'Loading...';
                  return _section('Customer', [
                    _detailRow('Name', name),
                    _detailRow('Address', booking.address),
                  ]);
                },
              ),
              const SizedBox(height: 24),
              _section(
                  'Vehicles',
                  booking.cars.map((car) {
                    final vehicle = car['vehicle'] ?? 'Unknown Vehicle';
                    final time = car['time'] ?? '';
                    return _detailRow(vehicle, time);
                  }).toList()),
              const SizedBox(height: 24),
              _section(
                  'Services',
                  booking.services.map((s) {
                    return _detailRow(s['name'] ?? 'Service',
                        '\$${s['price']?.toStringAsFixed(2) ?? '0.00'}');
                  }).toList()),
              const SizedBox(height: 24),
              _section('Payment & Status', [
                _detailRow(
                    'Total Price', '\$${booking.totalPrice.toStringAsFixed(2)}',
                    color: Colors.green),
                _detailRow(
                    'Payment Method', booking.paymentMethod.toUpperCase()),
                _detailRow('Payment Status', booking.isPaid ? 'PAID' : 'UNPAID',
                    color: booking.isPaid ? Colors.green : Colors.orange),
                if (booking.paidAt != null)
                  _detailRow(
                      'Paid On',
                      DateFormat('MMM d, yyyy • h:mm a')
                          .format(booking.paidAt!)),
                _detailRow('Completion',
                    booking.isCompleted ? 'COMPLETED' : 'IN PROGRESS',
                    color: booking.isCompleted ? Colors.blue : Colors.grey),
                if (booking.completedAt != null)
                  _detailRow(
                      'Completed On',
                      DateFormat('MMM d, yyyy • h:mm a')
                          .format(booking.completedAt!)),
              ]),
              const SizedBox(height: 24),
              FutureBuilder<String>(
                future: booking.assignedDetailerId != null
                    ? _getEmployeeName(booking.assignedDetailerId!)
                    : Future.value('Not assigned'),
                builder: (context, snapshot) {
                  return _section('Assigned To',
                      [_detailRow('Detailer', snapshot.data ?? '—')]);
                },
              ),
              if (booking.notes.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Notes', style: TextStyle(color: Colors.white70)),
                Text(booking.notes,
                    style: const TextStyle(color: Colors.white, height: 1.4)),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.white70)),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _detailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child:
                  Text(label, style: const TextStyle(color: Colors.white70))),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: color ?? Colors.white),
                softWrap: true),
          ),
        ],
      ),
    );
  }

  Future<String> _getCustomerName(String customerId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (doc.exists) {
        final data = doc.data()!;
        return data['displayName'] ??
            data['fullName'] ??
            data['email']?.split('@')[0] ??
            'Unknown Customer';
      }
    } catch (_) {}
    return 'Unknown Customer';
  }

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

  void _showReimbursementDetail(ReimbursementModel claim) {
    final isPending = claim.isPending;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.6,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (claim.receiptUrl != null && claim.receiptUrl!.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    claim.receiptUrl!,
                    height: 320,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                          height: 320,
                          color: Colors.grey[800],
                          child:
                              const Center(child: CircularProgressIndicator()));
                    },
                    errorBuilder: (_, __, ___) => Container(
                      height: 320,
                      color: Colors.grey[800],
                      child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 64, color: Colors.white54)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ] else
                const Text('No receipt image attached',
                    style: TextStyle(color: Colors.white54)),
              Text(claim.title,
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              const SizedBox(height: 8),
              Text(DateFormat('MMMM d, yyyy').format(claim.dateSubmitted),
                  style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Amount',
                      style: TextStyle(fontSize: 17, color: Colors.white70)),
                  Text('\$${claim.amount.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange)),
                ],
              ),
              if (claim.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text('Note', style: TextStyle(color: Colors.white70)),
                Text(claim.description,
                    style: const TextStyle(color: Colors.white, height: 1.4)),
              ],
              const SizedBox(height: 24),
              Chip(
                label: Text(claim.isPaid
                    ? 'PAID'
                    : claim.isApproved
                        ? 'APPROVED'
                        : 'PENDING'),
                backgroundColor: claim.isPaid
                    ? Colors.blue.withValues(alpha: 0.2)
                    : claim.isApproved
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.orange.withValues(alpha: 0.2),
                labelStyle: TextStyle(
                    color: claim.isPaid
                        ? Colors.blue
                        : claim.isApproved
                            ? Colors.green
                            : Colors.orange),
              ),
              if (isPending) ...[
                const SizedBox(height: 32),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _approveReimbursement(claim.id);
                        },
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.green),
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _denyReimbursement(claim.id);
                        },
                        style:
                            FilledButton.styleFrom(backgroundColor: Colors.red),
                        child: const Text('Deny'),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
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
        color: const Color(0xFF00E5FF),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                            child: _summaryCard(
                                'Money In', _moneyIn, Colors.green)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _summaryCard(
                                'Money Out', _moneyOut, Colors.orange)),
                        const SizedBox(width: 16),
                        Expanded(
                            child: _summaryCard('Net Profit', _netProfit,
                                _netProfit >= 0 ? Colors.cyan : Colors.red)),
                      ],
                    ),
                  ),

                  // NORMAL HEIGHT BANNER WITH FULL-HEIGHT TAB HITBOXES
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Row(
                        children: [
                          _buildTab(0, 'Bookings', Icons.calendar_today,
                              Colors.green),
                          _buildTab(1, 'Reimbursements', Icons.receipt_long,
                              Colors.orange),
                          _buildTab(
                              2, 'Payroll', Icons.attach_money, Colors.red),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

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

  Widget _buildTab(
      int index, String label, IconData icon, Color selectedColor) {
    final isSelected = _currentTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          // No margin = full height hitbox
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor.withValues(alpha: 0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 22, color: isSelected ? selectedColor : Colors.white70),
              const SizedBox(width: 8),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? selectedColor : Colors.white70,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryCard(String title, double amount, Color color) {
    return Card(
      elevation: 12,
      shadowColor: color.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(title, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 26, fontWeight: FontWeight.bold, color: color),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showBookingDetail(b),
            child: ListTile(
              title: Text('Booking • ${AlaskaDateUtils.toDateString(b.date)}'),
              subtitle: Text('\$${b.totalPrice.toStringAsFixed(2)}'),
              trailing: Chip(
                label: Text(b.isPaid ? 'PAID' : 'UNPAID'),
                backgroundColor: b.isPaid ? Colors.green : Colors.orange,
              ),
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
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => _showReimbursementDetail(r),
            child: ListTile(
              title: Text(r.title),
              subtitle: FutureBuilder<String>(
                future: _getEmployeeName(r.employeeId),
                builder: (context, snapshot) {
                  final name = snapshot.data ?? r.employeeId.substring(0, 8);
                  return Text('\$${r.amount.toStringAsFixed(2)} • $name');
                },
              ),
              trailing: r.isPending
                  ? const Icon(Icons.pending, color: Colors.orange)
                  : r.isPaid
                      ? const Icon(Icons.check_circle, color: Colors.blue)
                      : const Icon(Icons.check, color: Colors.green),
            ),
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
                    '${DateFormat("MMM d, yyyy").format(p.paidAt)} • ${p.totalHours.toStringAsFixed(1)} hrs'),
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

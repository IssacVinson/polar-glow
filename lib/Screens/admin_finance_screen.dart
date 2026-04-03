// lib/Screens/admin_finance_screen.dart
// UPGRADED: Premium dark theme with glowing cards + cyan accents
// FIXED: Updated from old 'mileageClaims' → new 'reimbursements' collection
// Fully consistent with EmployeeDashboard + all upgraded admin screens

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/utils/alaska_date_utils.dart';

class AdminFinanceScreen extends StatefulWidget {
  const AdminFinanceScreen({super.key});

  @override
  State<AdminFinanceScreen> createState() => _AdminFinanceScreenState();
}

class _AdminFinanceScreenState extends State<AdminFinanceScreen> {
  double _moneyIn = 0.0;
  double _moneyOut = 0.0;
  double _netProfit = 0.0;

  List<Map<String, dynamic>> _transactions = [];
  bool _isLoading = true;

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _loadFinanceData();
  }

  Future<void> _loadFinanceData() async {
    setState(() => _isLoading = true);

    try {
      // Money In: Paid bookings
      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('paid', isEqualTo: true)
          .get();

      double inTotal = 0.0;
      final List<Map<String, dynamic>> trans = [];

      for (var doc in bookingsSnap.docs) {
        final data = doc.data();
        final amount = (data['totalPrice'] ?? 0.0).toDouble();
        inTotal += amount;

        trans.add({
          'type': 'booking',
          'bookingId': doc.id,
          'title': 'Booking Payment',
          'subtitle':
              '${data['customerEmail'] ?? 'Customer'} • ${DateFormat('MMM d').format((data['date'] as Timestamp).toDate())}',
          'amount': amount,
          'date': (data['date'] as Timestamp).toDate(),
          'isIn': true,
          'data': data,
        });
      }

      // Money Out: Approved / Paid Reimbursements (NEW system)
      double outTotal = 0.0;

      final employeesSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      for (var empDoc in employeesSnap.docs) {
        final claimsSnap = await empDoc.reference
            .collection('reimbursements') // ← Updated to new collection
            .where('status',
                whereIn: ['paid', 'accepted']) // only real money out
            .get();

        for (var claimDoc in claimsSnap.docs) {
          final data = claimDoc.data();
          final amount = (data['amount'] ?? 0.0).toDouble();
          outTotal += amount;

          trans.add({
            'type': 'reimbursement',
            'title': data['title'] ?? 'Reimbursement',
            'subtitle':
                '${empDoc['displayName'] ?? empDoc['email'] ?? 'Employee'}',
            'amount': amount,
            'date':
                (data['submittedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            'isIn': false,
            'notes': data['description'] ?? '',
            'status': data['status'],
            'receiptUrl': data['receiptUrl'],
          });
        }
      }

      trans.sort(
          (a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      if (mounted) {
        setState(() {
          _moneyIn = inTotal;
          _moneyOut = outTotal;
          _netProfit = inTotal - outTotal;
          _transactions = trans;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  // Reused helper methods (same as before)
  Future<Map<String, String>> _getCustomerFullInfo(String? customerId) async {
    if (customerId == null || customerId.isEmpty)
      return {'name': 'Unknown', 'phone': 'N/A', 'email': 'N/A'};
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(customerId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return {
          'name': data['displayName'] ??
              data['fullName'] ??
              data['name'] ??
              'No Name',
          'phone': data['phoneNumber'] ?? data['phone'] ?? 'N/A',
          'email': data['email'] ?? 'N/A',
        };
      }
    } catch (_) {}
    return {'name': 'Unknown', 'phone': 'N/A', 'email': 'N/A'};
  }

  Future<String> _getEmployeeName(String? employeeId) async {
    if (employeeId == null || employeeId.isEmpty) return 'Unassigned';
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        return data['displayName'] ??
            data['fullName'] ??
            data['name'] ??
            (data['email']?.split('@')[0] ?? 'Unknown Employee');
      }
    } catch (_) {}
    return 'Unknown Employee';
  }

  void _showBookingDetails(
      BuildContext context, Map<String, dynamic> data) async {
    final customerId = data['customerId'] ?? data['customerEmail'];
    final assignedEmployeeId =
        data['assignedEmployeeId'] ?? data['assignedDetailerId'];
    final customerInfo = await _getCustomerFullInfo(customerId);
    final employeeName = await _getEmployeeName(assignedEmployeeId);
    final utcDate = (data['date'] as Timestamp).toDate();
    final alaskaDate = AlaskaDateUtils.toAlaskaDayKey(utcDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            Text('Customer: ${customerInfo['name']}',
                style: const TextStyle(color: Colors.white70)),
            Text('Email: ${customerInfo['email']}',
                style: const TextStyle(color: Colors.white70)),
            Text('Phone: ${customerInfo['phone']}',
                style: const TextStyle(color: Colors.white70)),
            if (data['address'] != null)
              Text('Address: ${data['address']}',
                  style: const TextStyle(color: Colors.white70)),
            Text('Date: ${DateFormat('MMM d, yyyy').format(alaskaDate)}',
                style: const TextStyle(color: Colors.white70)),
            Text(
                'Time: ${data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'}',
                style: const TextStyle(color: Colors.white70)),
            Text('Assigned to: $employeeName',
                style: const TextStyle(color: Colors.white70)),
            Text('Total: \$${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(color: _accentColor, fontSize: 18)),
            const SizedBox(height: 20),
            const Text('Services:',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.white)),
            ...((data['services'] as List?) ?? []).map((s) => Text(
                '• ${s['name']} (\$${s['price']})',
                style: const TextStyle(color: Colors.white70))),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              Text('Notes: ${data['notes']}',
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReimbursementDetails(Map<String, dynamic> claim) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Reimbursement Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            Text('Title: ${claim['title']}',
                style: const TextStyle(color: Colors.white70)),
            Text('Amount: \$${claim['amount']?.toStringAsFixed(2) ?? '0.00'}',
                style: TextStyle(color: _accentColor, fontSize: 18)),
            Text('Date: ${DateFormat('MMM d, yyyy').format(claim['date'])}',
                style: const TextStyle(color: Colors.white70)),
            if (claim['notes'] != null && claim['notes'].isNotEmpty)
              Text('Description: ${claim['notes']}',
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Finance Overview',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: RefreshIndicator(
        onRefresh: _loadFinanceData,
        color: _accentColor,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Cards with glow
                    Row(
                      children: [
                        Expanded(
                          child: _buildGlowSummaryCard(
                            title: 'Money In',
                            amount: _moneyIn,
                            color: Colors.green,
                            icon: Icons.arrow_downward_rounded,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildGlowSummaryCard(
                            title: 'Money Out',
                            amount: _moneyOut,
                            color: Colors.orange,
                            icon: Icons.arrow_upward_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildGlowSummaryCard(
                      title: 'Net Profit',
                      amount: _netProfit,
                      color: _netProfit >= 0 ? Colors.cyan : Colors.red,
                      icon: _netProfit >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      isBig: true,
                    ),
                    const SizedBox(height: 40),

                    Text(
                      'Recent Transactions',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                    ),
                    const SizedBox(height: 16),

                    _transactions.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40),
                              child: Text(
                                'No transactions yet',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              final isIn = t['isIn'] as bool;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                elevation: 16,
                                shadowColor: _accentColor.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24)),
                                color: Colors.grey[850],
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24, vertical: 12),
                                  leading: Icon(
                                    isIn
                                        ? Icons.arrow_downward_rounded
                                        : Icons.arrow_upward_rounded,
                                    color: isIn ? Colors.green : Colors.orange,
                                    size: 28,
                                  ),
                                  title: Text(
                                    t['title'],
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: Text(
                                    t['subtitle'],
                                    style:
                                        const TextStyle(color: Colors.white70),
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${isIn ? "+" : "-"}\$${t['amount'].toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isIn
                                              ? Colors.green
                                              : Colors.orange,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        DateFormat('MMM d').format(t['date']),
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    if (t['type'] == 'booking') {
                                      _showBookingDetails(context, t['data']);
                                    } else {
                                      _showReimbursementDetails(t);
                                    }
                                  },
                                ),
                              );
                            },
                          ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGlowSummaryCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
    bool isBig = false,
  }) {
    return Card(
      elevation: 16,
      shadowColor: color.withOpacity(0.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: isBig ? 32 : 24),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '\$${amount.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: isBig ? 36 : 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

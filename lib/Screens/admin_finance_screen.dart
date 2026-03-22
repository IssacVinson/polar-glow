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
          'data': data, // full booking data for modal
        });
      }

      // Money Out: Approved mileage claims
      double outTotal = 0.0;

      final employeesSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('role', isEqualTo: 'employee')
          .get();

      for (var empDoc in employeesSnap.docs) {
        final claimsSnap = await empDoc.reference
            .collection('mileageClaims')
            .where('status', isEqualTo: 'approved')
            .get();

        for (var claimDoc in claimsSnap.docs) {
          final data = claimDoc.data();
          final amount = (data['reimbursement'] ?? 0.0).toDouble();
          outTotal += amount;

          trans.add({
            'type': 'mileage',
            'title': 'Mileage Reimbursement',
            'subtitle':
                '${data['milesDriven']?.toStringAsFixed(1) ?? 0} miles • ${empDoc['displayName'] ?? empDoc['email']}',
            'amount': amount,
            'date': (data['date'] as Timestamp).toDate(),
            'isIn': false,
            'notes': data['notes'] ?? '',
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

  // Reused helper methods (same as Manage Bookings)
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

  // Rich modal (identical to Manage Bookings)
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Booking Details',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Customer: ${customerInfo['name']}'),
            Text('Email: ${customerInfo['email']}'),
            Text('Phone: ${customerInfo['phone']}'),
            if (data['address'] != null) Text('Address: ${data['address']}'),
            Text('Date: ${DateFormat('MMM d, yyyy').format(alaskaDate)}'),
            Text(
                'Time: ${data['cars']?[0]?['time'] ?? data['timeSlot'] ?? 'N/A'}'),
            Text('Assigned to: $employeeName'),
            Text(
                'Total: \$${data['totalPrice']?.toStringAsFixed(2) ?? '0.00'}'),
            const SizedBox(height: 16),
            const Text('Services:',
                style: TextStyle(fontWeight: FontWeight.bold)),
            ...((data['services'] as List?) ?? [])
                .map((s) => Text('• ${s['name']} (\$${s['price']})')),
            if (data['notes'] != null && data['notes'].toString().isNotEmpty)
              Text('Notes: ${data['notes']}'),
            const SizedBox(height: 24),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))),
          ],
        ),
      ),
    );
  }

  void _showMileageDetails(Map<String, dynamic> claim) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Mileage Claim Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Date: ${DateFormat('MMM d, yyyy').format(claim['date'])}'),
            Text('Miles: ${claim['milesDriven']?.toStringAsFixed(1) ?? 0}'),
            Text('Amount: \$${claim['amount']?.toStringAsFixed(2) ?? '0.00'}'),
            if (claim['notes'] != null && claim['notes'].isNotEmpty)
              Text('Note: ${claim['notes']}'),
            const SizedBox(height: 20),
            SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'))),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Finance Overview'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: _loadFinanceData,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _SummaryCard(
                                title: 'Money In',
                                amount: _moneyIn,
                                color: Colors.green,
                                icon: Icons.arrow_downward)),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _SummaryCard(
                                title: 'Money Out',
                                amount: _moneyOut,
                                color: Colors.orange,
                                icon: Icons.arrow_upward)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _SummaryCard(
                        title: 'Net Profit',
                        amount: _netProfit,
                        color: _netProfit >= 0 ? Colors.cyan : Colors.red,
                        icon: _netProfit >= 0
                            ? Icons.trending_up
                            : Icons.trending_down,
                        isBig: true),
                    const SizedBox(height: 32),
                    const Text('Recent Transactions',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _transactions.isEmpty
                        ? const Center(child: Text('No transactions yet'))
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final t = _transactions[index];
                              final isIn = t['isIn'] as bool;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                child: ListTile(
                                  leading: Icon(
                                      isIn
                                          ? Icons.arrow_downward
                                          : Icons.arrow_upward,
                                      color:
                                          isIn ? Colors.green : Colors.orange),
                                  title: Text(t['title']),
                                  subtitle: Text(t['subtitle']),
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
                                                  : Colors.orange)),
                                      Text(
                                          DateFormat('MMM d').format(t['date']),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey)),
                                    ],
                                  ),
                                  onTap: () {
                                    if (t['type'] == 'booking') {
                                      _showBookingDetails(context, t['data']);
                                    } else {
                                      _showMileageDetails(t);
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
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final double amount;
  final Color color;
  final IconData icon;
  final bool isBig;

  const _SummaryCard(
      {required this.title,
      required this.amount,
      required this.color,
      required this.icon,
      this.isBig = false});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(icon, color: color, size: isBig ? 28 : 20),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600))
            ]),
            const SizedBox(height: 12),
            Text('\$${amount.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: isBig ? 32 : 24,
                    fontWeight: FontWeight.bold,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

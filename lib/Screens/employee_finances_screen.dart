import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeFinancesScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeFinancesScreen({super.key, required this.employeeId});

  @override
  State<EmployeeFinancesScreen> createState() => _EmployeeFinancesScreenState();
}

class _EmployeeFinancesScreenState extends State<EmployeeFinancesScreen> {
  double _totalEarned = 0.0;
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  Future<void> _loadPayouts() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('payouts')
          .orderBy('date', descending: true)
          .get();

      double total = 0.0;
      final payouts = snapshot.docs.map((doc) {
        final data = doc.data();
        final amount = (data['amount'] ?? 0.0).toDouble();
        total += amount;
        return {
          'id': doc.id,
          'date': (data['date'] as Timestamp).toDate(),
          'amount': amount,
          'hoursPay': (data['hoursPay'] ?? 0.0).toDouble(),
          'mileagePay': (data['mileagePay'] ?? 0.0).toDouble(),
          'notes': data['notes'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          _totalEarned = total;
          _payouts = payouts;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Finances'),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          const Text('Total Earned',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '\$${_totalEarned.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 36,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text('Payout History',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _payouts.isEmpty
                      ? const Center(child: Text('No payouts yet'))
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _payouts.length,
                          itemBuilder: (context, index) {
                            final p = _payouts[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                title: Text(DateFormat('EEEE, MMMM d')
                                    .format(p['date'])),
                                subtitle: Text(
                                    'Hours: \$${p['hoursPay'].toStringAsFixed(2)} + Mileage: \$${p['mileagePay'].toStringAsFixed(2)}'),
                                trailing: Text(
                                  '\$${p['amount'].toStringAsFixed(2)}',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green),
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

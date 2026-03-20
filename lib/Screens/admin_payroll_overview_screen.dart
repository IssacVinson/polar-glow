import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_hours_pay_screen.dart';

class AdminPayrollOverviewScreen extends StatefulWidget {
  const AdminPayrollOverviewScreen({super.key});

  @override
  State<AdminPayrollOverviewScreen> createState() =>
      _AdminPayrollOverviewScreenState();
}

class _AdminPayrollOverviewScreenState
    extends State<AdminPayrollOverviewScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payroll Overview'), centerTitle: true),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'employee')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
                child: Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red)));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No employees found'));
          }

          final employees = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final doc = employees[index];
              final employeeId = doc.id;
              final email = doc['email'] ?? 'No email';

              return FutureBuilder<Map<String, dynamic>>(
                future: _calculateEmployeeSummary(employeeId),
                builder: (context, summarySnapshot) {
                  if (summarySnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Card(
                        child: ListTile(title: Text('Loading...')));
                  }

                  final summary = summarySnapshot.data ??
                      {'hours': '0h 0m', 'pay': 0.0, 'rate': 20.0};

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.person, size: 40),
                      title: Text(email,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('Total Hours: ${summary['hours']}'),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('\$${summary['pay'].toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                          Text('\$${summary['rate'].toStringAsFixed(2)}/hr',
                              style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AdminHoursPayScreen(employeeId: employeeId)),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Future<Map<String, dynamic>> _calculateEmployeeSummary(
      String employeeId) async {
    try {
      final now = DateTime.now();
      final startOfPeriod = now.subtract(const Duration(days: 14));

      // Clock events (exact same logic as detail screen)
      final snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .collection('clock_events')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(startOfPeriod))
          .orderBy('timestamp')
          .get();

      Duration total = Duration.zero;
      DateTime? openIn;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final time = (data['timestamp'] as Timestamp).toDate();
        final type = data['type'] as String;

        if (type == 'in') {
          openIn = time;
        } else if (type == 'out' && openIn != null) {
          total += time.difference(openIn);
          openIn = null;
        }
      }
      if (openIn != null) total += DateTime.now().difference(openIn);

      // Real hourly rate from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(employeeId)
          .get();
      final hourlyRate = (userDoc.data()?['hourlyRate'] ?? 20.0).toDouble();

      final hoursStr = '${total.inHours}h ${total.inMinutes % 60}m';
      final pay = (total.inMinutes / 60) * hourlyRate;

      return {'hours': hoursStr, 'pay': pay, 'rate': hourlyRate};
    } catch (e) {
      print('Payroll calc error for $employeeId: $e');
      return {'hours': 'Error', 'pay': 0.0, 'rate': 20.0};
    }
  }
}

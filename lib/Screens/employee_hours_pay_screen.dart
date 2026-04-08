// lib/screens/employee/employee_hours_pay_screen.dart
// FIXED: Overflow on "Unpaid Hours" row (long label + large duration)
// - Used Expanded + FittedBox (same pattern as your original code)
// - Clock events now display correctly
// - Premium dark theme + responsive layout preserved

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/clock_event_model.dart';
import '../../core/services/firestore_service.dart';
import '../../Providers/auth_provider.dart' as app_auth;

class EmployeeHoursPayScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeHoursPayScreen({super.key, required this.employeeId});

  @override
  State<EmployeeHoursPayScreen> createState() => _EmployeeHoursPayScreenState();
}

class _EmployeeHoursPayScreenState extends State<EmployeeHoursPayScreen> {
  final FirestoreService _firestore = FirestoreService();

  // Payroll data
  double _unpaidHours = 0.0;
  double _ytdHours = 0.0;
  double _ytdPay = 0.0;
  double _hourlyRate = 0.0;
  double _projectedPayout = 0.0;

  // Clock events (last 14 days)
  List<ClockEventModel> _clockEvents = [];

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
      final uid = context.read<app_auth.AuthProvider>().user!.uid;

      // Payroll data
      final payData = await _firestore.calculateEmployeePay(
        widget.employeeId,
        DateTime.now(),
      );

      // Clock events - last 14 days
      final allEvents = await _firestore.getClockEventsFuture(uid);
      final cutoff = DateTime.now().subtract(const Duration(days: 14));
      final recentEvents = allEvents
          .where((e) => e.timestamp.isAfter(cutoff))
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // newest first

      if (mounted) {
        setState(() {
          _unpaidHours = payData['unpaidHours'] ?? 0.0;
          _ytdHours = payData['ytdHours'] ?? 0.0;
          _ytdPay = payData['ytdPay'] ?? 0.0;
          _hourlyRate = payData['hourlyRate'] ?? 0.0;
          _projectedPayout = payData['projectedPayout'] ?? 0.0;
          _clockEvents = recentEvents;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load payroll data';
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
      body: RefreshIndicator(
        onRefresh: _loadAllData,
        color: _accentColor,
        child: _isLoading
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
                        // Main summary card
                        Card(
                          elevation: 16,
                          shadowColor: _accentColor.withValues(alpha: 0.4),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(28),
                          ),
                          color: Colors.grey[850],
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                // Unpaid Hours - FIXED OVERFLOW
                                Row(
                                  children: [
                                    const Expanded(
                                      child: Text(
                                        'Unpaid Hours (since last payout)',
                                        style: TextStyle(
                                            fontSize: 17,
                                            color: Colors.white70),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Flexible(
                                      child: FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          _formatDuration(_unpaidHours),
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 20),

                                // Hourly Rate
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Hourly Rate',
                                      style: TextStyle(
                                          fontSize: 17, color: Colors.white54),
                                    ),
                                    Text(
                                      '\$${_hourlyRate.toStringAsFixed(2)} / hr',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),

                                // Projected Payout
                                Text(
                                  'Projected Payout',
                                  style: const TextStyle(
                                      fontSize: 18, color: Colors.white70),
                                ),
                                Text(
                                  '\$${_projectedPayout.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: _accentColor,
                                  ),
                                ),

                                const Divider(
                                    height: 40, color: Colors.white24),

                                // YTD
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('YTD Hours',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    Text(
                                      _formatDuration(_ytdHours),
                                      style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('YTD Pay',
                                        style:
                                            TextStyle(color: Colors.white70)),
                                    Text(
                                      '\$${_ytdPay.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 40),

                        // Clock Events Section
                        Text(
                          'Clock Events (last 14 days)',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Clock events are automatically calculated.\n'
                          'Contact admin for detailed log if needed.',
                          style: TextStyle(color: Colors.white54, height: 1.4),
                        ),
                        const SizedBox(height: 24),

                        // Real clock events list
                        _clockEvents.isEmpty
                            ? const Center(
                                child: Padding(
                                  padding: EdgeInsets.symmetric(vertical: 32),
                                  child: Text(
                                    'No clock events in the last 14 days',
                                    style: TextStyle(color: Colors.white54),
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _clockEvents.length,
                                itemBuilder: (context, index) {
                                  final e = _clockEvents[index];
                                  final isIn = e.type.toLowerCase() == 'in' ||
                                      e.type.toLowerCase() == 'clock_in';

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    color: Colors.grey[850],
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: ListTile(
                                      leading: Icon(
                                        isIn ? Icons.login : Icons.logout,
                                        color: isIn
                                            ? const Color(0xFF00E5FF)
                                            : Colors.redAccent,
                                        size: 28,
                                      ),
                                      title: Text(
                                        isIn ? 'Clocked In' : 'Clocked Out',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      subtitle: Text(
                                        DateFormat('MMM d, yyyy • HH:mm:ss')
                                            .format(e.timestamp),
                                        style: const TextStyle(
                                            color: Colors.white54),
                                      ),
                                    ),
                                  );
                                },
                              ),

                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
      ),
    );
  }
}

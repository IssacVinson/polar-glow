// lib/screens/employee/employee_hours_pay_screen.dart
// UPDATED: New dynamic payroll system
// - Unpaid Hours = hours since last payout (dynamic, no fixed period)
// - YTD Hours + YTD Pay readouts
// - Projected Payout clearly shown
// - Employee view-only (no rate editing)
// - Premium dark theme preserved

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/services/firestore_service.dart';

class EmployeeHoursPayScreen extends StatefulWidget {
  final String employeeId;

  const EmployeeHoursPayScreen({super.key, required this.employeeId});

  @override
  State<EmployeeHoursPayScreen> createState() => _EmployeeHoursPayScreenState();
}

class _EmployeeHoursPayScreenState extends State<EmployeeHoursPayScreen> {
  final FirestoreService _firestore = FirestoreService();

  // New dynamic payroll fields
  double _unpaidHours = 0.0;
  double _ytdHours = 0.0;
  double _ytdPay = 0.0;
  double _hourlyRate = 0.0;
  double _projectedPayout = 0.0;

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
        DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _unpaidHours = payData['unpaidHours'] ?? 0.0;
          _ytdHours = payData['ytdHours'] ?? 0.0;
          _ytdPay = payData['ytdPay'] ?? 0.0;
          _hourlyRate = payData['hourlyRate'] ?? 0.0;
          _projectedPayout = payData['projectedPayout'] ?? 0.0;
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
    final grandTotal =
        _projectedPayout; // employees see only their unpaid payout

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
                      // Summary Card
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
                              // Unpaid Hours
                              Row(
                                children: [
                                  const Text(
                                    'Unpaid Hours (since last payout)',
                                    style: TextStyle(
                                        fontSize: 17, color: Colors.white70),
                                  ),
                                  const Spacer(),
                                  Flexible(
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        _formatDuration(_unpaidHours),
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
                              const SizedBox(height: 12),

                              // Hourly Rate (view only for employee)
                              Row(
                                children: [
                                  const Text(
                                    'Hourly Rate',
                                    style: TextStyle(
                                        fontSize: 17, color: Colors.white54),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '\$${_hourlyRate.toStringAsFixed(2)} / hr',
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Projected Payout
                              Text(
                                'Projected Payout: \$${_projectedPayout.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 22 : 24,
                                  fontWeight: FontWeight.bold,
                                  color: _accentColor,
                                ),
                              ),

                              const Divider(height: 32, color: Colors.white24),

                              // YTD
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('YTD Hours',
                                      style: TextStyle(color: Colors.white70)),
                                  Text(
                                    _formatDuration(_ytdHours),
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('YTD Pay',
                                      style: TextStyle(color: Colors.white70)),
                                  Text(
                                    '\$${_ytdPay.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Clock Events note
                      Text(
                        'Clock Events (last 14 days)',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Center(
                        child: Text(
                          'Clock events are automatically calculated.\n'
                          'Contact admin for detailed log if needed.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/booking_model.dart';
import '../../core/services/firestore_service.dart';
import '../../Providers/auth_provider.dart';
import '../core/utils/alaska_date_utils.dart';

class EmployeeBookingsScreen extends StatefulWidget {
  const EmployeeBookingsScreen({super.key});

  @override
  State<EmployeeBookingsScreen> createState() => _EmployeeBookingsScreenState();
}

class _EmployeeBookingsScreenState extends State<EmployeeBookingsScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<BookingModel> _bookings = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    final uid = context.read<AuthProvider>().user!.uid;
    final snap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('assignedDetailerId', isEqualTo: uid)
        .orderBy('date', descending: false)
        .get();

    final List<BookingModel> loaded = snap.docs
        .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
        .toList();

    if (mounted) {
      setState(() {
        _bookings = loaded;
        _loading = false;
      });
    }
  }

  Future<void> _markCompleted(String bookingId) async {
    final uid = context.read<AuthProvider>().user!.uid;
    await _firestore.markBookingCompleted(
      bookingId: bookingId,
      employeeId: uid,
    );
    _loadBookings(); // refresh
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Job marked as completed')),
      );
    }
  }

  Future<void> _markCashPaid(String bookingId) async {
    final uid = context.read<AuthProvider>().user!.uid;
    await _firestore.markCashBookingPaid(
      bookingId: bookingId,
      employeeId: uid,
    );
    _loadBookings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Cash payment marked as paid')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
          : _bookings.isEmpty
              ? const Center(
                  child: Text(
                    'No assigned bookings yet',
                    style: TextStyle(color: Colors.white54, fontSize: 18),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _bookings.length,
                  itemBuilder: (context, index) {
                    final booking = _bookings[index];
                    final isCash = booking.isCashPayment;
                    final isPaid = booking.isPaid;
                    final isCompleted = booking.isCompleted;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      color: Colors.grey[850],
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  AlaskaDateUtils.toDateString(booking.date),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPaid
                                        ? Colors.green
                                        : isCash
                                            ? Colors.orange
                                            : Colors.blue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    isPaid
                                        ? 'PAID'
                                        : isCash
                                            ? 'CASH'
                                            : 'STRIPE',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${booking.cars.map((c) => c['vehicle']).join(', ')}',
                              style: const TextStyle(color: Colors.white70),
                            ),
                            Text(
                              '\$${booking.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Divider(height: 24),
                            if (!isCompleted)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () => _markCompleted(booking.id),
                                  child: const Text('Mark Job Completed'),
                                ),
                              )
                            else if (isCash && !isPaid)
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                  ),
                                  onPressed: () => _markCashPaid(booking.id),
                                  child: const Text('Mark Cash as Paid'),
                                ),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(8.0),
                                child: Text(
                                  '✅ Completed & Paid',
                                  style: TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

// lib/screens/customer_booking_screen.dart
// UPDATED FILE — Replace your entire customer_booking_screen.dart with this exact code

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../core/models/booking_model.dart';
import '../core/services/firestore_service.dart';
import '../core/utils/alaska_date_utils.dart';
import '../Providers/auth_provider.dart';

class CustomerBookingScreen extends StatefulWidget {
  final List<Map<String, dynamic>> selectedServices;
  final String selectedRegion;

  const CustomerBookingScreen({
    super.key,
    required this.selectedServices,
    required this.selectedRegion,
  });

  @override
  State<CustomerBookingScreen> createState() => _CustomerBookingScreenState();
}

class _CustomerBookingScreenState extends State<CustomerBookingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  int _numCars = 1;
  List<TextEditingController> _vehicleControllers = [];
  List<TimeOfDay?> _carTimes = [];
  List<String?> _selectedFullSlots = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedDetailerId;

  List<Map<String, dynamic>> _employees = [];
  late Set<DateTime> _availableDays;
  Map<DateTime, int> _slotCounts = {};
  List<Map<String, dynamic>> _availableSlots = [];
  bool _loadingSlots = false;
  bool _isProcessingPayment = false;

  final FirestoreService _firestore = FirestoreService();

  double get _totalPrice =>
      widget.selectedServices.fold<double>(
        0.0,
        (sum, s) => sum + (s['price'] as num).toDouble(),
      ) *
      _numCars;

  @override
  void initState() {
    super.initState();
    _availableDays = {};
    _slotCounts = {};
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _updateCarControllers(_numCars);
    _loadEmployees();
    _loadAvailableDays();
  }

  void _updateCarControllers(int count) {
    for (var c in _vehicleControllers) c.dispose();
    _vehicleControllers = List.generate(count, (_) => TextEditingController());
    _carTimes = List.generate(count, (_) => null);
    _selectedFullSlots = List.generate(count, (_) => null);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _notesController.dispose();
    for (var c in _vehicleControllers) c.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'employee')
        .get();

    if (mounted) {
      setState(() {
        _employees = snap.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['displayName'] ??
                data['email']?.split('@')[0] ??
                'Employee',
          };
        }).toList();
      });
    }
  }

  Future<void> _loadAvailableDays() async {
    final now = DateTime.now();
    final futures = <Future>[];

    for (final emp in _employees) {
      final employeeId = emp['id'] as String;

      for (int i = 0; i < 60; i++) {
        final date =
            DateTime(now.year, now.month, now.day).add(Duration(days: i));
        final dateStr = AlaskaDateUtils.toDateString(date);

        futures.add(FirebaseFirestore.instance
            .collection('users')
            .doc(employeeId)
            .collection('availability')
            .doc(dateStr)
            .get()
            .then((doc) {
          if (doc.exists) {
            final data = doc.data()!;
            final regions = List<String>.from(data['regions'] ?? []);
            final timeSlots = List<String>.from(data['timeSlots'] ?? []);

            if (regions.contains(widget.selectedRegion) &&
                timeSlots.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _availableDays.add(date);
                  _slotCounts[date] = timeSlots.length;
                });
              }
            }
          }
        }));
      }
    }

    await Future.wait(futures);
    if (mounted) setState(() {});
  }

  Future<void> _loadSlotsForDay(DateTime date) async {
    setState(() {
      _loadingSlots = true;
      _availableSlots = [];
    });

    final dateStr = AlaskaDateUtils.toDateString(date);
    final storageDate = AlaskaDateUtils.toAlaskaStorageDate(date);
    final List<Map<String, dynamic>> slots = [];

    try {
      for (final emp in _employees) {
        final employeeId = emp['id'] as String;

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(employeeId)
            .collection('availability')
            .doc(dateStr)
            .get();

        if (doc.exists) {
          final data = doc.data()!;
          final regions = List<String>.from(data['regions'] ?? []);
          if (!regions.contains(widget.selectedRegion)) continue;

          final timeSlots = List<String>.from(data['timeSlots'] ?? []);

          if (timeSlots.isNotEmpty) {
            final bookedSnap = await FirebaseFirestore.instance
                .collection('bookings')
                .where('assignedDetailerId', isEqualTo: employeeId)
                .where('date', isEqualTo: Timestamp.fromDate(storageDate))
                .get();

            final bookedTimes = bookedSnap.docs
                .map((b) =>
                    (b.data()['cars']?[0]?['time'] ?? b.data()['time'] ?? '')
                        .toString())
                .where((t) => t.isNotEmpty)
                .toSet();

            final freeSlots =
                timeSlots.where((slot) => !bookedTimes.contains(slot)).toList();

            if (freeSlots.isNotEmpty) {
              slots.add({
                'employeeId': employeeId,
                'employeeName': emp['name'],
                'slots': freeSlots,
              });
            }
          }
        }
      }

      if (mounted) {
        setState(() {
          _availableSlots = slots;
          _loadingSlots = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSlots = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    _loadSlotsForDay(selectedDay);
  }

  Future<DocumentReference?> _createBooking(String paymentStatus) async {
    if (!_formKey.currentState!.validate()) return null;

    if (_selectedDay == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a date')));
      return null;
    }

    if (_carTimes.any((t) => t == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time for each car')));
      return null;
    }

    final List<Map<String, dynamic>> cars = [];
    for (int i = 0; i < _numCars; i++) {
      final vehicleText = _vehicleControllers[i].text.trim();
      final time = _carTimes[i]!;

      if (vehicleText.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Please enter vehicle info for car ${i + 1}')));
        return null;
      }

      cars.add({'vehicle': vehicleText, 'time': time.format(context)});
    }

    String? assignedDetailerId = _selectedDetailerId;
    if (assignedDetailerId == null) {
      if (_availableSlots.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('No available detailers in your region on this day')));
        return null;
      }
      assignedDetailerId = _availableSlots.first['employeeId'] as String?;
    }

    final booking = BookingModel(
      id: '',
      customerId: context.read<AuthProvider>().user!.uid,
      date: _selectedDay!,
      cars: cars,
      services: widget.selectedServices,
      totalPrice: _totalPrice,
      assignedDetailerId: assignedDetailerId,
      address: _addressController.text.trim(),
      notes: _notesController.text.trim(),
      status: 'pending',
      paymentStatus: paymentStatus,
    );

    try {
      final docRef = await _firestore.createBooking(booking);

      final dateStr = AlaskaDateUtils.toDateString(_selectedDay!);
      for (String? fullSlot in _selectedFullSlots) {
        if (fullSlot != null && fullSlot.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(assignedDetailerId!)
              .collection('availability')
              .doc(dateStr)
              .update({
            'timeSlots': FieldValue.arrayRemove([fullSlot])
          });
        }
      }

      return docRef;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create booking: $e')));
      }
      return null;
    }
  }

  Future<void> _payWithCard() async {
    setState(() => _isProcessingPayment = true);

    final docRef = await _createBooking('unpaid');
    if (docRef == null) {
      setState(() => _isProcessingPayment = false);
      return;
    }

    try {
      final paymentData = await _firestore.createPaymentIntent(
        bookingId: docRef.id,
        amount: _totalPrice,
      );

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: paymentData['clientSecret'],
          merchantDisplayName: 'Polar Glow Detailing',
          style: ThemeMode.dark,
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      await _firestore.updateBookingPaymentStatus(
        bookingId: docRef.id,
        paymentStatus: 'paid',
        paymentIntentId: paymentData['paymentIntentId'],
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('✅ Payment successful! Booking confirmed.'),
              backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Payment failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _payCash() async {
    setState(() => _isProcessingPayment = true);

    final docRef = await _createBooking('cash_on_arrival');
    if (docRef == null) {
      setState(() => _isProcessingPayment = false);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('✅ Booking confirmed! Pay cash when detailer arrives.'),
            backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }

    setState(() => _isProcessingPayment = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Book Appointment')),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverToBoxAdapter(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Selected Services
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Selected Services',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            ...widget.selectedServices.map(
                              (s) => ListTile(
                                dense: true,
                                title: Text(s['name'] ?? 'Service'),
                                trailing: Text(
                                    '\$${(s['price'] as num).toDouble().toStringAsFixed(2)}'),
                              ),
                            ),
                            const Divider(),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Total:',
                                    style:
                                        TextStyle(fontWeight: FontWeight.bold)),
                                Text('\$${_totalPrice.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // How many cars?
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('How many cars?',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 8),
                            DropdownButton<int>(
                              value: _numCars,
                              isExpanded: true,
                              items: List.generate(5, (i) => i + 1)
                                  .map((n) => DropdownMenuItem(
                                      value: n,
                                      child: Text('$n car${n > 1 ? 's' : ''}')))
                                  .toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() {
                                    _numCars = val;
                                    _updateCarControllers(val);
                                  });
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Car Details
                    ...List.generate(_numCars, (index) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Car ${index + 1} Details',
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 12),
                              TextFormField(
                                controller: _vehicleControllers[index],
                                decoration: const InputDecoration(
                                  labelText: 'Color, Make, Model',
                                  hintText: 'e.g. Black Toyota Camry',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (v) =>
                                    v!.trim().isEmpty ? 'Required' : null,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    // Google Places Autocomplete
                    GooglePlaceAutoCompleteTextField(
                      googleAPIKey: "AIzaSyDxrc2tPDR-SpPhC5rBZynOPxnbBvN2oGc",
                      textEditingController: _addressController,
                      inputDecoration: const InputDecoration(
                        labelText: 'Service Location / Address',
                        hintText: 'Start typing your address...',
                        border: OutlineInputBorder(),
                      ),
                      debounceTime: 800,
                      itemClick: (prediction) {
                        _addressController.text = prediction.description ?? '';
                      },
                      isLatLngRequired: false,
                    ),
                    const SizedBox(height: 16),

                    // Notes
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                          labelText: 'Additional Notes',
                          border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Calendar
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Select Date',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 380,
                              child: TableCalendar(
                                firstDay: DateTime.now(),
                                lastDay: DateTime.now()
                                    .add(const Duration(days: 365)),
                                focusedDay: _focusedDay,
                                selectedDayPredicate: (day) =>
                                    isSameDay(_selectedDay, day),
                                onDaySelected: _onDaySelected,
                                headerStyle: const HeaderStyle(
                                  formatButtonVisible: false,
                                  titleCentered: true,
                                  leftChevronVisible: true,
                                  rightChevronVisible: true,
                                ),
                                calendarFormat: CalendarFormat.month,
                                calendarBuilders: CalendarBuilders(
                                  markerBuilder: (context, day, _) {
                                    final count = _slotCounts[DateTime(
                                            day.year, day.month, day.day)] ??
                                        0;
                                    if (count > 0) {
                                      return Positioned(
                                        right: 6,
                                        top: 6,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                              color: Colors.green,
                                              shape: BoxShape.circle),
                                          child: Text(count.toString(),
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold)),
                                        ),
                                      );
                                    }
                                    return null;
                                  },
                                ),
                                calendarStyle: CalendarStyle(
                                  todayDecoration: BoxDecoration(
                                      color:
                                          colorScheme.primary.withOpacity(0.3),
                                      shape: BoxShape.circle),
                                  selectedDecoration: BoxDecoration(
                                      color: colorScheme.primary,
                                      shape: BoxShape.circle),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Available Times
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Available Times',
                                style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            if (_loadingSlots)
                              const Center(child: CircularProgressIndicator())
                            else if (_selectedDay == null)
                              const Text('Select a date above')
                            else if (_availableSlots.isEmpty)
                              const Text(
                                  'No available detailers in your region on this day',
                                  style: TextStyle(color: Colors.red))
                            else
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(_numCars, (carIndex) {
                                  final selectedTime = _carTimes[carIndex];
                                  final selectedTimeStr =
                                      selectedTime?.format(context);

                                  final usedTimes = _carTimes
                                      .asMap()
                                      .entries
                                      .where((e) =>
                                          e.key != carIndex && e.value != null)
                                      .map((e) => e.value!.format(context))
                                      .toSet();

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text('Car ${carIndex + 1}',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 8),
                                        DropdownButton<String?>(
                                          value: null,
                                          hint: Text(
                                              'Select time for Car ${carIndex + 1}'),
                                          isExpanded: true,
                                          items: _availableSlots.expand((emp) {
                                            final empId =
                                                emp['employeeId'] as String;
                                            final empName =
                                                emp['employeeName'] as String;
                                            return (emp['slots']
                                                    as List<String>)
                                                .where((slot) =>
                                                    !usedTimes.contains(slot
                                                        .split(' – ')[0]
                                                        .trim()))
                                                .map((slot) {
                                              final uniqueValue =
                                                  '$empId||$slot';
                                              return DropdownMenuItem<String>(
                                                value: uniqueValue,
                                                child: Text('$empName: $slot'),
                                              );
                                            });
                                          }).toList(),
                                          onChanged: (selectedUniqueValue) {
                                            if (selectedUniqueValue == null)
                                              return;
                                            final parts =
                                                selectedUniqueValue.split('||');
                                            if (parts.length != 2) return;

                                            final empId = parts[0];
                                            final slot = parts[1];

                                            final startStr =
                                                slot.split(' – ')[0].trim();
                                            TimeOfDay? parsedTime;

                                            try {
                                              final timeParts =
                                                  startStr.split(':');
                                              if (timeParts.length == 2) {
                                                final hour =
                                                    int.parse(timeParts[0]);
                                                final minute =
                                                    int.parse(timeParts[1]);
                                                parsedTime = TimeOfDay(
                                                    hour: hour, minute: minute);
                                              }
                                            } catch (_) {}

                                            if (parsedTime == null) {
                                              try {
                                                final format =
                                                    DateFormat('h:mm a');
                                                final dt =
                                                    format.parse(startStr);
                                                parsedTime =
                                                    TimeOfDay.fromDateTime(dt);
                                              } catch (_) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(SnackBar(
                                                        content: Text(
                                                            'Cannot parse time: $startStr')));
                                                return;
                                              }
                                            }

                                            setState(() {
                                              _carTimes[carIndex] = parsedTime;
                                              _selectedFullSlots[carIndex] =
                                                  slot;
                                              _selectedDetailerId = empId;
                                            });
                                          },
                                        ),
                                        if (selectedTimeStr != null) ...[
                                          const SizedBox(height: 8),
                                          Text('Selected: $selectedTimeStr',
                                              style: TextStyle(
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.w500)),
                                        ],
                                        const SizedBox(height: 16),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.credit_card),
                  label: Text(
                      'Pay in Full Now \$${_totalPrice.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 18)),
                  style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      backgroundColor: Colors.green[700]),
                  onPressed: _isProcessingPayment ? null : _payWithCard,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.money),
                  label: const Text('Pay Cash When Detailer Arrives',
                      style: TextStyle(fontSize: 17)),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18)),
                  onPressed: _isProcessingPayment ? null : _payCash,
                ),
              ),
              if (_isProcessingPayment)
                const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: CircularProgressIndicator()),
            ],
          ),
        ),
      ),
    );
  }
}

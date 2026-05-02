import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart' hide Card;
import 'package:google_places_flutter/google_places_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../core/models/booking_model.dart';
import '../core/services/firestore_service.dart';
import '../core/utils/alaska_date_utils.dart';
import '../Providers/auth_provider.dart';
import 'customer_calendar_view.dart';

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

  // Dedicated FocusNode for the address field (fixes backspace + focus jumping)
  late FocusNode _addressFocusNode;

  // Scroll controller for auto-scrolling to first missing required field
  late ScrollController _scrollController;

  // Key for address field so we can scroll exactly to it
  final _addressKey = GlobalKey();

  int _numCars = 1;
  List<TextEditingController> _vehicleControllers = [];
  List<TimeOfDay?> _carTimes = [];
  List<String?> _selectedFullSlots = [];

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  String? _selectedDetailerId;

  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _availableSlots = [];
  bool _loadingSlots = false;
  bool _isProcessingPayment = false;

  final FirestoreService _firestore = FirestoreService();

  double get _totalPrice =>
      widget.selectedServices.fold<double>(
        0.0,
        (acc, s) => acc + (s['price'] as num).toDouble(),
      ) *
      _numCars;

  Color get _accentColor => const Color(0xFF00E5FF);

  // NEW: Check if every car has a selected time slot
  bool get _allCarsHaveTime => !_carTimes.any((t) => t == null);

  @override
  void initState() {
    super.initState();
    _addressFocusNode = FocusNode();
    _scrollController = ScrollController();
    _selectedDay = DateTime.now();
    _focusedDay = DateTime.now();
    _updateCarControllers(_numCars);
    _loadEmployees();
  }

  void _updateCarControllers(int count) {
    for (var c in _vehicleControllers) {
      c.dispose();
    }
    _vehicleControllers = List.generate(count, (_) => TextEditingController());
    _carTimes = List.generate(count, (_) => null);
    _selectedFullSlots = List.generate(count, (_) => null);
  }

  @override
  void dispose() {
    _addressFocusNode.dispose();
    _scrollController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    for (var c in _vehicleControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // Helper to scroll to the first missing required field and focus it
  void _focusFirstMissingField() {
    if (_addressController.text.trim().isEmpty) {
      _addressFocusNode.requestFocus();
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_addressKey.currentContext != null) {
          Scrollable.ensureVisible(
            _addressKey.currentContext!,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Please fill all required fields above'),
        backgroundColor: Colors.orange,
      ),
    );
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

      if (_selectedDay != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _loadSlotsForDay(_selectedDay!);
        });
      }
    }
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

  Future<DocumentReference?> _createBooking(String paymentMethod) async {
    if (!_formKey.currentState!.validate()) {
      _focusFirstMissingField();
      return null;
    }

    if (_addressController.text.trim().isEmpty) {
      _focusFirstMissingField();
      return null;
    }

    if (_selectedDay == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Please select a date')));
      return null;
    }

    if (!_allCarsHaveTime) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a time for every car'),
        backgroundColor: Colors.red,
      ));
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
      paymentMethod: paymentMethod,
      paymentStatus: 'unpaid',
    );

    try {
      final docRef = await _firestore.createBookingWithPaymentMethod(booking);

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

    final authProvider = context.read<AuthProvider>();
    if (authProvider.user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please sign in again to continue'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() => _isProcessingPayment = false);
      return;
    }

    final docRef = await _createBooking('stripe');
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

      await _firestore.confirmStripePayment(
        bookingId: docRef.id,
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
      String userMessage = 'Payment failed. Please try again or use cash.';

      if (e.toString().contains('UNAUTHENTICATED') ||
          e.toString().contains('unauthenticated')) {
        userMessage =
            'Session expired.\nPlease log out and log back in, then try again.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userMessage),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Future<void> _payCash() async {
    setState(() => _isProcessingPayment = true);

    final docRef = await _createBooking('cash');
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
    final textTheme = Theme.of(context).textTheme;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Book Appointment',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selected Services
                Card(
                  elevation: 8,
                  shadowColor: _accentColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.spa, color: _accentColor, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Selected Services',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...widget.selectedServices.map(
                          (s) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  s['name'] ?? 'Service',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: Colors.white70,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  '\$${(s['price'] as num).toDouble().toStringAsFixed(2)}',
                                  style: textTheme.titleMedium?.copyWith(
                                    color: _accentColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const Divider(height: 32, color: Colors.white24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total:',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              '\$${_totalPrice.toStringAsFixed(2)}',
                              style: textTheme.headlineMedium?.copyWith(
                                color: _accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // How many cars?
                Card(
                  elevation: 8,
                  shadowColor: _accentColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.directions_car,
                                color: _accentColor, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'How many cars?',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          initialValue: _numCars,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  const BorderSide(color: Colors.white24),
                            ),
                            filled: true,
                            fillColor: Colors.black12,
                          ),
                          dropdownColor: Colors.grey[850],
                          style: const TextStyle(
                              color: Colors.white, fontSize: 18),
                          items: List.generate(5, (i) => i + 1)
                              .map((n) => DropdownMenuItem(
                                    value: n,
                                    child: Text(
                                      '$n car${n > 1 ? 's' : ''}',
                                      style:
                                          const TextStyle(color: Colors.white),
                                    ),
                                  ))
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

                const SizedBox(height: 28),

                // Car Details
                ...List.generate(_numCars, (index) {
                  return Card(
                    key: ValueKey('car-$index'),
                    margin: const EdgeInsets.only(bottom: 20),
                    elevation: 8,
                    shadowColor: _accentColor.withValues(alpha: 0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    color: colorScheme.surface,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Car ${index + 1} Details',
                            style: textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _vehicleControllers[index],
                            autofocus: false,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              labelText: 'Color, Make, Model',
                              labelStyle:
                                  const TextStyle(color: Colors.white70),
                              hintText: 'e.g. Black Toyota Camry',
                              hintStyle: const TextStyle(color: Colors.white38),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: Colors.black12,
                            ),
                            validator: (v) =>
                                v!.trim().isEmpty ? 'Required' : null,
                          ),
                        ],
                      ),
                    ),
                  );
                }),

                const SizedBox(height: 28),

                // Select Date (Calendar) - reduced for large phones (S25 Ultra)
                Card(
                  elevation: 8,
                  shadowColor: _accentColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today,
                                color: _accentColor, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Select Date',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: screenHeight *
                              0.45, // ← further reduced for S25 Ultra
                          child: CustomerCalendarView(
                            selectedRegion: widget.selectedRegion,
                            onDaySelected: _onDaySelected,
                            selectedDay: _selectedDay,
                            focusedDay: _focusedDay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Available Times
                Card(
                  elevation: 8,
                  shadowColor: _accentColor.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  color: colorScheme.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                color: _accentColor, size: 28),
                            const SizedBox(width: 12),
                            Text(
                              'Available Times',
                              style: textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_allCarsHaveTime && _selectedDay != null)
                          const Text(
                            'Please select a time for every car',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        const SizedBox(height: 16),
                        if (_loadingSlots)
                          const Center(
                              child: CircularProgressIndicator(
                                  color: Color(0xFF00E5FF)))
                        else if (_selectedDay == null)
                          const Text(
                            'Select a date above',
                            style: TextStyle(color: Colors.white70),
                          )
                        else if (_availableSlots.isEmpty)
                          const Text(
                            'No available detailers in your region on this day',
                            style: TextStyle(color: Colors.redAccent),
                          )
                        else
                          Column(
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
                                padding: const EdgeInsets.only(bottom: 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Car ${carIndex + 1}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    DropdownButtonFormField<String?>(
                                      initialValue: null,
                                      hint: Text(
                                        'Select time for Car ${carIndex + 1}',
                                        style: const TextStyle(
                                            color: Colors.white54),
                                      ),
                                      dropdownColor: Colors.grey[850],
                                      style:
                                          const TextStyle(color: Colors.white),
                                      decoration: InputDecoration(
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        filled: true,
                                        fillColor: Colors.black12,
                                      ),
                                      items: _availableSlots.expand((emp) {
                                        final empId =
                                            emp['employeeId'] as String;
                                        final empName =
                                            emp['employeeName'] as String;
                                        return (emp['slots'] as List<String>)
                                            .where((slot) =>
                                                !usedTimes.contains(slot
                                                    .split(' – ')[0]
                                                    .trim()))
                                            .map((slot) {
                                          final uniqueValue = '$empId||$slot';
                                          return DropdownMenuItem<String>(
                                            value: uniqueValue,
                                            child: Text(
                                              '$empName: $slot',
                                              style: const TextStyle(
                                                  color: Colors.white),
                                            ),
                                          );
                                        });
                                      }).toList(),
                                      onChanged: (selectedUniqueValue) {
                                        if (selectedUniqueValue == null) {
                                          return;
                                        }
                                        final parts =
                                            selectedUniqueValue.split('||');
                                        if (parts.length != 2) {
                                          return;
                                        }

                                        final empId = parts[0];
                                        final slot = parts[1];

                                        final startStr =
                                            slot.split(' – ')[0].trim();
                                        TimeOfDay? parsedTime;

                                        try {
                                          final timeParts = startStr.split(':');
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
                                            final format = DateFormat('h:mm a');
                                            final dt = format.parse(startStr);
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
                                          _selectedFullSlots[carIndex] = slot;
                                          _selectedDetailerId = empId;
                                        });
                                      },
                                    ),
                                    if (selectedTimeStr != null) ...[
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 8),
                                        decoration: BoxDecoration(
                                          color: _accentColor.withValues(
                                              alpha: 0.15),
                                          borderRadius:
                                              BorderRadius.circular(30),
                                        ),
                                        child: Text(
                                          'Selected: $selectedTimeStr',
                                          style: TextStyle(
                                            color: _accentColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            }),
                          ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Address field
                KeyedSubtree(
                  key: _addressKey,
                  child: GooglePlaceAutoCompleteTextField(
                    focusNode: _addressFocusNode,
                    googleAPIKey: "AIzaSyDxrc2tPDR-SpPhC5rBZynOPxnbBvN2oGc",
                    textEditingController: _addressController,
                    inputDecoration: InputDecoration(
                      labelText: 'Address *',
                      labelStyle: const TextStyle(color: Colors.white70),
                      hintText: 'Start typing your address...',
                      hintStyle: const TextStyle(color: Colors.white38),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.black12,
                      prefixIcon: Icon(Icons.location_on, color: _accentColor),
                    ),
                    debounceTime: 800,
                    itemClick: (prediction) {
                      _addressController.text = prediction.description ?? '';
                      _addressFocusNode.requestFocus();
                    },
                    isLatLngRequired: false,
                  ),
                ),

                const SizedBox(height: 28),

                // Additional Notes
                TextFormField(
                  controller: _notesController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Additional Notes',
                    labelStyle: const TextStyle(color: Colors.white70),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.black12,
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 120), // reduced for large phones
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.credit_card, size: 26),
                  label: Text(
                    'Pay in Full Now \$${_totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 22),
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessingPayment ? null : _payWithCard,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.money, size: 26),
                  label: const Text(
                    'Pay Cash When Detailer Arrives',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white54),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isProcessingPayment ? null : _payCash,
                ),
              ),
              if (_isProcessingPayment)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

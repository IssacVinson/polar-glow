/// Pure booking quote, validation, assignment, and slot rules.
///
/// Kept out of the widget so the customer happy path can be tested without
/// Firebase, Stripe, or Google Places.
class BookingQuote {
  static double total({
    required List<Map<String, dynamic>> services,
    required int numCars,
  }) {
    final base = services.fold<double>(
      0.0,
      (acc, s) => acc + ((s['price'] as num?) ?? 0).toDouble(),
    );
    return base * numCars;
  }
}

enum BookingValidationCode {
  missingAddress,
  missingDate,
  missingCarTime,
  missingVehicle,
  noDetailers,
}

class BookingValidationResult {
  const BookingValidationResult._(this.code, this.message);

  final BookingValidationCode code;
  final String message;

  static const missingAddress = BookingValidationResult._(
    BookingValidationCode.missingAddress,
    'Please fill all required fields above',
  );
  static const missingDate = BookingValidationResult._(
    BookingValidationCode.missingDate,
    'Please select a date',
  );
  static const missingCarTime = BookingValidationResult._(
    BookingValidationCode.missingCarTime,
    'Please select a time for every car',
  );
  static const noDetailers = BookingValidationResult._(
    BookingValidationCode.noDetailers,
    'No available detailers in your region on this day',
  );

  static BookingValidationResult missingVehicle(int carNumber) {
    return BookingValidationResult._(
      BookingValidationCode.missingVehicle,
      'Please enter vehicle info for car $carNumber',
    );
  }
}

class BookingDraft {
  const BookingDraft({
    required this.customerId,
    required this.date,
    required this.cars,
    required this.services,
    required this.totalPrice,
    required this.assignedDetailerId,
    required this.address,
    required this.notes,
    required this.paymentMethod,
    this.status = 'pending',
    this.paymentStatus = 'unpaid',
  });

  final String customerId;
  final DateTime date;
  final List<Map<String, dynamic>> cars;
  final List<Map<String, dynamic>> services;
  final double totalPrice;
  final String assignedDetailerId;
  final String address;
  final String notes;
  final String paymentMethod;
  final String status;
  final String paymentStatus;

  Map<String, dynamic> toMap() {
    return {
      'customerId': customerId,
      'date': date,
      'cars': cars,
      'services': services,
      'totalPrice': totalPrice,
      'assignedDetailerId': assignedDetailerId,
      'address': address,
      'notes': notes,
      'status': status,
      'paymentMethod': paymentMethod,
      'paymentStatus': paymentStatus,
    };
  }
}

class BookingFlow {
  static BookingValidationResult? validate({
    required String address,
    required DateTime? selectedDay,
    required List<String> vehicles,
    required List<String?> times,
    required String? selectedDetailerId,
    required List<Map<String, dynamic>> availableSlots,
  }) {
    if (address.trim().isEmpty) {
      return BookingValidationResult.missingAddress;
    }
    if (selectedDay == null) {
      return BookingValidationResult.missingDate;
    }
    if (times.isEmpty || times.any((t) => t == null || t.trim().isEmpty)) {
      return BookingValidationResult.missingCarTime;
    }
    for (var i = 0; i < vehicles.length; i++) {
      if (vehicles[i].trim().isEmpty) {
        return BookingValidationResult.missingVehicle(i + 1);
      }
    }
    if (selectedDetailerId == null && availableSlots.isEmpty) {
      return BookingValidationResult.noDetailers;
    }
    return null;
  }

  static String? nextDetailerId({
    required String? selectedDetailerId,
    required List<Map<String, dynamic>> availableSlots,
  }) {
    if (selectedDetailerId != null && selectedDetailerId.isNotEmpty) {
      return selectedDetailerId;
    }
    if (availableSlots.isEmpty) return null;
    return availableSlots.first['employeeId'] as String?;
  }

  /// Builds the booking the customer would persist after cash or card.
  static BookingDraft? buildDraft({
    required String customerId,
    required String address,
    required String notes,
    required DateTime? selectedDay,
    required List<String> vehicles,
    required List<String?> times,
    required String? selectedDetailerId,
    required List<Map<String, dynamic>> availableSlots,
    required List<Map<String, dynamic>> services,
    required int numCars,
    required String paymentMethod,
  }) {
    final error = validate(
      address: address,
      selectedDay: selectedDay,
      vehicles: vehicles,
      times: times,
      selectedDetailerId: selectedDetailerId,
      availableSlots: availableSlots,
    );
    if (error != null) return null;

    final detailerId = nextDetailerId(
      selectedDetailerId: selectedDetailerId,
      availableSlots: availableSlots,
    );
    if (detailerId == null) return null;

    final cars = <Map<String, dynamic>>[];
    for (var i = 0; i < numCars; i++) {
      cars.add({
        'vehicle': vehicles[i].trim(),
        'time': times[i]!.trim(),
      });
    }

    return BookingDraft(
      customerId: customerId,
      date: selectedDay!,
      cars: cars,
      services: services,
      totalPrice: BookingQuote.total(services: services, numCars: numCars),
      assignedDetailerId: detailerId,
      address: address.trim(),
      notes: notes.trim(),
      paymentMethod: paymentMethod,
    );
  }
}

class BookingSlots {
  static Set<String> bookedTimesFromDocs(List<Map<String, dynamic>> bookings) {
    return bookings
        .map((b) {
          final cars = b['cars'];
          if (cars is List && cars.isNotEmpty) {
            final first = cars.first;
            if (first is Map && first['time'] != null) {
              return first['time'].toString();
            }
          }
          return (b['time'] ?? '').toString();
        })
        .where((t) => t.isNotEmpty)
        .toSet();
  }

  static Map<String, dynamic>? freeEntry({
    required String region,
    required List<String> regions,
    required List<String> timeSlots,
    required Set<String> bookedTimes,
    required String employeeId,
    required String employeeName,
  }) {
    if (!regions.contains(region)) return null;
    final freeSlots =
        timeSlots.where((slot) => !bookedTimes.contains(slot)).toList();
    if (freeSlots.isEmpty) return null;
    return {
      'employeeId': employeeId,
      'employeeName': employeeName,
      'slots': freeSlots,
    };
  }
}

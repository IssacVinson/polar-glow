import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/booking/booking_flow.dart';

void main() {
  const services = [
    {'id': 'full', 'name': 'Full Interior', 'price': 175.0},
    {'id': 'tlc', 'name': 'Extra TLC', 'price': 50.0},
  ];

  const slots = [
    {
      'employeeId': 'emp-1',
      'employeeName': 'Alex',
      'slots': ['9:00 AM – 11:00 AM'],
    },
    {
      'employeeId': 'emp-2',
      'employeeName': 'Jordan',
      'slots': ['1:00 PM – 3:00 PM'],
    },
  ];

  group('BookingQuote', () {
    test('sums selected services times the car count', () {
      expect(
        BookingQuote.total(services: services, numCars: 1),
        225.0,
      );
      expect(
        BookingQuote.total(services: services, numCars: 2),
        450.0,
      );
    });
  });

  group('BookingFlow.validate', () {
    test('requires address, date, times, vehicles, and a detailer', () {
      expect(
        BookingFlow.validate(
          address: '',
          selectedDay: DateTime(2026, 8, 27),
          vehicles: ['Black Camry'],
          times: ['9:00 AM'],
          selectedDetailerId: 'emp-1',
          availableSlots: slots,
        )?.code,
        BookingValidationCode.missingAddress,
      );
      expect(
        BookingFlow.validate(
          address: '123 Eagle River Rd',
          selectedDay: null,
          vehicles: ['Black Camry'],
          times: ['9:00 AM'],
          selectedDetailerId: 'emp-1',
          availableSlots: slots,
        )?.code,
        BookingValidationCode.missingDate,
      );
      expect(
        BookingFlow.validate(
          address: '123 Eagle River Rd',
          selectedDay: DateTime(2026, 8, 27),
          vehicles: ['Black Camry'],
          times: [null],
          selectedDetailerId: 'emp-1',
          availableSlots: slots,
        )?.code,
        BookingValidationCode.missingCarTime,
      );
      expect(
        BookingFlow.validate(
          address: '123 Eagle River Rd',
          selectedDay: DateTime(2026, 8, 27),
          vehicles: [''],
          times: ['9:00 AM'],
          selectedDetailerId: 'emp-1',
          availableSlots: slots,
        )?.message,
        'Please enter vehicle info for car 1',
      );
      expect(
        BookingFlow.validate(
          address: '123 Eagle River Rd',
          selectedDay: DateTime(2026, 8, 27),
          vehicles: ['Black Camry'],
          times: ['9:00 AM'],
          selectedDetailerId: null,
          availableSlots: const [],
        )?.code,
        BookingValidationCode.noDetailers,
      );
    });
  });

  group('customer booking happy path', () {
    test('cash booking assigns the next available detailer', () {
      final draft = BookingFlow.buildDraft(
        customerId: 'cust-1',
        address: '  123 Eagle River Rd  ',
        notes: ' Gate code 1234 ',
        selectedDay: DateTime(2026, 8, 27),
        vehicles: ['Black Toyota Camry'],
        times: ['9:00 AM'],
        selectedDetailerId: null,
        availableSlots: slots,
        services: services,
        numCars: 1,
        paymentMethod: 'cash',
      );

      expect(draft, isNotNull);
      expect(draft!.assignedDetailerId, 'emp-1');
      expect(draft.totalPrice, 225.0);
      expect(draft.paymentMethod, 'cash');
      expect(draft.paymentStatus, 'unpaid');
      expect(draft.status, 'pending');
      expect(draft.address, '123 Eagle River Rd');
      expect(draft.notes, 'Gate code 1234');
      expect(draft.cars.single, {
        'vehicle': 'Black Toyota Camry',
        'time': '9:00 AM',
      });
    });

    test('card booking keeps a chosen detailer and stripe method', () {
      final draft = BookingFlow.buildDraft(
        customerId: 'cust-1',
        address: '123 Eagle River Rd',
        notes: '',
        selectedDay: DateTime(2026, 8, 27),
        vehicles: ['White F-150'],
        times: ['1:00 PM'],
        selectedDetailerId: 'emp-2',
        availableSlots: slots,
        services: services,
        numCars: 1,
        paymentMethod: 'stripe',
      );

      expect(draft, isNotNull);
      expect(draft!.assignedDetailerId, 'emp-2');
      expect(draft.paymentMethod, 'stripe');
      expect(draft.paymentStatus, 'unpaid');
    });

    test('two cars multiply the quote and keep both vehicles', () {
      final draft = BookingFlow.buildDraft(
        customerId: 'cust-1',
        address: '123 Eagle River Rd',
        notes: '',
        selectedDay: DateTime(2026, 8, 27),
        vehicles: ['Black Camry', 'White F-150'],
        times: ['9:00 AM', '1:00 PM'],
        selectedDetailerId: 'emp-1',
        availableSlots: slots,
        services: services,
        numCars: 2,
        paymentMethod: 'cash',
      );

      expect(draft!.totalPrice, 450.0);
      expect(draft.cars, hasLength(2));
    });
  });

  group('BookingSlots', () {
    test('drops booked times and employees outside the region', () {
      final booked = BookingSlots.bookedTimesFromDocs([
        {
          'cars': [
            {'time': '9:00 AM – 11:00 AM'}
          ]
        },
        {'time': 'legacy-slot'},
      ]);
      expect(booked, containsAll(['9:00 AM – 11:00 AM', 'legacy-slot']));

      expect(
        BookingSlots.freeEntry(
          region: 'Palmer',
          regions: const ['Eagle River'],
          timeSlots: const ['9:00 AM – 11:00 AM', '1:00 PM – 3:00 PM'],
          bookedTimes: booked,
          employeeId: 'emp-1',
          employeeName: 'Alex',
        ),
        isNull,
      );

      final free = BookingSlots.freeEntry(
        region: 'Eagle River',
        regions: const ['Eagle River', 'Palmer'],
        timeSlots: const ['9:00 AM – 11:00 AM', '1:00 PM – 3:00 PM'],
        bookedTimes: booked,
        employeeId: 'emp-1',
        employeeName: 'Alex',
      );
      expect(free, isNotNull);
      expect(free!['slots'], ['1:00 PM – 3:00 PM']);
    });
  });
}

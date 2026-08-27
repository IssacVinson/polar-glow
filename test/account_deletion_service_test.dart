import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/services/account_deletion_rules.dart';

void main() {
  group('AccountDeletionRules', () {
    test('anonymizes completed or paid jobs and deletes the rest', () {
      expect(
        AccountDeletionRules.shouldAnonymizeBooking({'status': 'completed'}),
        isTrue,
      );
      expect(
        AccountDeletionRules.shouldAnonymizeBooking({
          'status': 'pending',
          'paymentStatus': 'paid',
        }),
        isTrue,
      );
      expect(
        AccountDeletionRules.shouldAnonymizeBooking({
          'status': 'pending',
          'paid': true,
        }),
        isTrue,
      );
      expect(
        AccountDeletionRules.shouldAnonymizeBooking({
          'status': 'pending',
          'paymentStatus': 'unpaid',
        }),
        isFalse,
      );
    });

    test('clears personal fields on anonymized bookings', () {
      expect(AccountDeletionRules.anonymizedFields(), {
        'customerId': 'deleted_user',
        'address': '',
        'notes': '',
      });
    });

    test('falls back only when the callable is missing', () {
      expect(
        AccountDeletionRules.isMissingCallable(code: 'not-found'),
        isTrue,
      );
      expect(
        AccountDeletionRules.isMissingCallable(code: 'unimplemented'),
        isTrue,
      );
      expect(
        AccountDeletionRules.isMissingCallable(code: 'unavailable'),
        isTrue,
      );
      expect(
        AccountDeletionRules.isMissingCallable(
          code: 'internal',
          message: 'Function deleteOwnAccount not found',
        ),
        isTrue,
      );
      expect(
        AccountDeletionRules.isMissingCallable(
          code: 'permission-denied',
          message: 'Missing permissions',
        ),
        isFalse,
      );
    });
  });

  test('client service and Cloud Function stay on the same rules', () {
    final service = File('lib/core/services/account_deletion_service.dart')
        .readAsStringSync();
    final function = File('functions/index.js').readAsStringSync();
    final settings = File('lib/screens/settings_screen.dart').readAsStringSync();

    expect(service.contains('AccountDeletionRules.shouldAnonymizeBooking'),
        isTrue);
    expect(service.contains('AccountDeletionRules.callableName'), isTrue);
    expect(function.contains('exports.deleteOwnAccount'), isTrue);
    expect(function.contains('auth.deleteUser(uid)'), isTrue);
    expect(function.contains("customerId: \"deleted_user\""), isTrue);
    expect(settings.contains('Delete account'), isTrue);
    expect(settings.contains('Delete my account'), isTrue);
    expect(settings.contains('Confirm with your password'), isTrue);
  });
}

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/constants/app_constants.dart';

void main() {
  test('Android targets API 36, not Flutter-default 35', () {
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();
    expect(RegExp(r'compileSdk\s*=\s*36').hasMatch(gradle), isTrue);
    expect(RegExp(r'targetSdk\s*=\s*36').hasMatch(gradle), isTrue);
    expect(RegExp(r'compileSdk\s*=\s*flutter\.').hasMatch(gradle), isFalse);
    expect(RegExp(r'targetSdk\s*=\s*flutter\.').hasMatch(gradle), isFalse);
    expect(
        RegExp(r'(compileSdk|targetSdk)\s*=\s*35').hasMatch(gradle), isFalse);
  });

  test('in-app deletion removes Firebase Auth and Firestore data', () {
    final service = File('lib/core/services/account_deletion_service.dart')
        .readAsStringSync();
    final function = File('functions/index.js').readAsStringSync();
    final settings =
        File('lib/screens/settings_screen.dart').readAsStringSync();
    expect(settings.contains('Delete account'), isTrue);
    expect(service.contains('deleteOwnAccount'), isTrue);
    expect(service.contains('.delete()'), isTrue);
    expect(function.contains('exports.deleteOwnAccount'), isTrue);
    expect(function.contains('auth.deleteUser(uid)'), isTrue);
    expect(function.contains('userRef.delete()'), isTrue);
  });

  test('public legal URLs point at GitHub Pages', () {
    expect(AppConstants.privacyPolicyUrl,
        'https://issacvinson.github.io/polar-glow/privacy_policy.html');
    expect(AppConstants.deleteAccountUrl,
        'https://issacvinson.github.io/polar-glow/delete-account.html');
  });

  test('service regions keep existing labels and add Palmer', () {
    expect(AppConstants.serviceRegions, contains('Eagle River'));
    expect(AppConstants.serviceRegions, contains('Anchorage'));
    expect(AppConstants.serviceRegions, contains('Wasilla'));
    expect(AppConstants.serviceRegions, contains('Base (JBER)'));
    expect(AppConstants.serviceRegions, contains('Palmer'));
  });

  test('phone number matches the live business', () {
    expect(AppConstants.phoneDisplay, '(907) 406-5088');
    expect(AppConstants.phoneDigits, '9074065088');
  });
}

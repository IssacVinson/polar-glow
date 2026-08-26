import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/constants/app_constants.dart';

void main() {
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

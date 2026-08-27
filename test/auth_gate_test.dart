import 'package:flutter_test/flutter_test.dart';
import 'package:polar_glow/core/auth/auth_gate.dart';

void main() {
  test('unsigned users see the login shell', () {
    expect(
      AuthGate.destination(isLoading: false, signedIn: false),
      AuthDestination.login,
    );
  });

  test('auth listener shows loading before the first event', () {
    expect(
      AuthGate.destination(isLoading: true, signedIn: false),
      AuthDestination.loading,
    );
    expect(
      AuthGate.destination(isLoading: true, signedIn: true, role: 'admin'),
      AuthDestination.loading,
    );
  });

  test('signed-in roles route to the matching shell', () {
    expect(
      AuthGate.destination(
        isLoading: false,
        signedIn: true,
        role: 'customer',
      ),
      AuthDestination.customer,
    );
    expect(
      AuthGate.destination(isLoading: false, signedIn: true, role: 'ADMIN'),
      AuthDestination.admin,
    );
    expect(
      AuthGate.destination(
        isLoading: false,
        signedIn: true,
        role: 'employee',
      ),
      AuthDestination.employee,
    );
    expect(
      AuthGate.destination(isLoading: false, signedIn: true),
      AuthDestination.customer,
    );
  });
}

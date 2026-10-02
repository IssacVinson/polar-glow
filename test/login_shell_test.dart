import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:polar_glow/core/constants/app_constants.dart';
import 'package:polar_glow/core/theme/app_theme.dart';
import 'package:polar_glow/screens/customer_shell.dart';
import 'package:polar_glow/screens/customer_services_screen.dart';
import 'package:polar_glow/screens/login_screen.dart';
import 'package:polar_glow/core/models/service_model.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('login shell shows brand, sign-in, and sign-up', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const LoginScreen(),
      ),
    );
    await tester.pump();

    expect(find.text('POLAR GLOW'), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('SIGN IN'), findsOneWidget);
    expect(find.text("Don't have an account? Sign up"), findsOneWidget);
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('EAGLE RIVER, ALASKA'), findsOneWidget);
    expect(find.text(AppConstants.tagline), findsOneWidget);
    expect(
      find.text('CALL ${AppConstants.phoneDisplay}'.toUpperCase()),
      findsOneWidget,
    );
  });

  testWidgets('customer shell switches Home / Book / Bookings / Account',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const CustomerShell(
          pages: [
            Text('home-tab'),
            Text('book-tab'),
            Text('bookings-tab'),
            Text('account-tab'),
          ],
        ),
      ),
    );

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Book'), findsOneWidget);
    expect(find.text('Bookings'), findsOneWidget);
    expect(find.text('Account'), findsOneWidget);
    expect(find.text('home-tab'), findsOneWidget);

    await tester.tap(find.text('Book'));
    await tester.pump();
    expect(find.text('book-tab'), findsOneWidget);

    await tester.tap(find.text('Account'));
    await tester.pump();
    expect(find.text('account-tab'), findsOneWidget);
  });

  testWidgets('Book tab enables checkout after region and base service',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: CustomerServicesScreen(
          embedded: true,
          loadServices: () async => [
            ServiceModel(
              id: 'full',
              name: 'Full Interior',
              price: 175,
              category: 'base',
              description: 'Shampoo included',
            ),
            ServiceModel(
              id: 'tlc',
              name: 'Extra TLC',
              price: 50,
              category: 'add_on',
              description: 'Add-on',
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Full Interior'), findsOneWidget);
    expect(find.text('Extra TLC'), findsOneWidget);
    expect(find.text('Book Selected'), findsOneWidget);

    final bookButton = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Book Selected'),
    );
    expect(bookButton.onPressed, isNull);

    await tester.tap(find.text('Full Interior'));
    await tester.pump();

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eagle River').last);
    await tester.pumpAndSettle();

    final enabled = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Book Selected'),
    );
    expect(enabled.onPressed, isNotNull);
    expect(find.text('1 service'), findsOneWidget);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:polar_glow/core/theme/app_theme.dart';
import 'package:polar_glow/core/widgets/booking_pay_bar.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('booking pay bar shows cash and card actions with the quote',
      (tester) async {
    var cardTaps = 0;
    var cashTaps = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          bottomNavigationBar: BookingPayBar(
            totalPrice: 225,
            isProcessing: false,
            onPayCard: () => cardTaps++,
            onPayCash: () => cashTaps++,
          ),
        ),
      ),
    );

    expect(find.text('Pay in Full Now \$225.00'), findsOneWidget);
    expect(find.text('Pay Cash When Detailer Arrives'), findsOneWidget);

    await tester.tap(find.text('Pay Cash When Detailer Arrives'));
    await tester.tap(find.text('Pay in Full Now \$225.00'));
    expect(cardTaps, 1);
    expect(cashTaps, 1);
  });

  testWidgets('booking pay bar disables actions while processing',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          bottomNavigationBar: BookingPayBar(
            totalPrice: 175,
            isProcessing: true,
            onPayCard: () {},
            onPayCash: () {},
          ),
        ),
      ),
    );

    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}

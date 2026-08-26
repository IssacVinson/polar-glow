import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:polar_glow/core/theme/app_colors.dart';
import 'package:polar_glow/core/theme/app_theme.dart';
import 'package:polar_glow/core/widgets/app_widgets.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('brand colors match polarglowak.com', () {
    expect(AppColors.primary, const Color(0xFF0B1215));
    expect(AppColors.navy, const Color(0xFF0C2340));
    expect(AppColors.cyan, const Color(0xFF00AEEF));
  });

  testWidgets('theme uses cyan primary and dark scaffold', (tester) async {
    late ColorScheme scheme;
    late Color scaffold;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Builder(
          builder: (context) {
            scheme = Theme.of(context).colorScheme;
            scaffold = Theme.of(context).scaffoldBackgroundColor;
            return const SizedBox.shrink();
          },
        ),
      ),
    );
    expect(scheme.primary, AppColors.cyan);
    expect(scaffold, AppColors.primary);
  });

  testWidgets('empty and error states render copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: const Scaffold(
          body: GlowEmptyState(
            icon: Icons.event,
            title: 'No bookings yet',
            message: 'Book a mobile detail from the Book tab.',
          ),
        ),
      ),
    );
    expect(find.text('No bookings yet'), findsOneWidget);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: GlowErrorState(
            message: 'Failed to load services.',
            onRetry: () {},
          ),
        ),
      ),
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(find.text('TRY AGAIN'), findsOneWidget);
  });

  testWidgets('primary button uses uppercase label', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: GlowPrimaryButton(
            label: 'Book an appointment',
            onPressed: () {},
          ),
        ),
      ),
    );
    expect(find.text('BOOK AN APPOINTMENT'), findsOneWidget);
  });
}

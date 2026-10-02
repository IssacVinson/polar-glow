import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        actions: [
          IconButton(
            tooltip: 'Open public policy',
            onPressed: () => launchAppUrl(AppConstants.privacyPolicyUrl),
            icon: const Icon(Icons.open_in_new),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        children: [
          const GlowSectionLabel('Polar Glow Detailing'),
          const SizedBox(height: 8),
          Text(
            'Privacy Policy',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Effective Date: April 7, 2026',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _section(
            '1. Introduction',
            'Polar Glow Detailing ("we", "us", or "our") respects your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
          ),
          _section(
            '2. Information We Collect',
            '• Account Information: Name, username, email, phone number, and password (hashed).\n'
                '• Booking & Service Data: Vehicle details, service location (via Google Places), appointment times.\n'
                '• Payment Information: Processed securely by Stripe — we never store full card details.\n'
                '• Location Data: Used only to match you with detailers in your service area.\n'
                '• Usage Data: App interactions for improving our service.',
          ),
          _section(
            '3. How We Use Your Information',
            '• To create and manage your account\n'
                '• To process bookings and payments\n'
                '• To communicate with you about services and appointments\n'
                '• To provide customer support\n'
                '• To comply with legal obligations',
          ),
          _section(
            '4. How We Share Your Information',
            'We share data only as necessary with Firebase (authentication and database), Stripe (payments), and our detailers (only what is needed to complete a booking). We do not sell your personal data.',
          ),
          _section(
            '5. Data Security',
            'We use industry-standard security measures (Firebase security rules, encrypted connections). No system is 100% secure.',
          ),
          _section(
            '6. Your Rights',
            'You can access and update your profile in the app. You can delete your account and associated personal data at any time from Settings → Delete account. That in-app flow removes your Firebase Auth user and personal Firestore data. You may also email ${AppConstants.supportEmail}.',
          ),
          _section(
            '7. Children\'s Privacy',
            'Our app is not intended for children under 18. We do not knowingly collect data from children.',
          ),
          _section(
            '8. Changes to This Policy',
            'We may update this Privacy Policy. We will notify you of significant changes via the app or email.',
          ),
          _section(
            '9. Contact Us',
            'Questions about this Privacy Policy? Contact us at ${AppConstants.supportEmail}. Polar Glow Detailing, Eagle River, Alaska.',
          ),
          const SizedBox(height: 12),
          GlowOutlineButton(
            label: 'View public policy',
            icon: Icons.open_in_new,
            onPressed: () => launchAppUrl(AppConstants.privacyPolicyUrl),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.cyan,
                fontSize: 16,
              )),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(height: 1.5, fontSize: 15)),
        ],
      ),
    );
  }
}

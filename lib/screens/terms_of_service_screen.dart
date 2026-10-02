import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Terms of Service'),
        actions: [
          IconButton(
            tooltip: 'Open public terms',
            onPressed: () => launchAppUrl(AppConstants.termsOfServiceUrl),
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
            'Terms of Service',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 6),
          const Text(
            'Effective Date: April 7, 2026',
            style: TextStyle(color: AppColors.textMuted),
          ),
          const SizedBox(height: 20),
          _section(
            '1. Acceptance of Terms',
            'By creating an account or using the Polar Glow Detailing mobile application, you agree to be bound by these Terms of Service. If you do not agree, do not use the app.',
          ),
          _section(
            '2. Our Service',
            'Polar Glow Detailing provides on-location vehicle detailing services in the Anchorage, Eagle River, Chugiak, Wasilla, Palmer, and JBER, Alaska areas. We come to you. Services are booked and paid for through this app.',
          ),
          _section(
            '3. User Accounts',
            'You must be at least 18 years old to create an account. You are responsible for maintaining the confidentiality of your account credentials. You may delete your account at any time from Settings.',
          ),
          _section(
            '4. Bookings and Payments',
            '• All bookings are subject to availability.\n'
                '• Payments are processed securely via Stripe.\n'
                '• Cancellations must be made at least 24 hours in advance for a full refund (subject to Stripe fees).\n'
                '• No-shows or late cancellations may incur a fee.',
          ),
          _section(
            '5. Service Limitations and Liability',
            'We provide professional detailing services to the best of our ability. Polar Glow Detailing is not liable for pre-existing vehicle damage, damage caused by improper use of the vehicle after service, or any indirect, incidental, or consequential damages. Our maximum liability shall not exceed the amount paid for the service.',
          ),
          _section(
            '6. Privacy',
            'Please review our Privacy Policy for details on how we collect and use your information.',
          ),
          _section(
            '7. Governing Law',
            'These Terms are governed by the laws of the State of Alaska, United States. Any disputes shall be resolved in the courts of Anchorage, Alaska.',
          ),
          _section(
            '8. Changes to Terms',
            'We may update these Terms from time to time. Continued use of the app after changes constitutes acceptance of the new Terms.',
          ),
          _section(
            '9. Contact Us',
            'Questions? ${AppConstants.supportEmail} or ${AppConstants.phoneDisplay}. Polar Glow Detailing, Eagle River, Alaska.',
          ),
          const SizedBox(height: 12),
          GlowOutlineButton(
            label: 'View public terms',
            icon: Icons.open_in_new,
            onPressed: () => launchAppUrl(AppConstants.termsOfServiceUrl),
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

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Terms of Service',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Polar Glow Detailing – Terms of Service',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Effective Date: April 7, 2026',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            _buildSectionTitle('1. Acceptance of Terms'),
            _buildSectionText(
              'By creating an account or using the Polar Glow Detailing mobile application, you agree to be bound by these Terms of Service ("Terms"). If you do not agree, do not use the app.',
            ),
            _buildSectionTitle('2. Our Service'),
            _buildSectionText(
              'Polar Glow Detailing provides on-location vehicle detailing services in the Anchorage, Eagle River, Chugiak, Wasilla, and Palmer, Alaska areas. We come to you! Services are booked and paid for through this app.',
            ),
            _buildSectionTitle('3. User Accounts'),
            _buildSectionText(
              'You must be at least 18 years old to create an account. You are responsible for maintaining the confidentiality of your account credentials and all activities under your account.',
            ),
            _buildSectionTitle('4. Bookings and Payments'),
            _buildSectionText(
              '• All bookings are subject to availability.\n'
              '• Payments are processed securely via Stripe.\n'
              '• Cancellations must be made at least 24 hours in advance for a full refund (subject to Stripe fees).\n'
              '• No-shows or late cancellations may incur a fee.',
            ),
            _buildSectionTitle('5. Service Limitations and Liability'),
            _buildSectionText(
              'We provide professional detailing services to the best of our ability. However, Polar Glow Detailing is not liable for:\n'
              '• Pre-existing vehicle damage\n'
              '• Damage caused by improper use of the vehicle after service\n'
              '• Any indirect, incidental, or consequential damages\n\n'
              'Our maximum liability shall not exceed the amount paid for the service.',
            ),
            _buildSectionTitle('6. Privacy'),
            _buildSectionText(
              'Your privacy is important to us. Please review our Privacy Policy (linked in the app settings) for details on how we collect and use your information.',
            ),
            _buildSectionTitle('7. Governing Law'),
            _buildSectionText(
              'These Terms are governed by the laws of the State of Alaska, United States. Any disputes shall be resolved in the courts of Anchorage, Alaska.',
            ),
            _buildSectionTitle('8. Changes to Terms'),
            _buildSectionText(
              'We may update these Terms from time to time. We will notify you of material changes via the app or email. Continued use of the app after changes constitutes acceptance of the new Terms.',
            ),
            _buildSectionTitle('9. Contact Us'),
            _buildSectionText(
              'Questions about these Terms? Contact us at:\n'
              'polarglowdetailing@gmail.com\n'
              'Polar Glow Detailing\n'
              'Anchorage, Alaska',
            ),
            const SizedBox(height: 40),
            Text(
              'By using Polar Glow Detailing, you acknowledge that you have read, understood, and agree to these Terms of Service.',
              style: GoogleFonts.poppins(
                  fontSize: 14, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.blue.shade900,
        ),
      ),
    );
  }

  Widget _buildSectionText(String text) {
    return Text(
      text,
      style: GoogleFonts.poppins(fontSize: 15, height: 1.5),
    );
  }
}

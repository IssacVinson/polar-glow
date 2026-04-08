import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Privacy Policy',
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
              'Polar Glow Detailing – Privacy Policy',
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
            _buildSectionTitle('1. Introduction'),
            _buildSectionText(
              'Polar Glow Detailing ("we", "us", or "our") respects your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application.',
            ),
            _buildSectionTitle('2. Information We Collect'),
            _buildSectionText(
              '• Account Information: Name, username, email, phone number, and password (hashed).\n'
              '• Booking & Service Data: Vehicle details, service location (via Google Places), appointment times.\n'
              '• Payment Information: Processed securely by Stripe — we never store full card details.\n'
              '• Location Data: Used only to match you with detailers in your service area (Anchorage, Eagle River, etc.).\n'
              '• Usage Data: App interactions for improving our service.',
            ),
            _buildSectionTitle('3. How We Use Your Information'),
            _buildSectionText(
              '• To create and manage your account\n'
              '• To process bookings and payments\n'
              '• To communicate with you about services and appointments\n'
              '• To provide customer support\n'
              '• To comply with legal obligations',
            ),
            _buildSectionTitle('4. How We Share Your Information'),
            _buildSectionText(
              'We share data only as necessary:\n'
              '• With Firebase (for authentication and database)\n'
              '• With Stripe (for secure payments)\n'
              '• With our detailers/employees (only the information needed to complete your booking)\n'
              'We do NOT sell your personal data to third parties.',
            ),
            _buildSectionTitle('5. Data Security'),
            _buildSectionText(
              'We use industry-standard security measures (Firebase security rules, encrypted connections, etc.) to protect your information. However, no system is 100% secure.',
            ),
            _buildSectionTitle('6. Your Rights'),
            _buildSectionText(
              'You can:\n'
              '• Access, update, or delete your account data at any time from the app settings\n'
              '• Request deletion of your data (subject to legal requirements)\n'
              '• Opt out of marketing communications',
            ),
            _buildSectionTitle('7. Children\'s Privacy'),
            _buildSectionText(
              'Our app is not intended for children under 18. We do not knowingly collect data from children.',
            ),
            _buildSectionTitle('8. Changes to This Policy'),
            _buildSectionText(
              'We may update this Privacy Policy. We will notify you of significant changes via the app or email.',
            ),
            _buildSectionTitle('9. Contact Us'),
            _buildSectionText(
              'Questions about this Privacy Policy? Contact us at:\n'
              'polarglowdetailing@gmail.com\n'
              'Polar Glow Detailing\n'
              'Anchorage, Alaska',
            ),
            const SizedBox(height: 40),
            Text(
              'By using Polar Glow Detailing, you consent to the practices described in this Privacy Policy.',
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

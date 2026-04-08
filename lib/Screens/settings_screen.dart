import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Color get _accentColor => const Color(0xFF00E5FF);

  Future<void> _launchURL(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // Account Section
          ListTile(
            leading: Icon(Icons.account_circle, color: _accentColor, size: 28),
            title: const Text('Account',
                style: TextStyle(fontSize: 18, color: Colors.white)),
            subtitle: Text(
              FirebaseAuth.instance.currentUser?.email ?? '',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          const Divider(color: Colors.white24),

          // Legal Section
          const Padding(
            padding: EdgeInsets.only(top: 16, bottom: 8),
            child: Text(
              'Legal',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
          ),

          ListTile(
            leading:
                const Icon(Icons.description_outlined, color: Colors.white70),
            title: const Text('Terms of Service',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const TermsOfServiceScreen())),
          ),
          ListTile(
            leading:
                const Icon(Icons.privacy_tip_outlined, color: Colors.white70),
            title: const Text('Privacy Policy',
                style: TextStyle(color: Colors.white)),
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen())),
          ),

          const Divider(color: Colors.white24),

          // Public web links
          ListTile(
            leading: const Icon(Icons.public, color: Colors.white70),
            title: const Text('Terms of Service (web)',
                style: TextStyle(color: Colors.white)),
            onTap: () => _launchURL(
                'https://issacvinson.github.io/polar-glow/terms_of_service.html'),
          ),
          ListTile(
            leading: const Icon(Icons.public, color: Colors.white70),
            title: const Text('Privacy Policy (web)',
                style: TextStyle(color: Colors.white)),
            onTap: () => _launchURL(
                'https://issacvinson.github.io/polar-glow/privacy_policy.html'),
          ),

          const Divider(color: Colors.white24),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Sign Out',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w600)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.popUntil(context, (route) => route.isFirst);
              }
            },
          ),
        ],
      ),
    );
  }
}

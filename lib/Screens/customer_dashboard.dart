import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'customer_services_screen.dart';
import 'customer_my_bookings_screen.dart';
import 'customer_feedback_screen.dart';
import 'profile_screen.dart'; // ← New import

class CustomerDashboard extends StatelessWidget {
  const CustomerDashboard({super.key});

  // Polar Glow brand colors
  Color get _accentColor => const Color(0xFF00E5FF); // icy cyan
  Color get _bookingsColor => const Color(0xFF06B67F); // vibrant teal
  Color get _feedbackColor => const Color(0xFFFFD700); // gold
  Color get _profileColor => const Color(0xFF9C27B0); // purple for profile

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Polar Glow Detailing',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Signed out successfully'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Sign out failed: $e'),
                      backgroundColor: Colors.redAccent,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with premium animation
              Image.asset(
                'assets/images/logo.png',
                width: 240,
                height: 240,
                fit: BoxFit.contain,
              )
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .scaleXY(begin: 0.85, end: 1.0, curve: Curves.easeOutBack),

              const SizedBox(height: 48),

              // Welcome heading
              Text(
                'Welcome to Polar Glow!',
                style: textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Subtitle
              Text(
                'Professional car detailing across Eagle River, Anchorage, Wasilla, and JBER.\n'
                'Book your next shine today!',
                style: textTheme.titleMedium?.copyWith(
                  color: Colors.white70,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 64),

              // Book Appointment - Cyan (main CTA)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 26),
                  label: const Text(
                    'Book an Appointment',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accentColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 12,
                    shadowColor: _accentColor.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerServicesScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // View My Bookings - Teal
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.list_alt, size: 26),
                  label: const Text(
                    'View My Bookings',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _bookingsColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 10,
                    shadowColor: _bookingsColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerMyBookingsScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // Give Feedback - Gold with glow
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.feedback_rounded, size: 26),
                  label: const Text(
                    'Give Feedback',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _feedbackColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 14,
                    shadowColor: _feedbackColor.withOpacity(0.7),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CustomerFeedbackScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 18),

              // NEW: My Profile - Purple
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(Icons.person, size: 26),
                  label: const Text(
                    'My Profile',
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _profileColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    elevation: 12,
                    shadowColor: _profileColor.withOpacity(0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileScreen(),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 64),

              // Footer tagline
              Text(
                'Serving Alaska Since 2024 • Expert Attention to Detail • Satisfaction Guaranteed',
                style: textTheme.bodySmall?.copyWith(
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

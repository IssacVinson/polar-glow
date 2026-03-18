import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'booking_screen.dart';
import 'services_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Polar Glow Detailing'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Sign out',
            onPressed: () async {
              try {
                await FirebaseAuth.instance.signOut();
                // No need to navigate — AuthWrapper stream will handle going back to LoginScreen
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Signed out successfully'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sign out failed: $e'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with fade + scale animation
              Image.asset(
                    'assets/images/logo.png',
                    width: 240,
                    height: 240,
                    fit: BoxFit.contain,
                  )
                  .animate()
                  .fadeIn(duration: 800.ms, curve: Curves.easeOut)
                  .scaleXY(begin: 0.85, end: 1.0, curve: Curves.easeOutBack),

              const SizedBox(height: 40),

              const Text(
                'Welcome to Polar Glow!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              const Text(
                'Professional car detailing across Anchorage, Wasilla, Eagle River, and JBER.\n'
                'Book your next shine today!',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.white70,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 56),

              // Book Appointment Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text(
                    'Book an Appointment',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const BookingScreen(selectedServices: []),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 20),

              // View Services Button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.list_alt),
                  label: const Text(
                    'View Services & Pricing',
                    style: TextStyle(fontSize: 18),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.cyan, width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ServicesScreen()),
                    );
                  },
                ),
              ),

              const SizedBox(height: 48),

              const Text(
                'Serving Alaska since 2025 • Eco-friendly • Satisfaction guaranteed',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white54,
                  fontStyle: FontStyle.italic,
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

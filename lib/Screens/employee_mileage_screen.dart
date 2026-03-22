import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart';

class EmployeeMileageScreen extends StatefulWidget {
  const EmployeeMileageScreen({super.key});

  @override
  State<EmployeeMileageScreen> createState() => _EmployeeMileageScreenState();
}

class _EmployeeMileageScreenState extends State<EmployeeMileageScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _selectedDate = DateTime.now();
  final _startController = TextEditingController();
  final _endController = TextEditingController();
  final _notesController = TextEditingController();

  double _milesDriven = 0.0;
  double _reimbursement = 0.0;
  final double _ratePerMile = 0.67; // Standard IRS rate — easy to change later

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _startController.addListener(_calculate);
    _endController.addListener(_calculate);
  }

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _calculate() {
    final start = double.tryParse(_startController.text) ?? 0;
    final end = double.tryParse(_endController.text) ?? 0;
    final miles = end > start ? end - start : 0.0;

    setState(() {
      _milesDriven = miles;
      _reimbursement = miles * _ratePerMile;
    });
  }

  Future<void> _submitClaim() async {
    if (!_formKey.currentState!.validate()) return;

    final start = double.tryParse(_startController.text) ?? 0;
    final end = double.tryParse(_endController.text) ?? 0;

    if (end <= start) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Ending miles must be greater than starting miles')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final uid = context.read<AuthProvider>().user!.uid;

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('mileageClaims')
          .add({
        'date': Timestamp.fromDate(_selectedDate),
        'startMiles': start,
        'endMiles': end,
        'milesDriven': _milesDriven,
        'reimbursement': _reimbursement,
        'notes': _notesController.text.trim(),
        'status': 'pending', // admin can approve later
        'submittedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Mileage claim submitted!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context); // go back to dashboard
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mileage Reimbursement'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: ListTile(
                  title: const Text('Date'),
                  subtitle: Text(
                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate)),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: _pickDate,
                ),
              ),
              const SizedBox(height: 20),

              // Starting Miles
              TextFormField(
                controller: _startController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Starting Odometer Reading',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Ending Miles
              TextFormField(
                controller: _endController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Ending Odometer Reading',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.speed),
                ),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),

              // Live Calculation
              Card(
                color: Colors.blueGrey[900],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Miles Driven',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '${_milesDriven.toStringAsFixed(1)} mi',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Reimbursement',
                              style: TextStyle(fontSize: 16)),
                          Text(
                            '\$${_reimbursement.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.cyanAccent,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '@ \$${_ratePerMile.toStringAsFixed(2)} per mile',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'e.g. Anchorage to Wasilla round trip',
                ),
              ),
              const SizedBox(height: 32),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitClaim,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Submit Mileage Claim',
                          style: TextStyle(fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

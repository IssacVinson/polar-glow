import 'package:flutter/material.dart';

import '../core/models/service_model.dart';
import '../core/services/firestore_service.dart';
import 'booking_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<ServiceModel> _services = [];
  String? _errorMessage;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final services = await _firestore.getServices();
      if (mounted) {
        setState(() {
          _services = services;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load services.\n\n'
              'Please check your internet connection\n'
              'or ask your admin to check Firestore rules.';
          _loading = false;
        });
      }
    }
  }

  List<ServiceModel> get _selected {
    return _services.where((s) => _selectedServices[s.id] == true).toList();
  }

  // Track selected state by service ID
  final Map<String, bool> _selectedServices = {};

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services & Pricing'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            size: 60, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Try Again'),
                          onPressed: _loadServices,
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: _services.isEmpty
                          ? const Center(
                              child: Text('No services available yet'))
                          : ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _services.length,
                              itemBuilder: (context, index) {
                                final service = _services[index];
                                final isSelected =
                                    _selectedServices[service.id] ?? false;

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 16),
                                  color: service.category == 'add_on'
                                      ? Colors.blueGrey[800]
                                      : Colors.blueGrey[700],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: CheckboxListTile(
                                    value: isSelected,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        _selectedServices[service.id] =
                                            value ?? false;
                                      });
                                    },
                                    title: Text(
                                      service.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '\$${service.price.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: service.category == 'add_on'
                                                ? Colors.cyan[300]
                                                : Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          service.description,
                                          style: const TextStyle(
                                              color: Colors.white70),
                                        ),
                                      ],
                                    ),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    activeColor: Colors.cyan[400],
                                    checkColor: Colors.black,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),

                    // Bottom action bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[850],
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, -4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Selected',
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14),
                              ),
                              Text(
                                hasSelection
                                    ? '${_selected.length} service${_selected.length != 1 ? "s" : ""}'
                                    : 'None selected',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          ElevatedButton.icon(
                            onPressed: hasSelection
                                ? () {
                                    final selectedMaps = _selected
                                        .map((s) => {
                                              'id': s.id,
                                              'name': s.name,
                                              'price': s.price,
                                              'description': s.description,
                                            })
                                        .toList();

                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => BookingScreen(
                                            selectedServices: selectedMaps),
                                      ),
                                    );
                                  }
                                : null,
                            icon: const Icon(Icons.calendar_today, size: 20),
                            label: const Text('Book Selected',
                                style: TextStyle(fontSize: 16)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: hasSelection
                                  ? Colors.cyan[700]
                                  : Colors.grey[700],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

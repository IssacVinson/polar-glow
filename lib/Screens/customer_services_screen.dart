// lib/screens/customer_services_screen.dart
// UPDATED FILE — Replace your entire customer_services_screen.dart with this exact code

import 'package:flutter/material.dart';

import '../core/models/service_model.dart';
import '../core/services/firestore_service.dart';
import 'customer_booking_screen.dart';

class CustomerServicesScreen extends StatefulWidget {
  const CustomerServicesScreen({super.key});

  @override
  State<CustomerServicesScreen> createState() => _CustomerServicesScreenState();
}

class _CustomerServicesScreenState extends State<CustomerServicesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<ServiceModel> _services = [];
  String? _errorMessage;
  bool _loading = true;

  // NEW: Region selection
  String? _selectedRegion;

  final List<String> _regions = [
    'Anchorage',
    'Wasilla',
    'Eagle River',
    'Base (JBER)'
  ];

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

  List<ServiceModel> get _baseServices =>
      _services.where((s) => s.category != 'add_on').toList();

  List<ServiceModel> get _addOnServices =>
      _services.where((s) => s.category == 'add_on').toList();

  bool get _hasBaseService => _selected.any((s) => s.category != 'add_on');

  final Map<String, bool> _selectedServices = {};

  bool get _canContinue => _hasBaseService && _selectedRegion != null;

  @override
  Widget build(BuildContext context) {
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
                        Text(_errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16)),
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
                          : ListView(
                              padding: const EdgeInsets.all(16),
                              children: [
                                // Base Services Banner
                                _buildSectionHeader('Base Services'),
                                const SizedBox(height: 8),
                                ..._baseServices.map(
                                    (service) => _buildServiceCard(service)),

                                const SizedBox(height: 32),

                                // Add Ons Banner
                                _buildSectionHeader('Add Ons'),
                                const SizedBox(height: 8),
                                ..._addOnServices.map(
                                    (service) => _buildServiceCard(service)),
                              ],
                            ),
                    ),

                    // Bottom action bar with Region selector
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[850],
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.4),
                              blurRadius: 12,
                              offset: const Offset(0, -4))
                        ],
                      ),
                      child: Column(
                        children: [
                          // Region selector
                          DropdownButtonFormField<String>(
                            value: _selectedRegion,
                            decoration: const InputDecoration(
                              labelText: 'Select Your Region',
                              border: OutlineInputBorder(),
                            ),
                            hint: const Text('Choose region'),
                            items: _regions
                                .map((r) =>
                                    DropdownMenuItem(value: r, child: Text(r)))
                                .toList(),
                            onChanged: (value) {
                              setState(() => _selectedRegion = value);
                            },
                          ),
                          const SizedBox(height: 12),

                          // Warning when only add-ons are selected
                          if (_selected.isNotEmpty && !_hasBaseService)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Text(
                                'You must select at least one Base Service',
                                style: TextStyle(
                                  color: Colors.orange[300],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Selected',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 14)),
                                  Text(
                                    _selected.isNotEmpty
                                        ? '${_selected.length} service${_selected.length != 1 ? "s" : ""}'
                                        : 'None selected',
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: _canContinue
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
                                            builder: (_) =>
                                                CustomerBookingScreen(
                                              selectedServices: selectedMaps,
                                              selectedRegion: _selectedRegion!,
                                            ),
                                          ),
                                        );
                                      }
                                    : null,
                                icon:
                                    const Icon(Icons.calendar_today, size: 20),
                                label: const Text('Book Selected',
                                    style: TextStyle(fontSize: 16)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _canContinue
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
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: title == 'Base Services'
            ? Colors.blueGrey[700]
            : Colors.blueGrey[800],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    final isSelected = _selectedServices[service.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: service.category == 'add_on'
          ? Colors.blueGrey[800]
          : Colors.blueGrey[700],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            _selectedServices[service.id] = value ?? false;
          });
        },
        title: Text(service.name,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('\$${service.price.toStringAsFixed(2)}',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: service.category == 'add_on'
                        ? Colors.cyan[300]
                        : Colors.white)),
            const SizedBox(height: 4),
            Text(service.description,
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: Colors.cyan[400],
        checkColor: Colors.black,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
    );
  }
}

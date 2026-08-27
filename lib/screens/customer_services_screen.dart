import 'package:flutter/material.dart';

import '../core/constants/app_constants.dart';
import '../core/models/service_model.dart';
import '../core/services/firestore_service.dart';
import '../core/theme/app_colors.dart';
import '../core/widgets/app_widgets.dart';
import 'customer_booking_screen.dart';

class CustomerServicesScreen extends StatefulWidget {
  const CustomerServicesScreen({
    super.key,
    this.embedded = false,
    this.loadServices,
  });

  final bool embedded;

  /// Test override so the Book tab can be pumped without Firestore.
  final Future<List<ServiceModel>> Function()? loadServices;

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

  final List<String> _regions = AppConstants.serviceRegions;

  Color get _accentColor => AppColors.cyan;

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
      final services = await (widget.loadServices ?? _firestore.getServices)();
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Services & pricing'),
        automaticallyImplyLeading: !widget.embedded,
      ),
      body: _loading
          ? const GlowLoading(message: 'Loading services…')
          : _errorMessage != null
              ? GlowErrorState(
                  message: _errorMessage!,
                  onRetry: _loadServices,
                )
              : Column(
                  children: [
                    Expanded(
                      child: _services.isEmpty
                          ? const GlowEmptyState(
                              icon: Icons.spa_outlined,
                              title: 'No services yet',
                              message:
                                  'Check back soon or call Polar Glow to book by phone.',
                            )
                          : ListView(
                              padding:
                                  const EdgeInsets.fromLTRB(20, 20, 20, 20),
                              children: [
                                // Base Services Section
                                _buildSectionHeader(
                                  'Base Services',
                                  Icons.spa,
                                ),
                                const SizedBox(height: 12),
                                ..._baseServices.map(
                                    (service) => _buildServiceCard(service)),

                                const SizedBox(height: 40),

                                // Add Ons Section
                                _buildSectionHeader(
                                  'Add Ons',
                                  Icons.add_circle_outline,
                                ),
                                const SizedBox(height: 12),
                                ..._addOnServices.map(
                                    (service) => _buildServiceCard(service)),
                              ],
                            ),
                    ),
                  ],
                ),
      // ── FIXED BOTTOM BAR (no more overflow on S22 or any small phone) ──
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          decoration: const BoxDecoration(
            color: AppColors.navy,
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Region selector
              DropdownButtonFormField<String>(
                value: _selectedRegion,
                decoration: InputDecoration(
                  labelText: 'Select Your Region',
                  labelStyle: const TextStyle(color: Colors.white70),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                  filled: true,
                  fillColor: Colors.black12,
                  prefixIcon: Icon(Icons.location_on, color: _accentColor),
                ),
                dropdownColor: Colors.grey[850],
                style: const TextStyle(color: Colors.white, fontSize: 17),
                hint: const Text('Choose region',
                    style: TextStyle(color: Colors.white54)),
                items: _regions
                    .map((r) => DropdownMenuItem(
                          value: r,
                          child: Text(r,
                              style: const TextStyle(color: Colors.white)),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => _selectedRegion = value);
                },
              ),
              const SizedBox(height: 16),

              // Warning when only add-ons are selected
              if (_selected.isNotEmpty && !_hasBaseService)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange[900]!.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.orangeAccent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You must select at least one Base Service',
                          style: TextStyle(
                            color: Colors.orangeAccent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 16),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Selected',
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14)),
                      Text(
                        _selected.isNotEmpty
                            ? '${_selected.length} service${_selected.length != 1 ? "s" : ""}'
                            : 'None selected',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
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
                                builder: (_) => CustomerBookingScreen(
                                  selectedServices: selectedMaps,
                                  selectedRegion: _selectedRegion!,
                                ),
                              ),
                            );
                          }
                        : null,
                    icon: const Icon(Icons.calendar_today, size: 22),
                    label: const Text('Book Selected',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _canContinue ? _accentColor : Colors.grey[700],
                      foregroundColor:
                          _canContinue ? Colors.black : Colors.white70,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: _canContinue ? 8 : 0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _accentColor.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: _accentColor, size: 32),
          const SizedBox(width: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 0.5,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(ServiceModel service) {
    final isSelected = _selectedServices[service.id] ?? false;
    final isAddOn = service.category == 'add_on';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 8,
      shadowColor: _accentColor.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: AppColors.card,
      child: CheckboxListTile(
        value: isSelected,
        onChanged: (bool? value) {
          setState(() {
            _selectedServices[service.id] = value ?? false;
          });
        },
        title: Text(
          service.name,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Text(
              '\$${service.price.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isAddOn ? _accentColor : Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              service.description,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
          ],
        ),
        secondary: Icon(
          isAddOn ? Icons.add_circle_outline : Icons.spa,
          color: isAddOn ? _accentColor : Colors.white70,
          size: 36,
        ),
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _accentColor,
        checkColor: Colors.black,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}

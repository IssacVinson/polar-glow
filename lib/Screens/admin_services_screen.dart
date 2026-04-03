// lib/Screens/admin_services_screen.dart
// UPGRADED: Premium dark theme with glowing cards + cyan accents
// Fully consistent with EmployeeDashboard + all upgraded admin screens

import 'package:flutter/material.dart';

import '../core/models/service_model.dart';
import '../core/services/firestore_service.dart';

class AdminServicesScreen extends StatefulWidget {
  const AdminServicesScreen({super.key});

  @override
  State<AdminServicesScreen> createState() => _AdminServicesScreenState();
}

class _AdminServicesScreenState extends State<AdminServicesScreen> {
  final FirestoreService _firestore = FirestoreService();
  List<ServiceModel> _services = [];
  bool _loading = true;

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    setState(() => _loading = true);
    try {
      final services = await _firestore.getServices();
      if (mounted) {
        setState(() {
          _services = services;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showServiceDialog([ServiceModel? service]) {
    final nameCtrl = TextEditingController(text: service?.name);
    final priceCtrl = TextEditingController(text: service?.price.toString());
    final descCtrl = TextEditingController(text: service?.description);

    String selectedCategory = service?.category ?? '';

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[850],
              title: Text(
                service == null ? 'Add New Service' : 'Edit Service',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  letterSpacing: -0.5,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Service Name',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: priceCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Price (\$)',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      keyboardType:
                          TextInputType.numberWithOptions(decimal: true),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: descCtrl,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(color: Colors.white70),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),

                    // Premium category selector
                    const Text(
                      'Service Type',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'base',
                          label: Text('Base'),
                        ),
                        ButtonSegment(
                          value: 'add_on',
                          label: Text('Add-On'),
                        ),
                      ],
                      selected:
                          selectedCategory.isEmpty ? {} : {selectedCategory},
                      onSelectionChanged: (Set<String> newSelection) {
                        setDialogState(() {
                          selectedCategory = newSelection.first;
                        });
                      },
                      style: SegmentedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white70,
                        selectedBackgroundColor: _accentColor,
                        selectedForegroundColor: Colors.black,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      emptySelectionAllowed: true,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel',
                      style: TextStyle(color: Colors.white70)),
                ),
                TextButton(
                  onPressed: isSaving ||
                          (service == null && selectedCategory.isEmpty)
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);

                          final svc = ServiceModel(
                            id: service?.id ?? '',
                            name: nameCtrl.text.trim(),
                            price: double.tryParse(priceCtrl.text) ?? 0,
                            category: selectedCategory,
                            description: descCtrl.text.trim(),
                          );

                          try {
                            if (service == null) {
                              await _firestore.addService(svc);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        '✅ Service added successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } else {
                              await _firestore.updateService(service.id, svc);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        '✅ Service updated successfully!'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            }
                            Navigator.pop(ctx);
                            _loadServices();
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Failed: ${e.toString()}'),
                                    backgroundColor: Colors.red),
                              );
                            }
                          } finally {
                            if (mounted) setDialogState(() => isSaving = false);
                          }
                        },
                  child: isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(service == null ? 'Add Service' : 'Save Changes',
                          style: TextStyle(color: _accentColor)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Manage Services',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: _accentColor, size: 28),
            onPressed: () => _showServiceDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              itemCount: _services.length,
              itemBuilder: (ctx, i) {
                final s = _services[i];
                return Card(
                  margin: const EdgeInsets.only(bottom: 20),
                  elevation: 16,
                  shadowColor: _accentColor.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                  color: Colors.grey[850],
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 20 : 24,
                        vertical: isSmallScreen ? 12 : 16),
                    title: Text(
                      s.name,
                      style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                    ),
                    subtitle: Text(
                      '${s.category.toUpperCase()} • \$${s.price.toStringAsFixed(2)}\n${s.description}',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.edit_rounded,
                              color: _accentColor, size: 26),
                          onPressed: () => _showServiceDialog(s),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_rounded,
                              color: Colors.red, size: 26),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                backgroundColor: Colors.grey[850],
                                title: const Text('Delete Service?',
                                    style: TextStyle(color: Colors.white)),
                                content: const Text('This cannot be undone.',
                                    style: TextStyle(color: Colors.white70)),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Delete',
                                        style: TextStyle(color: Colors.red)),
                                  ),
                                ],
                              ),
                            );
                            if (confirm == true) {
                              await _firestore.deleteService(s.id);
                              _loadServices();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

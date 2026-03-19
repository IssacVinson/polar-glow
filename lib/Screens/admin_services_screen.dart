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
    final categoryCtrl = TextEditingController(text: service?.category);

    bool isSaving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(service == null ? 'Add Service' : 'Edit Service'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name')),
                  TextField(
                      controller: priceCtrl,
                      decoration: const InputDecoration(labelText: 'Price'),
                      keyboardType: TextInputType.number),
                  TextField(
                      controller: descCtrl,
                      decoration:
                          const InputDecoration(labelText: 'Description')),
                  TextField(
                      controller: categoryCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Category (base/add_on/interior)')),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSaving ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          setDialogState(() => isSaving = true);

                          final svc = ServiceModel(
                            id: service?.id ?? '',
                            name: nameCtrl.text.trim(),
                            price: double.tryParse(priceCtrl.text) ?? 0,
                            category: categoryCtrl.text.trim().toLowerCase(),
                            description: descCtrl.text.trim(),
                          );

                          try {
                            if (service == null) {
                              await _firestore.addService(svc);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '✅ Service added successfully!')),
                                );
                              }
                            } else {
                              await _firestore.updateService(service.id, svc);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          '✅ Service updated successfully!')),
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
                      : Text(service == null ? 'Add' : 'Save'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Services'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showServiceDialog(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _services.length,
              itemBuilder: (ctx, i) {
                final s = _services[i];
                return Card(
                  margin:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    title: Text(s.name,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        '${s.category} • \$${s.price.toStringAsFixed(2)}\n${s.description}'),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showServiceDialog(s)),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete Service?'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(c, true),
                                      child: const Text('Delete',
                                          style: TextStyle(color: Colors.red))),
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

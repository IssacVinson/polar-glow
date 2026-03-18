import 'package:flutter/material.dart';
import 'booking_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  // Track selected state by service ID
  final Map<int, bool> _selectedServices = {};

  // Your actual services & pricing
  final List<Map<String, dynamic>> _services = [
    {
      'id': 0,
      'name': 'Sedan Interior Detail',
      'price': 205,
      'description':
          'Full interior shampoo, vacuum, wipe-down, windows cleaned',
      'size': 'Small Car / Sedan',
    },
    {
      'id': 1,
      'name': 'SUV Interior Detail',
      'price': 215,
      'description':
          'Full interior shampoo, vacuum, wipe-down, windows cleaned',
      'size': 'Mid-Size SUV / Crossover',
    },
    {
      'id': 2,
      'name': 'Truck Interior Detail',
      'price': 205,
      'description':
          'Full interior shampoo, vacuum, wipe-down, windows cleaned',
      'size': 'Pickup Truck',
    },
    {
      'id': 3,
      'name': 'Minivan / Large SUV Interior Detail',
      'price': 255,
      'description':
          'Full interior shampoo, vacuum, wipe-down, windows cleaned',
      'size': 'Minivan / Full-Size SUV',
    },
    {
      'id': 4,
      'name': 'Extra TLC Add-On',
      'price': 40,
      'description': 'Extra attention to high-touch areas, odor elimination',
      'isAddOn': true,
    },
    {
      'id': 5,
      'name': 'Extra Shampoo Add-On',
      'price': 20,
      'description': 'Additional shampoo treatment for heavy stains',
      'isAddOn': true,
    },
  ];

  // Get list of selected services to pass to booking
  List<Map<String, dynamic>> get _selected {
    return _services.where((s) => _selectedServices[s['id']] == true).toList();
  }

  @override
  Widget build(BuildContext context) {
    final hasSelection = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Services & Pricing'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Scrollable list of services
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _services.length,
              itemBuilder: (context, index) {
                final service = _services[index];
                final isAddOn = service['isAddOn'] == true;
                final isSelected = _selectedServices[service['id']] ?? false;

                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  color: isAddOn ? Colors.blueGrey[800] : Colors.blueGrey[700],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        _selectedServices[service['id']] = value ?? false;
                      });
                    },
                    title: Text(
                      service['name'],
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '\$${service['price']}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isAddOn ? Colors.cyan[300] : Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service['description'],
                          style: const TextStyle(color: Colors.white70),
                        ),
                        if (service['size'] != null)
                          Text(
                            'Size: ${service['size']}',
                            style: const TextStyle(
                              color: Colors.white60,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                      ],
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
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
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  BookingScreen(selectedServices: _selected),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.calendar_today, size: 20),
                  label: const Text(
                    'Book Selected',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasSelection
                        ? Colors.cyan[700]
                        : Colors.grey[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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

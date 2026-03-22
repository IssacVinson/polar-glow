import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminViewClientsScreen extends StatefulWidget {
  const AdminViewClientsScreen({super.key});

  @override
  State<AdminViewClientsScreen> createState() => _AdminViewClientsScreenState();
}

class _AdminViewClientsScreenState extends State<AdminViewClientsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('View Clients'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search clients (name, email, phone)',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceContainerLowest,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase().trim();
                });
              },
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'customer')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No customers found'));
                }

                final clients = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['displayName'] ??
                          data['fullName'] ??
                          data['name'] ??
                          '')
                      .toString()
                      .toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final phone = (data['phoneNumber'] ?? data['phone'] ?? '')
                      .toString()
                      .toLowerCase();

                  return name.contains(_searchQuery) ||
                      email.contains(_searchQuery) ||
                      phone.contains(_searchQuery);
                }).toList();

                if (clients.isEmpty) {
                  return const Center(child: Text('No matching clients'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: clients.length,
                  itemBuilder: (context, index) {
                    final doc = clients[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final displayName = data['displayName'] ??
                        data['fullName'] ??
                        data['name'] ??
                        'No Name';
                    final email = data['email'] ?? 'No Email';
                    final phone =
                        data['phoneNumber'] ?? data['phone'] ?? 'No Phone';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(displayName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email),
                            if (phone.isNotEmpty && phone != 'No Phone')
                              Text(phone),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.info_outline),
                          onPressed: () => _showClientDetails(context, data),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showClientDetails(BuildContext context, Map<String, dynamic> data) {
    final name =
        data['displayName'] ?? data['fullName'] ?? data['name'] ?? 'N/A';
    final email = data['email'] ?? 'N/A';
    final phone = data['phoneNumber'] ?? data['phone'] ?? 'N/A';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Client Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Text('Name: $name'),
            Text('Email: $email'),
            Text('Phone: $phone'),
            if (data['address'] != null) Text('Address: ${data['address']}'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

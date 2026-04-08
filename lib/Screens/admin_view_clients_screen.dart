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

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'View Clients',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Premium glowing search bar
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shadowColor: _accentColor.withOpacity(0.3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              color: Colors.grey[850],
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Search clients (name, email, phone)',
                  labelStyle: TextStyle(color: Colors.white70),
                  prefixIcon: Icon(Icons.search, color: _accentColor),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[850],
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase().trim();
                  });
                },
              ),
            ),
          ),

          // Clients list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: 'customer')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No customers found',
                          style: TextStyle(color: Colors.white70)));
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
                  return const Center(
                      child: Text('No matching clients',
                          style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                        leading: CircleAvatar(
                          radius: 26,
                          backgroundColor: _accentColor.withOpacity(0.2),
                          child: Icon(Icons.person_outline_rounded,
                              color: _accentColor, size: 32),
                        ),
                        title: Text(
                          displayName,
                          style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(email,
                                style: const TextStyle(color: Colors.white70)),
                            if (phone.isNotEmpty && phone != 'No Phone')
                              Text(phone,
                                  style:
                                      const TextStyle(color: Colors.white70)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: Icon(Icons.info_outline_rounded,
                              color: _accentColor, size: 28),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Client Details',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 20),
            Text('Name: $name', style: const TextStyle(color: Colors.white70)),
            Text('Email: $email',
                style: const TextStyle(color: Colors.white70)),
            Text('Phone: $phone',
                style: const TextStyle(color: Colors.white70)),
            if (data['address'] != null)
              Text('Address: ${data['address']}',
                  style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
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

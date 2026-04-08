import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPromotionScreen extends StatefulWidget {
  const AdminPromotionScreen({super.key});

  @override
  State<AdminPromotionScreen> createState() => _UserPromotionScreenState();
}

class _UserPromotionScreenState extends State<AdminPromotionScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _updateRole(String userId, String newRole) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role updated to $newRole'),
            backgroundColor: Colors.teal,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Promote Accounts',
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
                  labelText: 'Search by email or name',
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
              ),
            ),
          ),

          // Responsive user list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                      child: Text('No users found',
                          style: TextStyle(color: Colors.white70)));
                }

                final filtered = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final email = (data['email'] ?? '').toString().toLowerCase();
                  final name =
                      (data['displayName'] ?? '').toString().toLowerCase();
                  return email.contains(_searchQuery) ||
                      name.contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(
                      child: Text('No matching users',
                          style: TextStyle(color: Colors.white70)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final doc = filtered[index];
                    final id = doc.id;
                    final data = doc.data() as Map<String, dynamic>;

                    final email = data['email'] ?? 'No email';
                    final displayName = data['displayName'] ?? 'No name';
                    final phone = data['phoneNumber'] ?? 'No phone';
                    final role = (data['role'] ?? 'customer').toLowerCase();

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      elevation: 16,
                      shadowColor: _accentColor.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24)),
                      color: Colors.grey[850],
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor:
                                      _accentColor.withOpacity(0.2),
                                  child: Text(
                                    displayName.isNotEmpty
                                        ? displayName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                        fontSize: 22,
                                        color: _accentColor,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayName,
                                        style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(email,
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14)),
                                      Text('Phone: $phone',
                                          style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 14)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Divider(color: Colors.white24),
                            const SizedBox(height: 12),

                            // Current role badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: role == 'admin'
                                    ? Colors.deepPurple.withOpacity(0.2)
                                    : role == 'employee'
                                        ? Colors.teal.withOpacity(0.2)
                                        : Colors.blueGrey.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(30),
                              ),
                              child: Text(
                                'Current: ${role.toUpperCase()}',
                                style: TextStyle(
                                  color: role == 'admin'
                                      ? Colors.deepPurple
                                      : role == 'employee'
                                          ? Colors.teal
                                          : Colors.blueGrey,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            // Premium glowing role buttons (fixed purple visibility)
                            Wrap(
                              spacing: 10,
                              runSpacing: 10,
                              children: [
                                if (role != 'customer')
                                  _buildRoleButton(
                                    'Demote to Customer',
                                    Colors.red,
                                    () => _updateRole(id, 'customer'),
                                  ),
                                if (role != 'employee')
                                  _buildRoleButton(
                                    'Make Employee',
                                    Colors.teal,
                                    () => _updateRole(id, 'employee'),
                                  ),
                                if (role != 'admin')
                                  _buildRoleButton(
                                    'Make Admin',
                                    const Color(
                                        0xFF9C27B0), // brighter, vibrant purple (same as app's profile purple)
                                    () => _updateRole(id, 'admin'),
                                  ),
                              ],
                            ),
                          ],
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

  Widget _buildRoleButton(
    String label,
    Color color,
    VoidCallback onPressed,
  ) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 12,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w600,
            fontSize: 14.5,
            shadows: [
              // Extra text glow for premium visibility (especially on purple)
              Shadow(
                blurRadius: 6,
                color: color.withOpacity(0.9),
                offset: const Offset(0, 0),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// lib/Screens/admin_employee_details_screen.dart
// UPGRADED: Premium dark theme with glowing cards, cyan accents, responsive layout
// Fully consistent with EmployeeDashboard + all upgraded admin screens
// No old mileage references found — nothing to update (new reimbursement screen is already being used elsewhere)

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'admin_hours_pay_screen.dart';
import 'admin_schedule_calendar_screen.dart';

class AdminEmployeeDetailsScreen extends StatefulWidget {
  final String employeeId;
  final String email;
  final String role;
  final Timestamp? createdAt;

  const AdminEmployeeDetailsScreen({
    super.key,
    required this.employeeId,
    required this.email,
    required this.role,
    this.createdAt,
  });

  @override
  State<AdminEmployeeDetailsScreen> createState() =>
      _AdminEmployeeDetailsScreenState();
}

class _AdminEmployeeDetailsScreenState
    extends State<AdminEmployeeDetailsScreen> {
  bool _isLoadingSummary = true;
  String? _summaryError;
  String _hoursThisMonth = '0 h 0 m';
  String _bookingsCompleted = '0';
  List<Map<String, dynamic>> _recentBookings = [];

  // Polar Glow brand accent
  Color get _accentColor => const Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _loadSummaryStats();
  }

  Future<void> _loadSummaryStats() async {
    setState(() {
      _isLoadingSummary = true;
      _summaryError = null;
    });

    try {
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);

      final clockSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('clock_events')
          .where('timestamp',
              isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart))
          .orderBy('timestamp')
          .get();

      Duration totalHours = Duration.zero;
      DateTime? openIn;
      for (var doc in clockSnap.docs) {
        final data = doc.data();
        final time = (data['timestamp'] as Timestamp).toDate();
        final type = data['type'] as String;
        if (type == 'in') {
          openIn = time;
        } else if (type == 'out' && openIn != null) {
          totalHours += time.difference(openIn);
          openIn = null;
        }
      }
      if (openIn != null) totalHours += now.difference(openIn);

      final bookingsSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('assignedEmployeeId', isEqualTo: widget.employeeId)
          .get();

      final recentSnap = await FirebaseFirestore.instance
          .collection('bookings')
          .where('assignedEmployeeId', isEqualTo: widget.employeeId)
          .limit(3)
          .get();

      if (mounted) {
        setState(() {
          _hoursThisMonth =
              '${totalHours.inHours} h ${totalHours.inMinutes % 60} m';
          _bookingsCompleted = bookingsSnap.docs.length.toString();
          _recentBookings = recentSnap.docs.map((doc) => doc.data()).toList();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _summaryError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingSummary = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    final joinDate = widget.createdAt != null
        ? DateFormat('MMM d, yyyy').format(widget.createdAt!.toDate())
        : 'Unknown join date';

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text(
          widget.email.split('@').first,
          style:
              const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            // Premium glowing header
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
              color: Colors.grey[850],
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: _accentColor.withOpacity(0.2),
                    child: Text(
                      widget.email[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 48,
                        color: _accentColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    widget.email,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Role: ${widget.role.toUpperCase()} • Joined: $joinDate',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                ],
              ),
            ),

            // Premium dark TabBar
            TabBar(
              labelColor: _accentColor,
              unselectedLabelColor: Colors.white70,
              indicatorColor: _accentColor,
              indicatorWeight: 3,
              tabs: const [
                Tab(text: 'Summary'),
                Tab(text: 'Hours & Pay'),
                Tab(text: 'Schedule'),
                Tab(text: 'Products'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  // Summary Tab
                  Padding(
                    padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                    child: _isLoadingSummary
                        ? const Center(child: CircularProgressIndicator())
                        : _summaryError != null
                            ? Center(
                                child: Card(
                                  elevation: 8,
                                  shadowColor: Colors.red.withOpacity(0.4),
                                  color: Colors.grey[850],
                                  child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text(
                                      'Failed to load summary:\n\nTry creating the Firestore index or check permissions',
                                      style: TextStyle(
                                          color: Colors.white70, fontSize: 15),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Quick Stats',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGlowStatCard('Total Hours This Month',
                                        _hoursThisMonth),
                                    _buildGlowStatCard('Bookings Completed',
                                        _bookingsCompleted),
                                    _buildGlowStatCard(
                                        'Average Rating', 'No data yet'),
                                    const SizedBox(height: 32),
                                    Text(
                                      'Recent Activity',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                    const SizedBox(height: 12),
                                    _buildRecentActivity(),
                                  ],
                                ),
                              ),
                  ),

                  // Hours & Pay Tab
                  AdminHoursPayScreen(employeeId: widget.employeeId),

                  // Schedule Tab
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: AdminScheduleCalendarScreen(
                        employeeId: widget.employeeId, showAppBar: false),
                  ),

                  // Products Tab
                  _ProductsTab(employeeId: widget.employeeId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowStatCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 16,
      shadowColor: _accentColor.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.grey[850],
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        title: Text(
          label,
          style: const TextStyle(
            fontSize: 15.5,
            color: Colors.white70,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _accentColor,
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentBookings.isEmpty) {
      return Card(
        elevation: 12,
        shadowColor: _accentColor.withOpacity(0.3),
        color: Colors.grey[850],
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No recent activity yet',
            style: TextStyle(color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return Column(
      children: _recentBookings.map((booking) {
        final date = (booking['date'] as Timestamp).toDate();
        final price = (booking['totalPrice'] as num? ?? 0).toDouble();
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 16,
          shadowColor: _accentColor.withOpacity(0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          color: Colors.grey[850],
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            title: Text(
              'Booking on ${DateFormat('MMM d').format(date)}',
              style: const TextStyle(color: Colors.white),
            ),
            subtitle: Text(
              'Total: \$${price.toStringAsFixed(2)}',
              style: TextStyle(color: Colors.white70),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ==================== PRODUCTS TAB (Premium upgraded) ====================
class _ProductsTab extends StatefulWidget {
  final String employeeId;
  const _ProductsTab({required this.employeeId});

  @override
  State<_ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<_ProductsTab> {
  final List<Map<String, dynamic>> _products = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final snap = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
        .collection('assigned_products')
        .get();
    setState(() => _products
      ..clear()
      ..addAll(snap.docs.map((doc) => {...doc.data(), 'id': doc.id})));
  }

  Future<void> _addProduct() async {
    final nameCtrl = TextEditingController();
    final costCtrl = TextEditingController();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Assign New Product',
            style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  labelStyle: TextStyle(color: Colors.white70),
                )),
            TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Replacement Cost (\$)',
                  labelStyle: TextStyle(color: Colors.white70),
                )),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, {
              'name': nameCtrl.text.trim(),
              'cost': double.tryParse(costCtrl.text) ?? 0.0,
              'usageCount': 0,
              'lastReplaced': Timestamp.now(),
            }),
            child:
                const Text('Add', style: TextStyle(color: Color(0xFF00E5FF))),
          ),
        ],
      ),
    );

    if (result != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('assigned_products')
          .add(result);
      _loadProducts();
    }
  }

  Future<void> _incrementUsage(String productId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
        .collection('assigned_products')
        .doc(productId)
        .update({
      'usageCount': FieldValue.increment(1),
      'lastReplaced': Timestamp.now()
    });
    _loadProducts();
  }

  Future<void> _decrementUsage(String productId) async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.employeeId)
        .collection('assigned_products')
        .doc(productId)
        .get();
    final current = (doc.data()?['usageCount'] ?? 0) as int;
    if (current > 0) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('assigned_products')
          .doc(productId)
          .update({'usageCount': FieldValue.increment(-1)});
      _loadProducts();
    }
  }

  Future<void> _deleteProduct(String productId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: const Text('Delete Product?',
            style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.employeeId)
          .collection('assigned_products')
          .doc(productId)
          .delete();
      _loadProducts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    return Padding(
      padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Assigned Products',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
              ),
              IconButton(
                icon: Icon(Icons.add, color: const Color(0xFF00E5FF), size: 28),
                onPressed: _addProduct,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _products.isEmpty
                ? const Center(
                    child: Text(
                      'No products assigned yet',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    itemCount: _products.length,
                    itemBuilder: (context, i) {
                      final p = _products[i];
                      final cost = ((p['cost'] ?? 0) as num).toDouble();
                      final usage = p['usageCount'] as int? ?? 0;
                      final totalYTD = (usage * cost).toDouble();
                      final monthlyAvg = usage > 0
                          ? (totalYTD / 12).toStringAsFixed(2)
                          : '0.00';

                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 16,
                        shadowColor: const Color(0xFF00E5FF).withOpacity(0.4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24)),
                        color: Colors.grey[850],
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          title: Text(
                            p['name'] ?? 'Unnamed Product',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Used $usage times\nMonthly Avg: \$$monthlyAvg • YTD Total: \$${totalYTD.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.white70),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.remove_circle_outline,
                                      color: Colors.white70),
                                  onPressed: () => _decrementUsage(p['id'])),
                              IconButton(
                                  icon: const Icon(Icons.add_circle,
                                      color: Color(0xFF00E5FF)),
                                  onPressed: () => _incrementUsage(p['id'])),
                              IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () => _deleteProduct(p['id'])),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

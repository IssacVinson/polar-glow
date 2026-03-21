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
    final colorScheme = Theme.of(context).colorScheme;
    final joinDate = widget.createdAt != null
        ? DateFormat('MMM d, yyyy').format(widget.createdAt!.toDate())
        : 'Unknown join date';

    return Scaffold(
      appBar:
          AppBar(title: Text(widget.email.split('@').first), centerTitle: true),
      body: DefaultTabController(
        length: 4,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              color: colorScheme.surfaceContainerHighest,
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: colorScheme.primary,
                    child: Text(widget.email[0].toUpperCase(),
                        style:
                            const TextStyle(fontSize: 40, color: Colors.white)),
                  ),
                  const SizedBox(height: 16),
                  Text(widget.email,
                      style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Text('Role: ${widget.role} • Joined: $joinDate',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            const TabBar(tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'Hours & Pay'),
              Tab(text: 'Schedule'),
              Tab(text: 'Products')
            ]),
            Expanded(
              child: TabBarView(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _isLoadingSummary
                        ? const Center(child: CircularProgressIndicator())
                        : _summaryError != null
                            ? Center(
                                child: Card(
                                  color: Colors.red.shade900,
                                  child: const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                        'Failed to load summary:\n\nTry creating the Firestore index or check permissions',
                                        style: TextStyle(color: Colors.white),
                                        textAlign: TextAlign.center),
                                  ),
                                ),
                              )
                            : SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Quick Stats',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 16),
                                    _buildStatCard('Total Hours This Month',
                                        _hoursThisMonth),
                                    _buildStatCard('Bookings Completed',
                                        _bookingsCompleted),
                                    _buildStatCard('Average Rating', 'No data'),
                                    const SizedBox(height: 24),
                                    const Text('Recent Activity',
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    _buildRecentActivity(),
                                  ],
                                ),
                              ),
                  ),
                  AdminHoursPayScreen(employeeId: widget.employeeId),
                  Padding(
                    padding: const EdgeInsets.all(8),
                    child: AdminScheduleCalendarScreen(
                        employeeId: widget.employeeId, showAppBar: false),
                  ),
                  _ProductsTab(employeeId: widget.employeeId),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
          title: Text(label),
          trailing:
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildRecentActivity() {
    if (_recentBookings.isEmpty) {
      return const Card(
          child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No recent activity yet')));
    }
    return Column(
      children: _recentBookings.map((booking) {
        final date = (booking['date'] as Timestamp).toDate();
        final price = (booking['totalPrice'] as num? ?? 0).toDouble();
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
              title: Text('Booking on ${DateFormat('MMM d').format(date)}'),
              subtitle: Text('Total: \$${price.toStringAsFixed(2)}')),
        );
      }).toList(),
    );
  }
}

// ==================== PRODUCTS TAB (FIXED - NO TYPE ERRORS) ====================
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
        title: const Text('Assign New Product'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Product Name')),
            TextField(
                controller: costCtrl,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Replacement Cost (\$)')),
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
            child: const Text('Add'),
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
        title: const Text('Delete Product?'),
        content: const Text('This cannot be undone.'),
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
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Assigned Products',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.add), onPressed: _addProduct),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _products.isEmpty
                ? const Center(child: Text('No products assigned yet'))
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
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          title: Text(p['name'] ?? 'Unnamed Product'),
                          subtitle: Text(
                              'Used $usage times\nMonthly Avg: \$$monthlyAvg • YTD Total: \$${totalYTD.toStringAsFixed(2)}'),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () => _decrementUsage(p['id'])),
                              IconButton(
                                  icon: const Icon(Icons.add_circle),
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

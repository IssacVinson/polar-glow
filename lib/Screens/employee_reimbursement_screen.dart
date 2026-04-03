// lib/screens/employee_reimbursement_screen.dart
// FIXED: Renamed from EmployeeMileageScreen → EmployeeReimbursementScreen
// FULL PREMIUM UPGRADE: Polar Glow dark theme + luxurious layout
// - Submit general reimbursement (title, amount, description, receipt photo)
// - Live preview of uploaded receipt
// - View all previous reimbursements with status badges

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../Providers/auth_provider.dart' as app_auth;

class EmployeeReimbursementScreen extends StatefulWidget {
  const EmployeeReimbursementScreen({super.key});

  @override
  State<EmployeeReimbursementScreen> createState() =>
      _EmployeeReimbursementScreenState();
}

class _EmployeeReimbursementScreenState
    extends State<EmployeeReimbursementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _receiptImage;
  String? _uploadedImageUrl;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (image != null) {
      setState(() => _receiptImage = image);
    }
  }

  Future<String?> _uploadReceipt(String claimId) async {
    if (_receiptImage == null) return null;

    try {
      final ref = FirebaseStorage.instance.ref().child(
          'reimbursements/$claimId/${DateTime.now().millisecondsSinceEpoch}.jpg');

      final uploadTask = await ref.putFile(File(_receiptImage!.path));
      return await uploadTask.ref.getDownloadURL();
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _submitReimbursement() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final uid = context.read<app_auth.AuthProvider>().user!.uid;
    final claimRef = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('reimbursements')
        .doc();

    try {
      // First upload image if selected
      _uploadedImageUrl = await _uploadReceipt(claimRef.id);

      await claimRef.set({
        'title': _titleController.text.trim(),
        'amount': amount,
        'description': _descriptionController.text.trim(),
        'receiptUrl': _uploadedImageUrl,
        'status': 'submitted',
        'submittedAt': FieldValue.serverTimestamp(),
        'employeeId': uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reimbursement submitted for approval!'),
            backgroundColor: Colors.green,
          ),
        );

        // Clear form
        _titleController.clear();
        _amountController.clear();
        _descriptionController.clear();
        setState(() {
          _receiptImage = null;
          _uploadedImageUrl = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Reimbursement',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Previous Reimbursements
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            child: Text(
              'Previous Requests',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
            ),
          ),
          Expanded(
            child: uid == null
                ? const Center(child: Text('Please sign in'))
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('reimbursements')
                        .orderBy('submittedAt', descending: true)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(
                            child: Text('Error: ${snapshot.error}',
                                style: const TextStyle(color: Colors.white70)));
                      }
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator(
                                color: Color(0xFF00E5FF)));
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(40),
                            child: Text(
                              'No reimbursement requests yet.\nSubmit one below!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 17),
                            ),
                          ),
                        );
                      }

                      final claims = snapshot.data!.docs;

                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: claims.length,
                        itemBuilder: (context, index) {
                          final data =
                              claims[index].data() as Map<String, dynamic>;
                          final status = data['status'] ?? 'submitted';
                          final submittedAt =
                              (data['submittedAt'] as Timestamp?)?.toDate();

                          Color statusColor;
                          String statusText;

                          switch (status) {
                            case 'accepted':
                              statusColor = Colors.green;
                              statusText = 'Accepted';
                              break;
                            case 'denied':
                              statusColor = Colors.red;
                              statusText = 'Denied';
                              break;
                            case 'paid':
                              statusColor = Colors.blue;
                              statusText = 'Paid';
                              break;
                            case 'unpaid':
                              statusColor = Colors.orange;
                              statusText = 'Approved (Unpaid)';
                              break;
                            default:
                              statusColor = Colors.orange;
                              statusText = 'Submitted';
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            color: Colors.grey[850],
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                data['title'] ?? 'Reimbursement',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '\$${data['amount']?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                        fontSize: 18, color: Color(0xFF00E5FF)),
                                  ),
                                  if (submittedAt != null)
                                    Text(
                                      DateFormat('MMM d, yyyy')
                                          .format(submittedAt),
                                      style: const TextStyle(
                                          color: Colors.white54),
                                    ),
                                ],
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  statusText,
                                  style: TextStyle(
                                      color: statusColor,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),

          // Submit New Reimbursement Form
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey[850],
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Submit New Reimbursement',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 20),

                  // Title
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.black12,
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Amount
                  TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Amount (\$)',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.black12,
                      prefixText: '\$ ',
                    ),
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.black12,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Receipt Photo
                  Text(
                    'Receipt Photo',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickReceipt,
                    child: Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: _receiptImage != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(
                                File(_receiptImage!.path),
                                fit: BoxFit.cover,
                              ),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 48, color: Colors.white54),
                                SizedBox(height: 8),
                                Text('Tap to upload receipt photo',
                                    style: TextStyle(color: Colors.white54)),
                              ],
                            ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submitReimbursement,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF00E5FF),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.black)
                          : const Text(
                              'Submit for Approval',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

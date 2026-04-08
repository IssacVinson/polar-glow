import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/models/reimbursement_model.dart';
import '../../core/services/firestore_service.dart';
import '../../Providers/auth_provider.dart' as app_auth;

class EmployeeReimbursementScreen extends StatefulWidget {
  const EmployeeReimbursementScreen({super.key});

  @override
  State<EmployeeReimbursementScreen> createState() =>
      _EmployeeReimbursementScreenState();
}

class _EmployeeReimbursementScreenState
    extends State<EmployeeReimbursementScreen> {
  final FirestoreService _firestore = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final uid = context.read<app_auth.AuthProvider>().user?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: const Text(
          'Reimbursements',
          style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        elevation: 4,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSubmitBottomSheet(context),
        backgroundColor: const Color(0xFF00E5FF),
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in'))
          : StreamBuilder<List<ReimbursementModel>>(
              stream:
                  Stream.fromFuture(_firestore.getEmployeeReimbursements(uid)),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: const TextStyle(color: Colors.white70)));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child:
                          CircularProgressIndicator(color: Color(0xFF00E5FF)));
                }

                final claims = snapshot.data ?? [];

                if (claims.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: Text(
                        'No reimbursement requests yet.\nTap the + button to submit one!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontSize: 17),
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: claims.length,
                  itemBuilder: (context, index) {
                    final claim = claims[index];

                    Color statusColor;
                    String statusText;

                    switch (claim.status) {
                      case 'approved':
                        statusColor = Colors.green;
                        statusText = 'Approved';
                        break;
                      case 'denied':
                        statusColor = Colors.red;
                        statusText = 'Denied';
                        break;
                      case 'paid':
                        statusColor = Colors.blue;
                        statusText = 'Paid';
                        break;
                      default:
                        statusColor = Colors.orange;
                        statusText = 'Pending';
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      color: Colors.grey[850],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Text(
                          claim.title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '\$${claim.amount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                  fontSize: 18, color: Color(0xFF00E5FF)),
                            ),
                            Text(
                              DateFormat('MMM d, yyyy')
                                  .format(claim.dateSubmitted),
                              style: const TextStyle(color: Colors.white54),
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.2),
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
    );
  }

  void _showSubmitBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 24,
          right: 24,
          top: 24,
        ),
        child: _SubmitReimbursementForm(onSubmitted: () {
          Navigator.pop(ctx);
        }),
      ),
    );
  }
}

// Submit form (now scrollable to prevent overflow)
class _SubmitReimbursementForm extends StatefulWidget {
  final VoidCallback onSubmitted;

  const _SubmitReimbursementForm({required this.onSubmitted});

  @override
  State<_SubmitReimbursementForm> createState() =>
      _SubmitReimbursementFormState();
}

class _SubmitReimbursementFormState extends State<_SubmitReimbursementForm> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  XFile? _receiptImage;
  bool _isSubmitting = false;

  final ImagePicker _picker = ImagePicker();
  final FirestoreService _firestore = FirestoreService();

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
    if (image != null) setState(() => _receiptImage = image);
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter a valid amount')));
      return;
    }

    setState(() => _isSubmitting = true);

    final uid = context.read<app_auth.AuthProvider>().user!.uid;

    try {
      final reimbursement = ReimbursementModel(
        id: '',
        employeeId: uid,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        amount: amount,
        dateSubmitted: DateTime.now(),
        status: 'pending',
      );

      final claimId = await _firestore.submitReimbursement(reimbursement);

      if (_receiptImage != null && claimId.isNotEmpty) {
        final receiptUrl = await _uploadReceipt(claimId);
        if (receiptUrl != null) {
          await FirebaseFirestore.instance
              .collection('reimbursements')
              .doc(claimId)
              .update({'receiptUrl': receiptUrl});
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reimbursement submitted for approval!'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSubmitted();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Submit New Reimbursement',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                  labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                  labelText: 'Amount (\$)',
                  border: OutlineInputBorder(),
                  prefixText: '\$ '),
              validator: (v) => v!.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                  labelText: 'Description', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            const Text('Receipt Photo (optional)',
                style: TextStyle(color: Colors.white)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _pickReceipt,
              child: Container(
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24),
                ),
                child: _receiptImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(File(_receiptImage!.path),
                            fit: BoxFit.cover),
                      )
                    : const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.camera_alt,
                                size: 48, color: Colors.white54),
                            SizedBox(height: 8),
                            Text('Tap to upload receipt',
                                style: TextStyle(color: Colors.white54)),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _isSubmitting ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  foregroundColor: Colors.black,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Submit for Approval',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

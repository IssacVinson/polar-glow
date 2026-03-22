import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Formats phone as (907) 518-4614 while typing
class PhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length > 10) return oldValue;

    String formatted = digitsOnly;
    if (digitsOnly.length > 3) {
      formatted = '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3)}';
    }
    if (digitsOnly.length > 6) {
      formatted =
          '(${digitsOnly.substring(0, 3)}) ${digitsOnly.substring(3, 6)}-${digitsOnly.substring(6)}';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Password change fields
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;
  String? _usernameError;
  String? _originalUsername;

  // Proper email validation
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();

    if (doc.exists) {
      final data = doc.data()!;
      setState(() {
        _usernameController.text = data['username'] ?? '';
        _originalUsername = data['username'];
        _nameController.text = data['displayName'] ?? '';
        _phoneController.text = data['phoneNumber'] ?? '';
      });
    }
  }

  Future<bool> _isUsernameAvailable(String username) async {
    if (username.toLowerCase() == _originalUsername?.toLowerCase()) return true;
    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    return !doc.exists;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameController.text.trim().toLowerCase();
    final isAvailable = await _isUsernameAvailable(newUsername);

    if (!isAvailable) {
      setState(() => _usernameError = 'Username already taken');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _usernameError = null;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': newUsername,
        'displayName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
      });

      // Update usernames collection if username changed
      if (newUsername != _originalUsername?.toLowerCase() &&
          _originalUsername != null) {
        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(_originalUsername!.toLowerCase())
            .delete();

        await FirebaseFirestore.instance
            .collection('usernames')
            .doc(newUsername)
            .set({
          'uid': uid,
          'email': FirebaseAuth.instance.currentUser!.email,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Profile updated successfully!')),
        );
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updatePassword() async {
    final currentPass = _currentPasswordController.text.trim();
    final newPass = _newPasswordController.text.trim();
    final confirmPass = _confirmPasswordController.text.trim();

    if (currentPass.isEmpty || newPass.isEmpty || confirmPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all password fields')),
      );
      return;
    }

    if (newPass.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('New password must be at least 6 characters')),
      );
      return;
    }

    if (newPass != confirmPass) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('New passwords do not match')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Re-authenticate user (required by Firebase for security)
      final credential = EmailAuthProvider.credential(
        email: FirebaseAuth.instance.currentUser!.email!,
        password: currentPass,
      );

      await FirebaseAuth.instance.currentUser!
          .reauthenticateWithCredential(credential);

      await FirebaseAuth.instance.currentUser!.updatePassword(newPass);

      // Clear fields
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Password updated successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update password: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),

              // Username
              TextFormField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Username',
                  errorText: _usernameError,
                  helperText:
                      '4-20 characters, letters/numbers/underscores only',
                ),
                validator: (value) {
                  if (value == null || value.length < 4 || value.length > 20) {
                    return '4-20 characters required';
                  }
                  if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(value)) {
                    return 'Only letters, numbers, underscores allowed';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Full Name
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Phone Number
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneFormatter()],
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Email (read-only)
              TextFormField(
                initialValue: FirebaseAuth.instance.currentUser?.email,
                decoration:
                    const InputDecoration(labelText: 'Email (cannot change)'),
                enabled: false,
              ),
              const SizedBox(height: 32),

              // ==================== CHANGE PASSWORD SECTION ====================
              const Text(
                'Change Password',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _currentPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Current Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _newPasswordController,
                decoration: const InputDecoration(labelText: 'New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _confirmPasswordController,
                decoration:
                    const InputDecoration(labelText: 'Confirm New Password'),
                obscureText: true,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updatePassword,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Password'),
                ),
              ),
              // =================================================================

              const SizedBox(height: 32),

              if (_errorMessage != null)
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),

              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Save Profile Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

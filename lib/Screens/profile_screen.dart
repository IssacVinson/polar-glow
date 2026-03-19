import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

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

  bool _isLoading = false;
  String? _errorMessage;
  String? _usernameError;
  Uint8List? _imageBytes;
  String? _currentPhotoURL;
  String? _originalUsername;

  final ImagePicker _picker = ImagePicker();

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
        _currentPhotoURL = data['photoURL'];
      });
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _imageBytes = bytes);
  }

  Future<String?> _uploadNewPhoto(String uid) async {
    if (_imageBytes == null) return _currentPhotoURL;

    final ref =
        FirebaseStorage.instance.ref().child('profile_pictures/$uid.jpg');
    await ref.putData(_imageBytes!);
    return await ref.getDownloadURL();
  }

  Future<bool> _isUsernameAvailable(String username) async {
    if (username.toLowerCase() == _originalUsername?.toLowerCase()) return true;
    final doc = await FirebaseFirestore.instance
        .collection('usernames')
        .doc(username.toLowerCase())
        .get();
    return !doc.exists;
  }

  // Clean getter to fix the type error
  ImageProvider<Object>? get backgroundImage {
    if (_imageBytes != null) return MemoryImage(_imageBytes!);
    if (_currentPhotoURL != null) return NetworkImage(_currentPhotoURL!);
    return null;
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
      final newPhotoURL = await _uploadNewPhoto(uid);

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'username': newUsername,
        'displayName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'photoURL': newPhotoURL,
      });

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
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
            children: [
              // Profile picture
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 70,
                  backgroundImage: backgroundImage,
                  child: (backgroundImage == null)
                      ? const Icon(Icons.add_a_photo, size: 50)
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              const Text('Tap to change profile picture'),

              const SizedBox(height: 32),

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

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                inputFormatters: [PhoneFormatter()],
                validator: (v) => v!.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                initialValue: FirebaseAuth.instance.currentUser?.email,
                decoration:
                    const InputDecoration(labelText: 'Email (cannot change)'),
                enabled: false,
              ),
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
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

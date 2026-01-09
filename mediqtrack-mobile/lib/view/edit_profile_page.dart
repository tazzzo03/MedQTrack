import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});
  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  static const _apiBase = 'http://172.20.10.4:8000'; // Tukar ke IP PC kau
  static const _storageBucket = 'gs://mediqtrack-d6aa7.firebasestorage.app';

  String? _avatarUrl;
  final _nameCtrl = TextEditingController();
  final _icCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _genderCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController(); // read-only (ambil dari Firebase Auth)
  bool _loading = false;
  bool _uploadingAvatar = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _emailCtrl.text = FirebaseAuth.instance.currentUser!.email ?? '';
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_apiBase/api/patient/profile/$uid');
      final res = await http.get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final js = jsonDecode(res.body);
        if (js['success'] == true && js['data'] != null) {
          final d = js['data'];
          _nameCtrl.text = (d['name'] ?? '').toString();
          _icCtrl.text = (d['ic_number'] ?? d['ic'] ?? '').toString();
          _dobCtrl.text = (d['dob'] ?? '').toString();
          _genderCtrl.text = (d['gender'] ?? '').toString();
          _phoneCtrl.text = (d['phone'] ??
                  d['phone_number'] ??
                  d['phone_no'] ??
                  d['no_phone'] ??
                  d['phoneNumber'] ??
                  '')
              .toString();
          _avatarUrl = await _fetchAvatarUrl(uid);
          setState(() {});
        }
      } else {
        debugPrint('PROFILE LOAD FAIL ${res.statusCode}: ${res.body}');
      }
    } catch (e) {
      debugPrint('PROFILE LOAD EX: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _fetchAvatarUrl(String uid) async {
    try {
      return await FirebaseStorage.instanceFor(bucket: _storageBucket)
          .ref('avatars/$uid')
          .getDownloadURL();
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickAvatar(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 85,
      maxWidth: 1024,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final ref =
          FirebaseStorage.instanceFor(bucket: _storageBucket).ref('avatars/$uid');
      final file = File(picked.path);
      await ref.putFile(
        file,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      _avatarUrl = await ref.getDownloadURL();
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _uploadingAvatar = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseStorage.instanceFor(bucket: _storageBucket)
          .ref('avatars/$uid')
          .delete();
      if (mounted) {
        setState(() => _avatarUrl = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Remove failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    setState(() => _loading = true);
    try {
      final uri = Uri.parse('$_apiBase/api/profile');
      final res = await http.put(
        uri,
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'firebase_uid': uid,
          'name': _nameCtrl.text.trim(),
          'phone_number': _phoneCtrl.text.trim(),
          //'avatar_url': _avatarUrl, // nanti bila siap upload
          // 'email': _emailCtrl.text.trim(), // only if you store email in patients
        }),
      ).timeout(const Duration(seconds: 12));

      final js = jsonDecode(res.body);
      if (res.statusCode == 200 && js['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile updated')),
          );
          Navigator.pop(context);
        }
      } else {
        final msg = (js is Map && js['message'] != null)
            ? js['message'].toString()
            : 'Failed to update (code ${res.statusCode})';
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Network error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openAvatarSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickAvatar(ImageSource.camera);
              },
            ),
            if (_avatarUrl != null)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Remove Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _onSave() => _saveProfile();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _icCtrl.dispose();
    _dobCtrl.dispose();
    _genderCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          TextButton(
            onPressed: _loading ? null : _onSave,
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 52,
                              backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                              backgroundImage: _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                              child: _avatarUrl == null
                                  ? Icon(Icons.person, size: 52, color: Theme.of(context).colorScheme.primary)
                                  : null,
                            ),
                            if (_uploadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      height: 24,
                                      width: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                                ),
                              ),
                            InkWell(
                              onTap: _uploadingAvatar ? null : _openAvatarSheet,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.surface,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Theme.of(context).dividerColor),
                                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6, offset: const Offset(0, 2))],
                                ),
                                child: const Icon(Icons.edit_outlined, size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text('Update your profile details', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    child: Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Theme.of(context).dividerColor),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _nameCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Full Name (read-only)',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _icCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'IC Number (read-only)',
                                  prefixIcon: Icon(Icons.credit_card_outlined),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _dobCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Date of Birth (read-only)',
                                  prefixIcon: Icon(Icons.calendar_today_outlined),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _genderCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Gender (read-only)',
                                  prefixIcon: Icon(Icons.wc_outlined),
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number',
                                  prefixIcon: Icon(Icons.phone_outlined),
                                  hintText: '+60',
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                                  if (v.replaceAll(' ', '').length < 9) return 'Phone number looks invalid';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),
                              TextFormField(
                                controller: _emailCtrl,
                                readOnly: true,
                                decoration: const InputDecoration(
                                  labelText: 'Email (read-only)',
                                  prefixIcon: Icon(Icons.email_outlined),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: _loading ? null : () => Navigator.pop(context), child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: FilledButton(onPressed: _loading ? null : _onSave, child: const Text('Save Changes'))),
            ],
          ),
        ),
      ),
    );
  }
}

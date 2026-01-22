// lib/view/profile_page.dart
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:mediqtrack03/view/edit_profile_page.dart';
import 'package:mediqtrack03/view/visit_history_page.dart';
import 'package:mediqtrack03/view/auth/auth_gate.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _loading = true;
  String? _name;
  String? _email;
  String? _phone;
  String? _avatarUrl;
  static const _storageBucket = 'gs://mediqtrack-d6aa7.firebasestorage.app';

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadAvatarUrl();
  }

  Future<void> _fetchProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final res = await http.get(
        Uri.parse('http://10.82.150.157:8000/api/patient/profile/$uid'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          setState(() {
            _name = data['data']['name'];
            _email = data['data']['email'];
            _phone = data['data']['phone'];
            _loading = false;
          });
        }
      }
      _loadAvatarUrl();
    } catch (e) {
      print('❌ Error fetching profile: $e');
    }
  }

  Future<void> _loadAvatarUrl() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final url = await FirebaseStorage.instanceFor(bucket: _storageBucket)
          .ref('avatars/$uid')
          .getDownloadURL();
      if (mounted) {
        setState(() => _avatarUrl = url);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _avatarUrl = null);
      }
    }
  }

  Future<void> _openEditProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const EditProfilePage(),
      ),
    );
    if (mounted) {
      setState(() => _loading = true);
      await _fetchProfile();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
        toolbarHeight: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchProfile,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // Header
            SizedBox(
              height: 260,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(
                    painter: _HeaderWavePainter(
                        Theme.of(context).colorScheme.primary),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: Colors.white,
                          backgroundImage:
                              _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                          child: _avatarUrl == null
                              ? const Icon(Icons.person,
                                  size: 46, color: Colors.black54)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _name ?? 'Unknown',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _email ?? '-',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: Colors.white),
                        ),
                        if (_phone != null && _phone!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _phone!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Quick actions
            Padding(
              padding: const EdgeInsets.all(16),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(
                      color: Theme.of(context).dividerColor, width: 1),
                ),
                elevation: 0,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline),
                      title: const Text('My Profile'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16),
                      onTap: _openEditProfile,
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: const Text('Visit History'),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const VisitHistoryPage()),
                        );
                      },
                    ),
                    const Divider(height: 0),
                    ListTile(
                      leading: const Icon(Icons.logout_outlined),
                      title: const Text('Logout'),
                      onTap: () => _confirmLogout(context),
                    ),
                    const Divider(height: 0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== Logout & Remove Account =====

void _confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text('You will be signed out of MediQTrack.'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            Navigator.pop(context);
            try {
              await FirebaseAuth.instance.signOut();

              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false, // clear semua page sebelum ni
                );
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Gagal logout: ${e.toString()}')),
                );
              }
            }
          },
          child: const Text('Logout'),
        ),
      ],
    ),
  );
}

void _confirmRemove(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Remove Account?'),
      content: const Text(
        'This action is permanent and will remove your account from MediQTrack completely.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.tonal(
          onPressed: () async {
            Navigator.pop(context);
            await _removeAccountFlow(context);
          },
          child: const Text('Remove Account'),
        ),
      ],
    ),
  );
}

Future<void> _removeAccountFlow(BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final messenger = ScaffoldMessenger.of(context);
  final uid = user.uid;

  try {
    // 1️⃣ Delete from MySQL via Laravel API
    final res = await http.delete(
      Uri.parse('http://10.82.150.157:8000/api/patient/delete/$uid'),
      headers: {'Accept': 'application/json'},
    );

    final data = jsonDecode(res.body);
    if (data['success'] == true) {
      debugPrint('✅ MySQL account deleted');
    } else {
      debugPrint('⚠️ MySQL delete failed: ${data['message'] ?? 'unknown error'}');
    }

    // 2️⃣ Delete from Firestore (if exists)
    final docRef =
        FirebaseFirestore.instance.collection('users').doc(uid);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.delete();
      debugPrint('✅ Firestore document deleted');
    }

    // 3️⃣ Delete from Firebase Authentication
    await user.delete();
    debugPrint('✅ Firebase Auth account deleted');

    if (context.mounted) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Account removed successfully.')));

      // 4️⃣ Redirect back to login
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthGate()),
        (route) => false,
      );
    }
  } on FirebaseAuthException catch (e) {
    if (e.code == 'requires-recent-login') {
      messenger.showSnackBar(const SnackBar(
          content: Text('Please reauthenticate before deleting.')));
    } else {
      messenger.showSnackBar(SnackBar(
          content: Text('Auth error: ${e.message ?? e.code}')));
    }
  } catch (e) {
    messenger.showSnackBar(SnackBar(
        content: Text('Error removing account: ${e.toString()}')));
  }
}

class _HeaderWavePainter extends CustomPainter {
  _HeaderWavePainter(this.baseColor);

  final Color baseColor;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = baseColor;
    canvas.drawRect(Offset.zero & size, bg);

    final wavePaint1 = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.fill;
    final wavePaint2 = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path1 = Path()
      ..moveTo(0, size.height * 0.55)
      ..cubicTo(size.width * 0.2, size.height * 0.48, size.width * 0.4,
          size.height * 0.6, size.width * 0.6, size.height * 0.5)
      ..cubicTo(size.width * 0.8, size.height * 0.4, size.width * 0.95,
          size.height * 0.55, size.width, size.height * 0.5)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path1, wavePaint1);

    final path2 = Path()
      ..moveTo(0, size.height * 0.75)
      ..cubicTo(size.width * 0.25, size.height * 0.65, size.width * 0.5,
          size.height * 0.82, size.width * 0.75, size.height * 0.7)
      ..cubicTo(size.width * 0.88, size.height * 0.62, size.width * 0.97,
          size.height * 0.7, size.width, size.height * 0.68)
      ..lineTo(size.width, 0)
      ..lineTo(0, 0)
      ..close();
    canvas.drawPath(path2, wavePaint2);
  }

  @override
  bool shouldRepaint(covariant _HeaderWavePainter oldDelegate) {
    return oldDelegate.baseColor != baseColor;
  }
}



// lib/view/home_page.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:mediqtrack03/services/geofence_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mediqtrack03/state/outside_status.dart';
import 'package:mediqtrack03/view/my_queue_page.dart';
import 'package:mediqtrack03/view/visit_history_page.dart';
import 'package:mediqtrack03/services/consultation_service.dart';

class HomePage extends StatefulWidget {
  final ValueChanged<int>? onTabSelect;
  const HomePage({super.key, this.onTabSelect});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? name;
  String? email;
  String? phone;
  String? _avatarUrl;
  bool loadingProfile = true;
  double? _avgMinutesCombined;
  static const _storageBucket = 'gs://mediqtrack-d6aa7.firebasestorage.app';
  Future<Map<String, String?>>? _roomDoctorFuture;
  String? _roomDoctorUid;

  Future<void> fetchProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://10.82.145.75:8000/api/patient/profile/$uid'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final avatarUrl = await _fetchAvatarUrl(uid);
          if (!mounted) return;
          setState(() {
            name = data['data']['name'];
            email = data['data']['email'];
            phone = data['data']['phone'];
            _avatarUrl = avatarUrl;
            loadingProfile = false;
          });
        }
      }
    } catch (e) {
      print('❌ Error fetching profile: $e');
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

  bool _loading = false;

Future<void> _joinQueue() async {
  setState(() => _loading = true);
  final uid = FirebaseAuth.instance.currentUser!.uid;

  try {
    final res = await http.post(
      Uri.parse('http://10.82.145.75:8000/api/join-queue'),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'firebase_uid': uid}),
    );

    final data = jsonDecode(res.body);
    if (res.statusCode == 200 && data['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Joined queue successfully!')),
        );

        // ✅ auto navigate ke MyQueuePage lepas berjaya join
        Navigator.pushNamed(context, '/myQueue');
      }
    } else {
      final msg = data['message'] ?? 'Unable to join queue.';
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Join Queue Failed'),
            content: Text(msg),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
            ],
          ),
        );
      }
    }
  } catch (e) {
    debugPrint('Error joining queue: $e');
  } finally {
    if (mounted) setState(() => _loading = false);
  }
}

  Future<void> _onRefresh() async {
    await fetchProfile();
    await _fetchAverageConsultation();
    await Future<void>.delayed(const Duration(milliseconds: 700));
  }

  Future<void> _fetchAverageConsultation() async {
    try {
      final avg = await ConsultationService.instance.fetchAverageCombinedMinutes();
      if (!mounted) return;
      setState(() => _avgMinutesCombined = avg > 0 ? avg : null);
    } catch (e) {
      debugPrint('Error fetching average consultation: $e');
    }
  }

  Future<Map<String, String?>> _fetchRoomDoctor(String uid) async {
    try {
      final res = await http.get(
        Uri.parse('http://10.82.145.75:8000/api/my-queue/$uid'),
        headers: {'Accept': 'application/json'},
      );
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true) {
          final room = data['room_name'];
          final doctor = data['doctor_name'];
          return {
            'room_name': room is String ? room : null,
            'doctor_name': doctor is String ? doctor : null,
          };
        }
      }
    } catch (e) {
      debugPrint('Error fetching room/doctor: $e');
    }
    return {'room_name': null, 'doctor_name': null};
  }

  final _geo = MediQGeofenceService.instance;

  @override
void initState() {
  super.initState();

  _geo.setupGeofencing(allowMockForTesting: true); // false for prod
  _geo.requestLocationPermission(background: true).then((ok) async {
    if (ok) await _geo.startGeofencing();
  });

  FirebaseMessaging.instance.getToken().then((token) {
    print('🔥 FCM Token (manual): $token');
  });

  fetchProfile();
  _fetchAverageConsultation();
}

  @override
void dispose() {
  _geo.dispose();
  super.dispose();
}

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final clinicRef = FirebaseFirestore.instance
        .collection('clinics')
        .doc('CL01')
        .collection('live')
        .doc('now_serving');
    final queueRef =
        uid != null ? FirebaseFirestore.instance.collection('queues').doc(uid) : null;

    final content = RefreshIndicator(
      onRefresh: _onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            floating: true,
            snap: true,
            title: const Text('MediQTrack'),
            backgroundColor: cs.primary,
            actions: [
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              )
            ],
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

         // 🔹 Greeting
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      loadingProfile
                          ? const Text('Hi, ... 👋', style: TextStyle(fontSize: 20))
                          : Text(
                              'Hi, ${name ?? 'User'} 👋',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),

                      // 🟢 Status geofence
                      ValueListenableBuilder<bool>(
                        valueListenable: _geo.isInsideGeofence,
                        builder: (context, inside, _) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              inside
                                  ? '🟢 Inside clinic area'
                                  : '🔴 Outside clinic area',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                CircleAvatar(
                  radius: 28,
                  backgroundColor: cs.primary.withOpacity(0.12),
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? Icon(Icons.person, color: cs.primary)
                      : null,
                ),
              ],
            ),
          ),
        ),

          // Clinic info (today)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today at Klinik Haifa (${_formatDateDdMmYyyy(DateTime.now())})',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      const Text('Operating hours: 8:00 AM – 10:00 PM'),
                      const SizedBox(height: 6),
                      Text(
                        'Clinic status: ${_isClinicOpenNow() ? 'Open' : 'Closed'}',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: _isClinicOpenNow() ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 5)),

          // ?? Live Now Serving (clinic-level, multi-counter)
          
          StreamBuilder<DocumentSnapshot>(
            stream: queueRef?.snapshots(),
            builder: (context, queueSnap) {
              final queueData =
                  queueSnap.data?.data() as Map<String, dynamic>? ?? {};
              final myStatus = queueData['status']?.toString().toLowerCase();
              if (myStatus == 'in_consultation') {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }
              return StreamBuilder<DocumentSnapshot>(
                stream: clinicRef.snapshots(),
                builder: (context, clinicSnap) {
                  if (!clinicSnap.hasData || !(clinicSnap.data?.exists ?? false)) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  final clinicData =
                      clinicSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final servingItems = _buildNowServingItems(clinicData);
                  if (servingItems.isEmpty) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _nowServingSection(context, servingItems),
                    ),
                  );
                },
              );
            },
          ),

          // 🔹 Queue Info
          StreamBuilder<DocumentSnapshot>(
            stream: queueRef?.snapshots(),
            builder: (context, queueSnap) {
              if (!queueSnap.hasData || !queueSnap.data!.exists) {
                return SliverToBoxAdapter(
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: _emptyQueueCard(context, onJoin: _joinQueue, loading: _loading),
                  ),
                );
              }

              final queueData =
                  queueSnap.data!.data() as Map<String, dynamic>? ?? {};
              final myQueueNo = queueData['queue_number'] ?? '-';
              final myStatus = queueData['status'] ?? 'waiting';

              return StreamBuilder<DocumentSnapshot>(
                stream: clinicRef.snapshots(),
                builder: (context, clinicSnap) {
                  if (!clinicSnap.hasData || !(clinicSnap.data?.exists ?? false)) {
                    return const SliverToBoxAdapter(child: SizedBox.shrink());
                  }
                  final clinicData =
                      clinicSnap.data?.data() as Map<String, dynamic>? ?? {};
                  final nowServing = clinicData['nowServingLabel'] ?? '-';
                  final nowSeq = clinicData['nowServingSeq'] ?? 0;
                  final myStatusLower = myStatus.toString().toLowerCase();

                  // Use people_ahead from backend if available, else compute diff
                  int? peopleAhead = queueData['people_ahead'] is int
                      ? queueData['people_ahead'] as int
                      : queueData['peopleAhead'] as int?;

                  if (peopleAhead == null) {
                    if (nowServing.toString() == myQueueNo.toString()) {
                      peopleAhead = 0;
                    } else if (nowServing == '-' || nowSeq == 0) {
                      // No live now-serving data; avoid inflating ETA
                      peopleAhead = 0;
                    } else {
                      final mySeq = int.tryParse(
                              myQueueNo.replaceAll(RegExp(r'[^0-9]'), '')) ??
                          0;
                      peopleAhead =
                          ((mySeq - nowSeq > 0) ? (mySeq - nowSeq) : 0).toInt();
                    }
                  }

                  final estWait = _formatEstWait(peopleAhead ?? 0);

                  if (myStatusLower == 'in_consultation' && uid != null) {
                    if (_roomDoctorFuture == null || _roomDoctorUid != uid) {
                      _roomDoctorUid = uid;
                      _roomDoctorFuture = _fetchRoomDoctor(uid);
                    }
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: FutureBuilder<Map<String, String?>>(
                          future: _roomDoctorFuture,
                          builder: (context, snapshot) {
                            final room = snapshot.data?['room_name'];
                            final doctor = snapshot.data?['doctor_name'];
                            return _queueSnapshot(
                              context,
                              myQueueNo,
                              nowServing,
                              peopleAhead ?? 0,
                              estWait,
                              myStatus,
                              roomName: room,
                              doctorName: doctor,
                            );
                          },
                        ),
                      ),
                    );
                  } else {
                    _roomDoctorFuture = null;
                    _roomDoctorUid = null;
                  }

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: _queueSnapshot(
                        context,
                        myQueueNo,
                        nowServing,
                        peopleAhead ?? 0,
                        estWait,
                        myStatus,
                      ),
                    ),
                  );
                },
              );
            },
          ),

          // 🔹 Quick Actions
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _quickActionsRow(context),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

        ],
      ),
    );

    return Stack(
      children: [
        content,
        ValueListenableBuilder<bool>(
          valueListenable: OutsideStatus.instance.isOutside,
          builder: (context, outside, _) {
            if (!outside) return const SizedBox.shrink();
            return Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withOpacity(0.6),
                  child: Center(
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(horizontal: 24),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: ValueListenableBuilder<int>(
                        valueListenable: OutsideStatus.instance.secondsLeft,
                        builder: (context, seconds, __) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.warning_amber_rounded,
                                  size: 56, color: Colors.redAccent),
                              const SizedBox(height: 16),
                              Text(
                                'Left Clinic Area',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Return within $seconds seconds or your queue will be cancelled automatically.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // -------------------------------------------------------------------
  // 🔹 Widgets
  // -------------------------------------------------------------------

  Widget _queueSnapshot(BuildContext context, String myNo, String now, int ahead,
      String est, String status,
      {String? roomName, String? doctorName}) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Theme.of(context).dividerColor)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Your No.'),
                  const SizedBox(height: 4),
                  Text(
                    myNo,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: scheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  status.toString().toUpperCase(),
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (status.toString().toLowerCase() == 'in_consultation') ...[
            Text(
              'Room No: ${roomName ?? '-'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 6),
            Text(
              'Doctor Name: ${doctorName ?? '-'}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ] else ...[
            Text(
              'Est. Wait: $est',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ]),
      ),
    );
  }

 Widget _emptyQueueCard(BuildContext context, {
  required Future<void> Function() onJoin, 
  bool loading = false,
}) {
  final scheme = Theme.of(context).colorScheme; // ✅ tambah ni

  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const Icon(Icons.queue_play_next_outlined, size: 36),
          const SizedBox(height: 8),
          const Text("You haven't joined the queue yet.",
              style: TextStyle(fontSize: 16), textAlign: TextAlign.center),
          const SizedBox(height: 6),
          ValueListenableBuilder<bool>(
            valueListenable: MediQGeofenceService.instance.isInsideGeofence,
            builder: (context, inside, _) {
              final isOpen = _isClinicOpenNow();
              if (inside && isOpen) return const SizedBox.shrink();
              final reasonText = !inside
                  ? 'You need to be at the clinic to join the queue.'
                  : 'The clinic is currently closed.';
              return Text(
                reasonText,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[700]),
              );
            },
          ),
          const SizedBox(height: 12),

          // ✅ butang ni dah betul sekarang
          ValueListenableBuilder<bool>(
            valueListenable: MediQGeofenceService.instance.isInsideGeofence,
            builder: (context, inside, _) {
              final isOpen = _isClinicOpenNow();
              return FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor:
                      (inside && isOpen) ? scheme.primary : Colors.grey,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                onPressed: (!inside || !isOpen || loading)
                    ? null
                    : () async {
                        await onJoin(); // panggil joinQueue
                        if (context.mounted) {
                          Navigator.pushNamed(context, '/myQueue'); // ✅ pergi page My Queue
                        }
                      },
                icon: loading
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.play_arrow_rounded),
                label: Text(
                  loading
                      ? 'Joining...'
                      : inside
                          ? (isOpen ? 'Join Queue Now' : 'Clinic Closed')
                          : 'Go to Clinic to Join',
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}


  Widget _quickActionsRow(BuildContext context) {
    return Row(children: [
      _qaBtn(
        context,
        icon: Icons.timer_outlined,
        label: 'My Queue',
        onTap: () {
          // Switch to tab if parent provided callback; fallback to page push
          if (widget.onTabSelect != null) {
            widget.onTabSelect!(1);
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const MyQueuePage()),
            );
          }
        },
      ),
      const SizedBox(width: 12),
      _qaBtn(
        context,
        icon: Icons.history,
        label: 'History',
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const VisitHistoryPage()),
          );
        },
      ),
      const SizedBox(width: 12),
      _qaBtn(
        context,
        icon: Icons.help_outline,
        label: 'Help',
        onTap: () => _showHelpSheet(context),
      ),
    ]);
  }

  Widget _qaBtn(BuildContext context,
      {required IconData icon, required String label, required VoidCallback onTap}) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor)),
            child: Column(children: [
              Icon(icon),
              const SizedBox(height: 6),
              Text(label, style: Theme.of(context).textTheme.labelLarge)
            ]),
          ),
        ),
      ),
    );
  }

  Widget _metric(BuildContext c, String label, String value) => Expanded(
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: Theme.of(c).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value,
              style: Theme.of(c)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ]),
      );

  String _formatEstWait(int peopleAhead) {
    final avg = _avgMinutesCombined;
    if (avg == null || avg <= 0) return '~ --';
    final minutes = (peopleAhead * avg).ceil();
    return '~ $minutes mins';
  }

  String _formatDateDdMmYyyy(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }

  bool _isClinicOpenNow() {
    return true;
  }

  // ---------------- Now Serving (multi-counter) ----------------
  List<_NowServingItem> _buildNowServingItems(Map<String, dynamic>? data) {
    if (data == null) return [];
    final items = <_NowServingItem>[];

    void addItem(dynamic raw, {String? mapKey}) {
      if (raw is! Map<String, dynamic>) return;
      final status = raw['status']?.toString().toLowerCase();
      if (status == 'completed' || status == 'done') return;

      final label = raw['label'] ?? raw['nowServingLabel'] ?? raw['ticket'];
      if (label == null || label.toString().trim().isEmpty) return;

      final counterValue = raw['counter'] ??
          raw['counterName'] ??
          raw['room'] ??
          raw['roomName'] ??
          mapKey ??
          '';
      final doctorValue = raw['doctor'] ??
          raw['doctorName'] ??
          raw['doctor_name'] ??
          '';

      items.add(_NowServingItem(
        label: label.toString(),
        counter: counterValue.toString(),
        doctor: doctorValue.toString(),
      ));
    }

    final counters = data['counters'];
    if (counters is List) {
      for (final raw in counters) {
        addItem(raw);
      }
    } else if (counters is Map<String, dynamic>) {
      counters.forEach((key, raw) => addItem(raw, mapKey: key));
    }

    if (items.isEmpty) {
      final fallback = data['nowServingLabel'];
      if (fallback is String && fallback.trim().isNotEmpty) {
        items.add(_NowServingItem(
          label: fallback,
          counter:
              data['counter']?.toString() ??
                  data['counterName']?.toString() ??
                  data['room']?.toString() ??
                  data['roomName']?.toString() ??
                  '',
          doctor: data['doctor']?.toString() ??
              data['doctorName']?.toString() ??
              data['doctor_name']?.toString() ??
              '',
        ));
      }
    }
    return items;
  }

  Widget _nowServingSection(BuildContext context, List<_NowServingItem> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Now Serving',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: 0.2),
        ),
        const SizedBox(height: 10),
        Column(
          children: items
              .map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _nowServingCard(context, item),
                  ))
              .toList(growable: false),
        ),
      ],
    );
  }

  Widget _nowServingCard(BuildContext context, _NowServingItem item) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(0.08),
            scheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.primary.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.countertops, size: 18, color: scheme.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  item.counter.isEmpty ? 'Room' : item.counter,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            item.label,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: scheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  void _showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.help_outline, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Need help?',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'If you need assistance:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                '• Visit the front desk for on-site support.\n'
                '• Call the clinic: 03-1234 5678\n'
                '• Email support: support@mediqtrack.com',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              const SizedBox(height: 18),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _leaveQueue() async {
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      // 🔹 1. Update Firestore (optional: flag or remove)
      await FirebaseFirestore.instance
          .collection('queues')
          .doc(uid)
          .delete()
          .catchError((_) {});

      // 🔹 2. Call Laravel API to set status = cancelled
      final response = await http.post(
        Uri.parse('http://10.82.145.75:8000/api/queue/cancel'),
        headers: {'Accept': 'application/json'},
        body: {'uid': uid},
      );

      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You have left the queue.')),
          );
        }
        print('✅ Queue cancelled successfully in MySQL.');
      } else {
        print('⚠️ Failed to cancel queue: ${data['message']}');
      }
    } catch (e) {
      print('❌ Error leaving queue: $e');
    }
  }
}

class _NowServingItem {
  final String label;
  final String counter;
  final String doctor;

  const _NowServingItem({
    required this.label,
    this.counter = '',
    this.doctor = '',
  });
}

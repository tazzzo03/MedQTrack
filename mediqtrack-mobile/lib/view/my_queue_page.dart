import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'queue_complete_page.dart';
import 'package:mediqtrack03/services/geofence_service.dart';
import 'package:mediqtrack03/services/consultation_service.dart';
import 'package:mediqtrack03/state/outside_status.dart';

class MyQueuePage extends StatefulWidget {
  const MyQueuePage({super.key});

  @override
  State<MyQueuePage> createState() => _MyQueuePageState();
}

class _MyQueuePageState extends State<MyQueuePage> {
  bool _userInQueue = false;
  String? _queueNumber;
  String? _status;
  int _peopleAhead = 0;
  int? _queueSeq;
  String _estWait = '--';
  String? _roomName;
  String? _doctorName;
  int _ewtRequestToken = 0;
  bool _loading = false;
  static const int _outsideGraceSeconds = 60;
  int _outsideSecondsLeft = _outsideGraceSeconds;
  bool _isOutside = false;
  Timer? _outsideTimer;
  int? _nowServingSeq;
  String? _nowServingLabel;
  StreamSubscription<DocumentSnapshot>? _firestoreSub;
  StreamSubscription<DocumentSnapshot>? _queueSub;
  final _geo = MediQGeofenceService();

  
  // listener function
  void _geofenceDebugPrinter() {
    // Print current value setiap kali berubah
    print('DEBUG: isInsideGeofence = ${_geo.isInsideGeofence.value}');
  }


  static const _apiBase = 'http://10.82.150.157:8000';

  @override
  void initState() {
    super.initState();
    _geo.isInsideGeofence.addListener(_geofenceDebugPrinter);
    _initGeofence();
    OutsideStatus.instance.hide(_outsideGraceSeconds);
    _geo.onEnterRegion = _handleGeofenceEnter;
    //
    _geo.onShowRuleMessage = (message) {
      debugPrint('🔔 UI RECEIVED RULE MESSAGE = $message');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 4),
        ),
      );
    };

    _geo.onRuleMessage = (message) {
      _showInAppAlert(message);
    };
    

    _geo.onStartOutsideCountdown = (seconds) {
      debugPrint('🎬 UI RECEIVED COUNTDOWN = $seconds seconds');
      startOutsideCountdownFromRule(seconds);
    };

    // Listen to Now Serving
    const clinicDocId = 'CL01';
    _firestoreSub = FirebaseFirestore.instance
        .collection('clinics')
        .doc(clinicDocId)
        .collection('live')
        .doc('now_serving')
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists) return;
      final data = snapshot.data() as Map<String, dynamic>;
      final counters = data['counters'];
      Map<String, dynamic>? selectedCounter;
      if (counters is Map<String, dynamic>) {
        if (_roomName != null && counters[_roomName] is Map<String, dynamic>) {
          selectedCounter = counters[_roomName] as Map<String, dynamic>;
        } else if (counters.isNotEmpty) {
          final first = counters.values.first;
          if (first is Map<String, dynamic>) {
            selectedCounter = first;
          }
        }
      } else if (counters is List) {
        if (_roomName != null) {
          for (final item in counters) {
            if (item is Map<String, dynamic>) {
              final room = item['room'] ??
                  item['roomName'] ??
                  item['counter'] ??
                  item['counterName'];
              if (room == _roomName) {
                selectedCounter = item;
                break;
              }
            }
          }
        }
        selectedCounter ??=
            counters.isNotEmpty && counters.first is Map<String, dynamic>
                ? counters.first as Map<String, dynamic>
                : null;
      }

      setState(() {
        _nowServingSeq = selectedCounter?['nowServingSeq'] ??
            selectedCounter?['queue_seq'] ??
            selectedCounter?['seq'] ??
            data['nowServingSeq'];
        _nowServingLabel = selectedCounter?['label'] ??
            selectedCounter?['nowServingLabel'] ??
            selectedCounter?['ticket'] ??
            data['nowServingLabel'];
      });
      _updatePeopleAhead();
    });

    // Listen to user’s queue
    _listenToQueue();
  }

  
  Future<void> _initGeofence() async {
    bool granted = await _geo.requestLocationPermission(background: true);
    if (granted) {
      _geo.setupGeofencing();
      _geo.startGeofencing();
    }
  }

  bool _isClinicOpenNow() {
    return true;
  }

  bool _isActiveQueueStatus(String? status) {
    final s = status?.toLowerCase();
    return s == 'waiting' ||
        s == 'in_consultation' ||
        s == 'serving' ||
        s == 'pharmacy' ||
        s == 'called';
  }

  bool _isInactiveQueueStatus(String? status) {
    final s = status?.toLowerCase();
    return s == 'completed' ||
        s == 'cancelled' ||
        s == 'auto_cancelled' ||
        s == 'timeout' ||
        s == 'left_geofence';
  }

  bool _shouldStartOutsideCountdown() {
    return _userInQueue && _status?.toLowerCase() == 'waiting';
  }


  Future<void> _joinQueue() async {
    setState(() => _loading = true);
    final uid = FirebaseAuth.instance.currentUser!.uid;

    try {
      final res = await http.post(
        Uri.parse('$_apiBase/api/join-queue'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'firebase_uid': uid}),
      );

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['success'] == true) {
        setState(() {
          _userInQueue = true;
          _queueNumber = data['queue_number'];
          _status = 'waiting';
        });
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(const SnackBar(content: Text('Joined queue successfully!')));
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
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Error joining queue.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

Future<void> _leaveQueue({String reason = "user"}) async {
  _outsideTimer?.cancel();
  _outsideTimer = null;

  if (_isOutside && mounted) {
    setState(() {
      _isOutside = false;
      _outsideSecondsLeft = _outsideGraceSeconds;
    });
  }

  OutsideStatus.instance.hide(_outsideGraceSeconds);

  try {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    // Delete queue document (Firestore)
    await FirebaseFirestore.instance
        .collection('queues')
        .doc(uid)
        .delete()
        .then((_) => print('🔥 Firestore queue deleted'))
        .catchError((e) => print('⚠ Firestore delete error: $e'));

    // Laravel API (send reason!)
    final response = await http.post(
      Uri.parse('$_apiBase/api/queue/cancel'),
      headers: {'Accept': 'application/json'},
      body: {
        'uid': uid,
        'reason': reason,   // <-- NOW Laravel knows!
      },
    );

    print('📡 API Response: ${response.statusCode} ${response.body}');
    final data = jsonDecode(response.body);

    if (data['success'] == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have left the queue.')),
      );
      print('✅ Queue cancelled successfully in MySQL.');
    } else {
      print('⚠ Failed to cancel queue: ${data['message']}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: ${data['message']}')),
      );
    }
  } catch (e) {
    print('❌ Error leaving queue: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error: $e')),
    );
  }
}

void _showInAppAlert(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Queue Alert'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }


  void _handleGeofenceEnter() {
    _setOutsideFlag(false);
    _cancelOutsideCountdown(showSnack: true);
  }

  void _handleGeofenceExit() {
    if (!_shouldStartOutsideCountdown() || _isOutside) return;

    _setOutsideFlag(true);
    setState(() {
      _isOutside = true;
      _outsideSecondsLeft = _outsideGraceSeconds;
    });
    OutsideStatus.instance.show(_outsideSecondsLeft);

    _outsideTimer?.cancel();
    _outsideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_outsideSecondsLeft <= 1) {
        timer.cancel();
        MediQGeofenceService.instance.notifyCountdownEnded();
      } else {
        setState(() => _outsideSecondsLeft--);
        OutsideStatus.instance.updateSeconds(_outsideSecondsLeft);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:
            Text('You left the clinic area. Returning within 60 seconds keeps your spot.'),
      ),
    );
  }

  void _onQueueAutoCancelled() {
  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Queue auto-cancelled due to leaving clinic area.'),
    ),
  );

  setState(() {
    _userInQueue = false;
    _status = 'auto_cancelled';
  });

  OutsideStatus.instance.hide(_outsideGraceSeconds);
}

  void _cancelOutsideCountdown({bool showSnack = false}) {
    if (!_isOutside) return;
    _outsideTimer?.cancel();
    _outsideTimer = null;
    setState(() {
      _isOutside = false;
      _outsideSecondsLeft = _outsideGraceSeconds;
    });
    OutsideStatus.instance.hide(_outsideGraceSeconds);
    if (showSnack && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Welcome back! Your queue spot is safe.')),
      );
    }
  }

  Future<void> _autoLeaveQueueDueToGeofence() async {
    if (!_isOutside) return;
    _outsideTimer?.cancel();
    _outsideTimer = null;
    setState(() {
      _isOutside = false;
      _outsideSecondsLeft = _outsideGraceSeconds;
    });
    OutsideStatus.instance.hide(_outsideGraceSeconds);
    await _leaveQueue(reason: "geofence");
  }

  Future<void> _setOutsideFlag(bool value) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await FirebaseFirestore.instance
        .collection('queues')
        .doc(uid)
        .update({'outside_area': value}).catchError((_) {});
  }

  void _listenToQueue() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    _queueSub?.cancel();

    _queueSub = FirebaseFirestore.instance
        .collection('queues')
        .doc(uid)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) {
        MediQGeofenceService.instance.clearActiveQueueId();
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _userInQueue = false);
        });
        return;
      }

      final data = snap.data() as Map<String, dynamic>;
      debugPrint('⚡ Queue snapshot → ${data['status']} | ${data['queue_number']}');

      final status = data['status']?.toString();
      final isActive = _isActiveQueueStatus(status);

      setState(() {
        _userInQueue = isActive;
        _queueNumber = data['queue_number'];
        _status = status;
        _queueSeq = data['queue_seq'];
      });

      if (status == 'completed') {
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QueueCompletePage()),
            );
          }
        });
      }

      if (!isActive) {
        MediQGeofenceService.instance.clearActiveQueueId();
        _outsideTimer?.cancel();
        _outsideTimer = null;
        if (_isOutside && mounted) {
          setState(() {
            _isOutside = false;
            _outsideSecondsLeft = _outsideGraceSeconds;
          });
        }
        OutsideStatus.instance.hide(_outsideGraceSeconds);
      }

      if (_isInactiveQueueStatus(status)) {
        FirebaseFirestore.instance
            .collection('queues')
            .doc(uid)
            .delete()
            .catchError((_) {});
      }

      _updatePeopleAhead();
    });
  }

  Future<void> _updatePeopleAhead() async {
    debugPrint('🧪 _updatePeopleAhead CALLED');
    if (!_userInQueue) {
      MediQGeofenceService.instance.clearActiveQueueId();
      MediQGeofenceService.instance.setEstimatedWaitMinutes(0);
      if (mounted) {
        setState(() {
          _peopleAhead = 0;
          _estWait = '--';
        });
      }
      return;
    }

    if (_status != null && !_isActiveQueueStatus(_status)) {
      MediQGeofenceService.instance.clearActiveQueueId();
      MediQGeofenceService.instance.setEstimatedWaitMinutes(0);
      if (mounted) {
        setState(() {
          _peopleAhead = 0;
          _estWait = '--';
        });
      }
      return;
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    // Quick fallback: kira based on now serving vs queue seq
    int mySeq = int.tryParse(_queueSeq.toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    int nowSeq = _nowServingSeq ?? 0;
    int diff = mySeq - nowSeq;
    if (diff < 0) diff = 0;
    if (mounted) setState(() => _peopleAhead = diff);

    // Preferred: gunakan angka dari API (kira DB ikut clinic/date/status aktif)
    try {
      final res = await http.get(
        Uri.parse('$_apiBase/api/my-queue/$uid'),
        headers: {'Accept': 'application/json'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        debugPrint('📦 my-queue response = $data');
        if (data['success'] == true) {

          final queueId = data['queue_id'];
                    if (queueId is int) {
            final apiStatus = data['status']?.toString();
            if (apiStatus == null || _isActiveQueueStatus(apiStatus)) {
              MediQGeofenceService.instance.setActiveQueueId(queueId);
              debugPrint('? ACTIVE QUEUE ID = $queueId');
            } else {
              MediQGeofenceService.instance.clearActiveQueueId();
            }
          }
          final apiAhead = data['people_ahead'];
          final roomName = data['room_name'];
          final doctorName = data['doctor_name'];
          if (mounted) {
            setState(() {
              if (apiAhead is int) {
                _peopleAhead = apiAhead;
                diff = apiAhead;
              }
              if (roomName is String && roomName.isNotEmpty) {
                _roomName = roomName;
              }
              if (doctorName is String && doctorName.isNotEmpty) {
                _doctorName = doctorName;
              }
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching people_ahead from API: $e');
    }

    _recalculateEstimatedWait(diff);
  }

  Future<void> _recalculateEstimatedWait(int diffAhead) async {
    if (diffAhead <= 0) {
      MediQGeofenceService.instance.setEstimatedWaitMinutes(0);
      if (!mounted) return;
      setState(() => _estWait = 'Ready');
      return;
    }

    final requestToken = ++_ewtRequestToken;
    if (mounted) {
      setState(() => _estWait = 'Calculating...');
    }

    try {
      final avgMinutes =
          await ConsultationService.instance.fetchAverageMinutes();
      if (!mounted || requestToken != _ewtRequestToken) return;
      if (avgMinutes <= 0) {
        MediQGeofenceService.instance.setEstimatedWaitMinutes(0);
        setState(() => _estWait = '--');
        return;
      }
      final waitMinutes = (diffAhead * avgMinutes).round();
      MediQGeofenceService.instance.setEstimatedWaitMinutes(waitMinutes);
      setState(() => _estWait = '~${waitMinutes > 0 ? waitMinutes : 1} mins');
    } catch (_) {
      MediQGeofenceService.instance.setEstimatedWaitMinutes(0);
      if (!mounted || requestToken != _ewtRequestToken) return;
      setState(() => _estWait = '--');
    }
  }

  void startOutsideCountdownFromRule(int seconds) {
  _outsideTimer?.cancel();

  setState(() {
    _isOutside = true;
    _outsideSecondsLeft = seconds;
  });

  OutsideStatus.instance.show(_outsideSecondsLeft);

  _outsideTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
    if (!mounted) {
      timer.cancel();
      return;
    }

    if (_outsideSecondsLeft <= 1) {
      timer.cancel();
      _autoLeaveQueueDueToGeofence();
    } else {
      setState(() => _outsideSecondsLeft--);
      OutsideStatus.instance.updateSeconds(_outsideSecondsLeft);
    }
  });
}



  @override
  void dispose() {
    _firestoreSub?.cancel();
    _queueSub?.cancel();
    _outsideTimer?.cancel();
    _geo.isInsideGeofence.removeListener(_geofenceDebugPrinter);
    _geo.onEnterRegion = null;
    _geo.onExitRegion = null;
    _geo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          RefreshIndicator(
            onRefresh: () async => Future.delayed(const Duration(milliseconds: 400)),
            child: CustomScrollView(
              slivers: [
                SliverAppBar(
                  floating: true,
                  snap: true,
                  backgroundColor: scheme.primary,
                  title: const Text('My Queue', style: TextStyle(color: Colors.white)),
                  centerTitle: true,
                ),
                if (!_userInQueue)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 16),
                      child: _EmptyQueueCard(
                        loading: _loading,
                        onJoin: _joinQueue,
                        scheme: scheme,
                        isOpen: _isClinicOpenNow(),
                      ),
                    ),
                  ),
                if (_userInQueue)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                      child: Column(
                        children: [
                          _QueueCard(
                            queueNumber: _queueNumber ?? '-',
                            nowServing: _nowServingLabel ?? '-',
                            peopleAhead: _peopleAhead,
                            estWait: _estWait,
                            status: _status ?? 'waiting',
                            roomName: _roomName,
                            doctorName: _doctorName,
                            color: _status == 'completed'
                                ? Colors.green
                                : (_status == 'called'
                                    ? Colors.orange
                                    : scheme.primary),
                            scheme: scheme,
                            onLeaveQueue: _leaveQueue,
                          ),
                          const SizedBox(height: 12),
                          _QueueMilestones(
                            status: _status ?? 'waiting',
                            scheme: scheme,
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (_isOutside)
            Positioned.fill(
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
                      child: Column(
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
                            'Return within $_outsideSecondsLeft seconds or your queue will be cancelled automatically.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium,
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
    );
  }
}

// ==== UI widgets ====
class _EmptyQueueCard extends StatelessWidget {
  final VoidCallback onJoin;
  final bool loading;
  final ColorScheme scheme;
  final bool isOpen;
  const _EmptyQueueCard(
      {required this.onJoin, required this.loading, required this.scheme, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        children: [
          Icon(Icons.queue_play_next_outlined,
              size: 60, color: scheme.primary.withOpacity(0.8)),
          const SizedBox(height: 16),
          Text('No Active Queue Yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
          const SizedBox(height: 8),
          Text('Join the queue to see your ticket and live status here.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Colors.grey[700])),
          const SizedBox(height: 6),
          ValueListenableBuilder<bool>(
            valueListenable: MediQGeofenceService.instance.isInsideGeofence,
            builder: (context, inside, _) {
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
          const SizedBox(height: 20),
         ValueListenableBuilder<bool>(
          valueListenable: MediQGeofenceService.instance.isInsideGeofence,
          builder: (context, inside, _) {
            final canJoin = inside && isOpen;
            return FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: canJoin ? scheme.primary : Colors.grey,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              onPressed: (!canJoin || loading) ? null : onJoin,
              icon: loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
    );
  }
}

class _QueueCard extends StatelessWidget {
  final String queueNumber;
  final String nowServing;
  final int peopleAhead;
  final String estWait;
  final String status;
  final String? roomName;
  final String? doctorName;
  final Color color;
  final VoidCallback onLeaveQueue;
  final ColorScheme scheme;
  const _QueueCard({
    required this.queueNumber,
    required this.nowServing,
    required this.peopleAhead,
    required this.estWait,
    required this.status,
    required this.roomName,
    required this.doctorName,
    required this.color,
    required this.scheme,
    required this.onLeaveQueue,
  });

  @override
Widget build(BuildContext context) {
  return Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Your Queue Details',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary)),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Queue No.', style: TextStyle(color: Colors.grey)),
                Text(queueNumber,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 20)),
              ],
            ),
            Text(status.toUpperCase(),
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 16)),
          ],
        ),
        const Divider(height: 28),
        if (const {'in_consultation', 'serving', 'pharmacy', 'called', 'completed'}
            .contains(status.toLowerCase())) ...[
          Text('Room No: ${roomName ?? '-'}'),
          const SizedBox(height: 8),
          Text('Doctor Name: ${doctorName ?? '-'}'),
        ] else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Now Serving: $nowServing'),
              Text('Ahead: $peopleAhead'),
            ],
          ),
          const SizedBox(height: 12),
          Text('Estimated Wait: $estWait'),
        ],

        const SizedBox(height: 20),

        // 🟢 Leave Queue button (only visible if status == waiting)
        if (status.toLowerCase() == 'waiting')
          Center(
            child: FilledButton.icon(
              icon: const Icon(Icons.logout),
              label: const Text('Leave Queue'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Leave Queue'),
                    content: const Text(
                        'Are you sure you want to leave the queue?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('No'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Yes, Leave'),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  onLeaveQueue(); // 🟢 panggil function cancel queue
                }
              },
            ),
          ),
      ],
    ),
  );
}

}

class _QueueMilestones extends StatelessWidget {
  final String status;
  final ColorScheme scheme;
  const _QueueMilestones({required this.status, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final steps = const [
      _QueueStep(key: 'waiting', label: 'Waiting'),
      _QueueStep(key: 'in_consultation', label: 'Consultation'),
      _QueueStep(key: 'serving', label: 'Serving'),
      _QueueStep(key: 'called', label: 'Pharmacy'),
      _QueueStep(key: 'completed', label: 'Completed'),
    ];
    final currentIndex =
        steps.indexWhere((s) => s.key == status.toLowerCase());
    final activeIndex = currentIndex == -1 ? 0 : currentIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Queue Progress',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold, color: scheme.primary),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < steps.length; i++)
            _MilestoneRow(
              step: steps[i],
              isCompleted: i < activeIndex,
              isCurrent: i == activeIndex,
              showConnector: i != steps.length - 1,
              scheme: scheme,
            ),
        ],
      ),
    );
  }
}

class _QueueStep {
  final String key;
  final String label;
  const _QueueStep({required this.key, required this.label});
}

class _MilestoneRow extends StatelessWidget {
  final _QueueStep step;
  final bool isCompleted;
  final bool isCurrent;
  final bool showConnector;
  final ColorScheme scheme;
  const _MilestoneRow({
    required this.step,
    required this.isCompleted,
    required this.isCurrent,
    required this.showConnector,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final color = isCompleted
        ? Colors.green
        : (isCurrent ? scheme.primary : Colors.grey);
    final icon = isCompleted
        ? Icons.check_circle
        : (isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Icon(icon, color: color, size: 20),
            if (showConnector)
              Container(
                width: 2,
                height: 24,
                color: isCompleted ? Colors.green : Colors.grey.shade300,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Text(
              step.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
                    color: isCurrent ? scheme.primary : null,
                  ),
            ),
          ),
        ),
      ],
    );
  }
}


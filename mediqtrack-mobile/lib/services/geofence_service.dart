// lib/services/geofence_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geofencing_api/geofencing_api.dart';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;

class MediQGeofenceService {
  static const String backendBaseUrl = 'http://10.82.150.157:8000';
  static const LatLng _clinicCenter = LatLng(2.086099, 102.599145);
  // ---------- Singleton ----------
  static final MediQGeofenceService instance = MediQGeofenceService._internal();
  MediQGeofenceService._internal();
  factory MediQGeofenceService() => instance;

  // ---------- Public state ----------
  // ============================
  // dY"\x15 TEMP DUMMY DATA (FOR TEST)
  // ============================
  int? currentQueueId;
  int estimatedWaitTime = 0;
  Timer? _finalCallTimer;

  double currentDistance = 1.2;
  static const double _earthRadiusMeters = 6371000.0;
  final ValueNotifier<bool> isInsideGeofence = ValueNotifier<bool>(false);

  // ---------- Callbacks you can set from UI ----------
  void Function()? onEnterRegion;
  void Function()? onExitRegion;
  void Function(int seconds)? onStartOutsideCountdown;
  void Function()? onQueueAutoCancelled;
  void Function(String message)? onShowRuleMessage;

  final Set<GeofenceRegion> _regions = {
    GeofenceRegion.circular(
      id: 'clinic_region',
      data: {'name': 'Klinik MediQTrack'},
      center: _clinicCenter,
      radius: 150, // meters
      loiteringDelay: 60 * 1000,
    ),
  };

  Future<bool> requestLocationPermission({bool background = false}) async {
    if (!await Geofencing.instance.isLocationServicesEnabled) return false;

    var permission = await Geofencing.instance.getLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geofencing.instance.requestLocationPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return false;
    }
    if (kIsWeb || kIsWasm) return true;

    if (Platform.isAndroid && background &&
        permission == LocationPermission.whileInUse) {
      permission = await Geofencing.instance.requestLocationPermission();
      if (permission != LocationPermission.always) return false;
    }
    return true;
  }

  void setupGeofencing({bool allowMockForTesting = true}) {
    Geofencing.instance.setup(
      interval: 5000,
      accuracy: 100,
      statusChangeDelay: 10000,
      allowsMockLocation: allowMockForTesting, // set to false for production
      printsDebugLog: true,
    );
  }

  Future<void> startGeofencing() async {
    Geofencing.instance.addGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.addGeofenceErrorCallbackListener(_onGeofenceError);
    Geofencing.instance.addLocationChangedListener((loc) {
      currentDistance = _haversineDistanceMeters(
        loc.latitude,
        loc.longitude,
        _clinicCenter.latitude,
        _clinicCenter.longitude,
      );
      debugPrint('dY"" distance=${currentDistance.toStringAsFixed(1)}m');
    });
    await Geofencing.instance.start(regions: _regions);
  }

  Future<void> _onGeofenceStatusChanged(
    GeofenceRegion region,
    GeofenceStatus status,
    Location location,
  ) async {
    // print('region=${region.id} status=${status.name}');

    if (status == GeofenceStatus.enter || status == GeofenceStatus.dwell) {
      if (!isInsideGeofence.value) {
        isInsideGeofence.value = true;
        print('📍 CALLING BACKEND with insideGeofence=true');

        await sendGeofenceStatusToBackend(
          insideGeofence: true,
        );
      }
      if (onEnterRegion != null) onEnterRegion!();     
    } else if (status == GeofenceStatus.exit) {
      if (isInsideGeofence.value) {
        isInsideGeofence.value = false;
        print('📍 CALLING BACKEND with insideGeofence=false');

        await sendGeofenceStatusToBackend(
          insideGeofence: false,
        );
      }
      if (onExitRegion != null) onExitRegion!();       
    }
  }

  Future<void> sendGeofenceStatusToBackend({
  required bool insideGeofence,
  }) async {
    if (currentQueueId == null) {
    debugPrint('⏳ Queue ID not ready yet. Skip rule evaluation.');
    return;
  }
    try {
      final url = '$backendBaseUrl/api/process-queue-rules';
      print('URL = $url');
      debugPrint('🧪 SENDING queue_id = $currentQueueId');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'queue_id': currentQueueId,
          'inside_geofence': insideGeofence,
          'distance': currentDistance,
          'ewt': estimatedWaitTime,
        }),
      );

      final data = jsonDecode(response.body);

      final actionCode = data['action_code'];
      final actionConfig = data['action_config'];

      if (actionCode != null && actionConfig != null) {
        _handleActionFromConfig(
          actionCode: actionCode,
          config: Map<String, dynamic>.from(actionConfig),
        );
      }
    } catch (e) {
      print('❌ HTTP ERROR = $e');
    }
  }



Future<void> notifyCountdownEnded() async {
  if (currentQueueId == null) return;

  final url = '$backendBaseUrl/api/countdown-ended';

  debugPrint('⏱ COUNTDOWN ENDED → CALL BACKEND');
  debugPrint('queue_id = $currentQueueId');

  try {
    final res = await http.post(
      Uri.parse(url),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'queue_id': currentQueueId,
      }),
    );

    debugPrint('✅ countdown-ended STATUS = ${res.statusCode}');
    debugPrint('✅ RESPONSE = ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      if (data['success'] == true) {
        onQueueAutoCancelled?.call();
      }
    }
  } catch (e) {
    debugPrint('❌ countdown-ended ERROR = $e');
  }
}



  void _onGeofenceError(Object error, StackTrace stack) {
    // print('error: $error');
  }

  void dispose() {
    Geofencing.instance.removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.removeGeofenceErrorCallbackListener(_onGeofenceError);
  }

  void setActiveQueueId(int queueId) {
  currentQueueId = queueId;
  debugPrint('📌 GeofenceService stored queue_id = $queueId');
}


  void clearActiveQueueId() {
  currentQueueId = null;
  debugPrint('dY"O GeofenceService cleared queue_id');
}
  void setEstimatedWaitMinutes(int minutes) {
  estimatedWaitTime = minutes < 0 ? 0 : minutes;
  debugPrint('dY"O GeofenceService updated ewt = $estimatedWaitTime');
}
void _handleFinalCall() {
  debugPrint('🚨 FINAL CALL ACTION TRIGGERED');

  // Step 3 proof (minimum viable action)
  // UI fancy & logic lain kita buat lepas ni
}




void _handleActionFromConfig({
  required String actionCode,
  required Map<String, dynamic> config,
}) {
  debugPrint('📦 ACTION CONFIG RECEIVED = $config');
  final messageTemplate = config['message_template'] as String?;

  if (messageTemplate != null && messageTemplate.isNotEmpty) {
    final minutes = config['countdown_minutes'];
    String message = messageTemplate;

    if (minutes != null) {
      message = message.replaceAll('{minutes}', minutes.toString());
    }

    onShowRuleMessage?.call(message);
  }

  final rawMessage = config['message_template'];
  final minutes = config['countdown_minutes'];

  if (rawMessage is String) {
    final message = rawMessage.replaceAll(
      '{minutes}',
      minutes?.toString() ?? '',
    );

    debugPrint('📢 RULE MESSAGE = $message');

    // 🔔 DISPATCH MESSAGE
    onRuleMessage?.call(message);
  }

  // START COUNTDOWN
  if (config['starts_countdown'] == 1) {
    final minutes = config['countdown_minutes'] ?? 0;
    debugPrint('⏱ START COUNTDOWN: $minutes minutes');
    //_startFinalCountdown(minutes);
  // 🔑 PANGGIL UI
  onStartOutsideCountdown?.call(minutes * 60);
  }

  // STOP COUNTDOWN
  if (config['stops_countdown'] == 1) {
    debugPrint('🛑 STOP COUNTDOWN');
    _stopCountdown();
  }

  // REMOVE USER (future)
  if (config['removes_user'] == 1) {
    debugPrint('🚫 REMOVE USER FROM QUEUE');
    // nanti step lain
  }
}

/*void _startFinalCountdown(int minutes) {
  _finalCallTimer?.cancel();

  int remaining = minutes * 60;

  _finalCallTimer = Timer.periodic(
    const Duration(seconds: 1),
    (timer) {
      remaining--;
      debugPrint('⏳ FINAL CALL COUNTDOWN: $remaining seconds left');

      if (remaining <= 0) {
        timer.cancel();
        debugPrint('❌ FINAL CALL TIMEOUT');
        // auto cancel akan buat later
      }
    },
  );
}*/

void _stopCountdown() {
  _finalCallTimer?.cancel();
  debugPrint('🛑 Countdown stopped');
}

void Function(String message)? onRuleMessage;


  double _haversineDistanceMeters(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    final dLat = _degToRad(lat2 - lat1);
    final dLon = _degToRad(lon2 - lon1);
    final a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degToRad(lat1)) *
            cos(_degToRad(lat2)) *
            (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return _earthRadiusMeters * c;
  }

  double _degToRad(double deg) => deg * (pi / 180.0);

}

// lib/services/geofence_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:geofencing_api/geofencing_api.dart';

class MediQGeofenceService {
  // ---------- Singleton ----------
  static final MediQGeofenceService instance = MediQGeofenceService._internal();
  MediQGeofenceService._internal();
  factory MediQGeofenceService() => instance;

  // ---------- Public state ----------
  final ValueNotifier<bool> isInsideGeofence = ValueNotifier<bool>(false);

  // ---------- Callbacks you can set from UI ----------
  void Function()? onEnterRegion;
  void Function()? onExitRegion;

  final Set<GeofenceRegion> _regions = {
    GeofenceRegion.circular(
      id: 'clinic_region',
      data: {'name': 'Klinik MediQTrack'},
      center: LatLng(2.086099, 102.599145),
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
      // Debug current location
      // print('📡 [DEBUG] ${loc.latitude}, ${loc.longitude}');
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
      }
      if (onEnterRegion != null) onEnterRegion!();     // 🔔 inform UI
    } else if (status == GeofenceStatus.exit) {
      if (isInsideGeofence.value) {
        isInsideGeofence.value = false;
      }
      if (onExitRegion != null) onExitRegion!();       // 🔔 inform UI
    }
  }

  void _onGeofenceError(Object error, StackTrace stack) {
    // print('error: $error');
  }

  void dispose() {
    Geofencing.instance.removeGeofenceStatusChangedListener(_onGeofenceStatusChanged);
    Geofencing.instance.removeGeofenceErrorCallbackListener(_onGeofenceError);
  }
}

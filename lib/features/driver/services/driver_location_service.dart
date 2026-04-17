import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Service to handle continuous driver location tracking and Supabase updates.
class DriverLocationService {
  Timer? _locationTimer;
  final String driverId;
  String? _currentOrderId;

  DriverLocationService({required this.driverId});

  /// Start tracking driver location and updating Supabase every [intervalSeconds].
  Future<void> startTracking({int intervalSeconds = 5, String? orderId}) async {
    debugPrint(
      '[DriverLocation] Starting location tracking for driver: $driverId',
    );

    _currentOrderId = orderId;

    // Check and request location permission
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      final result = await Geolocator.requestPermission();
      if (result == LocationPermission.denied) {
        debugPrint('[DriverLocation] Location permission denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      debugPrint('[DriverLocation] Location permission permanently denied');
      return;
    }

    // Cancel existing timer
    _locationTimer?.cancel();

    // Fetch and update location immediately
    await _updateLocation();

    // Set up periodic updates
    _locationTimer = Timer.periodic(
      Duration(seconds: intervalSeconds),
      (_) => _updateLocation(),
    );
  }

  /// Stop tracking and cancel timer.
  void stopTracking() {
    debugPrint('[DriverLocation] Stopping location tracking');
    _locationTimer?.cancel();
    _locationTimer = null;
    _currentOrderId = null;
  }

  /// Fetch current position and update Supabase.
  Future<void> _updateLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      debugPrint(
        '[DriverLocation] Current position: ${position.latitude}, ${position.longitude}',
      );

      // Update driver location in orders table
      await _updateDriverLocation(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      debugPrint('[DriverLocation] Error getting position: $e');
    }
  }

  /// Update driver latitude/longitude in active orders.
  Future<void> _updateDriverLocation({
    required double latitude,
    required double longitude,
  }) async {
    try {
      if (_currentOrderId != null && _currentOrderId!.isNotEmpty) {
        // Update specific order if provided
        await Supabase.instance.client
            .from('orders')
            .update({'driver_lat': latitude, 'driver_lng': longitude})
            .eq('id', _currentOrderId!)
            .eq('driver_id', driverId);

        debugPrint('[DriverLocation] Updated order $_currentOrderId');
      } else {
        // Update all active orders for this driver
        await Supabase.instance.client
            .from('orders')
            .update({'driver_lat': latitude, 'driver_lng': longitude})
            .eq('driver_id', driverId)
            .inFilter('status', ['assigned', 'on_the_way']);

        debugPrint('[DriverLocation] Updated active orders for driver');
      }
    } catch (e) {
      debugPrint('[DriverLocation] Error updating location: $e');
    }
  }

  /// Set the current active order ID.
  void setCurrentOrder(String? orderId) {
    _currentOrderId = orderId;
    debugPrint('[DriverLocation] Current order set to: $_currentOrderId');
  }

  /// Get current driver location.
  Future<Position?> getCurrentLocation() async {
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      debugPrint('[DriverLocation] Error getting current location: $e');
      return null;
    }
  }

  /// Dispose service and cleanup.
  void dispose() {
    stopTracking();
  }
}

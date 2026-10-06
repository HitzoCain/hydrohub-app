import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DriverSessionData {
  const DriverSessionData({required this.id, required this.name});

  final String id;
  final String name;
}

class DriverSession {
  const DriverSession._();

  static const String _driverIdKey = 'driver_id';
  static const String _driverNameKey = 'driver_name';
  static const String _driverAccessCodeKey = 'driver_access_code';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static String? id;
  static String? name;
  static String? accessCode;

  static Future<String?> getAccessCode() async {
    final storedCode = await _secureStorage.read(key: _driverAccessCodeKey);
    accessCode = storedCode;
    return storedCode;
  }

  static Future<String?> getDriverId() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString(_driverIdKey);
    id = driverId;
    return driverId;
  }

  static Future<void> save({
    required String driverId,
    required String driverName,
    required String driverAccessCode,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_driverIdKey, driverId);
    await prefs.setString(_driverNameKey, driverName);
    await _secureStorage.write(
      key: _driverAccessCodeKey,
      value: driverAccessCode,
    );

    id = driverId;
    name = driverName;
    accessCode = driverAccessCode;
  }

  static Future<DriverSessionData?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final driverId = prefs.getString(_driverIdKey);

    if (driverId == null || driverId.trim().isEmpty) {
      id = null;
      name = null;
      return null;
    }

    final storedName = prefs.getString(_driverNameKey)?.trim();
    final resolvedName = (storedName == null || storedName.isEmpty)
        ? 'Driver'
        : storedName;

    id = driverId;
    name = resolvedName;

    return DriverSessionData(id: driverId, name: resolvedName);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_driverIdKey);
    await prefs.remove(_driverNameKey);
    await _secureStorage.delete(key: _driverAccessCodeKey);

    id = null;
    name = null;
    accessCode = null;
  }
}

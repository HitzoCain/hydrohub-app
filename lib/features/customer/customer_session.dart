import 'package:shared_preferences/shared_preferences.dart';

/// Session helper to cache customer profile data locally
class CustomerSession {
  static const String _customerIdKey = 'customer_id';
  static const String _customerNameKey = 'customer_name';
  static const String _customerPhoneKey = 'customer_phone';
  static const String _customerAddressKey = 'customer_address';

  static String? id;
  static String? name;
  static String? phone;
  static String? address;

  /// Load customer session from shared preferences
  static Future<({String id, String name, String phone, String address})?>
  load() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final customerId = prefs.getString(_customerIdKey);
      if (customerId == null || customerId.isEmpty) {
        return null;
      }

      id = customerId;
      name = prefs.getString(_customerNameKey) ?? '';
      phone = prefs.getString(_customerPhoneKey) ?? '';
      address = prefs.getString(_customerAddressKey) ?? '';

      return (
        id: customerId,
        name: name ?? '',
        phone: phone ?? '',
        address: address ?? '',
      );
    } catch (e) {
      return null;
    }
  }

  /// Save customer session to shared preferences
  static Future<void> save({
    required String customerId,
    required String customerName,
    String? customerPhone,
    String? customerAddress,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      id = customerId;
      name = customerName;
      phone = customerPhone ?? '';
      address = customerAddress ?? '';

      await Future.wait([
        prefs.setString(_customerIdKey, customerId),
        prefs.setString(_customerNameKey, customerName),
        prefs.setString(_customerPhoneKey, customerPhone ?? ''),
        prefs.setString(_customerAddressKey, customerAddress ?? ''),
      ]);
    } catch (e) {
      // Silently fail
    }
  }

  /// Clear customer session
  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      id = null;
      name = null;
      phone = null;
      address = null;

      await Future.wait([
        prefs.remove(_customerIdKey),
        prefs.remove(_customerNameKey),
        prefs.remove(_customerPhoneKey),
        prefs.remove(_customerAddressKey),
      ]);
    } catch (e) {
      // Silently fail
    }
  }
}

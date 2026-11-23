import 'package:supabase_flutter/supabase_flutter.dart';

class CustomerProfileService {
  static Future<Map<String, Map<String, String>>> fetchProfiles(
    Iterable<String> customerIds,
  ) async {
    final ids = customerIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList();

    if (ids.isEmpty) return {};

    final profiles = await Supabase.instance.client
        .from('customer_profiles')
        .select('user_id, name, avatar_url')
        .inFilter('user_id', ids);

    final result = <String, Map<String, String>>{};
    for (final profile in profiles.whereType<Map<String, dynamic>>()) {
      final userId = profile['user_id']?.toString().trim() ?? '';
      if (userId.isEmpty) continue;
      result[userId] = {
        'name': profile['name']?.toString().trim() ?? '',
        'avatarUrl': profile['avatar_url']?.toString().trim() ?? '',
      };
    }
    return result;
  }

  static Future<Map<String, String>> fetchNames(
    Iterable<String> customerIds,
  ) async {
    final profiles = await fetchProfiles(customerIds);
    return profiles.map(
      (userId, profile) => MapEntry(userId, profile['name'] ?? ''),
    );
  }

  static String resolveName(
    Map<String, String> profileNames,
    dynamic customerId,
    dynamic storedName, {
    String fallback = 'Customer',
  }) {
    final id = customerId?.toString().trim() ?? '';
    final profileName = profileNames[id]?.trim() ?? '';
    if (profileName.isNotEmpty) return profileName;

    final stored = storedName?.toString().trim() ?? '';
    return stored.isEmpty ? fallback : stored;
  }
}

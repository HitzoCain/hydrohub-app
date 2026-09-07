import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/philippine_location.dart';

class AddressService {
  AddressService({http.Client? client}) : _client = client ?? http.Client();

  static const _baseUrl = 'https://psgc.gitlab.io/api';
  final http.Client _client;
  final Map<String, List<PhilippineLocation>> _cache = {};
  final Map<String, Future<List<PhilippineLocation>>> _requests = {};

  Future<List<PhilippineLocation>> getRegions() => _get('/regions', 'regions');

  Future<List<PhilippineLocation>> getProvinces(String regionCode) =>
      _get('/regions/$regionCode/provinces', 'provinces:$regionCode');

  Future<List<PhilippineLocation>> getCitiesMunicipalities(
    String provinceCode,
  ) =>
      _get('/provinces/$provinceCode/cities-municipalities', 'cities:$provinceCode');

  Future<List<PhilippineLocation>> getBarangays(String cityCode) =>
      _get('/cities-municipalities/$cityCode/barangays', 'barangays:$cityCode');

  Future<List<PhilippineLocation>> _get(String path, String cacheKey) {
    final cached = _cache[cacheKey];
    if (cached != null) return Future.value(cached);

    final pending = _requests[cacheKey];
    if (pending != null) return pending;

    final request = _fetch(path, cacheKey);
    _requests[cacheKey] = request;
    return request.whenComplete(() => _requests.remove(cacheKey));
  }

  Future<List<PhilippineLocation>> _fetch(String path, String cacheKey) async {
    final response = await _client.get(Uri.parse('$_baseUrl$path'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Unable to load locations (${response.statusCode})');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) throw const FormatException('Invalid location response');

    final locations = decoded
        .whereType<Map<String, dynamic>>()
        .map(PhilippineLocation.fromJson)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    _cache[cacheKey] = locations;
    return locations;
  }

  String buildFullAddress({
    required String region,
    required String province,
    required String cityMunicipality,
    required String barangay,
    String? street,
    String? houseNumber,
    String? landmark,
  }) {
    final streetLine = [houseNumber, street]
        .where((value) => value?.trim().isNotEmpty == true)
        .map((value) => value!.trim())
        .join(' ');
    final parts = <String>[];
    if (streetLine.isNotEmpty) parts.add(streetLine);
    if (barangay.trim().isNotEmpty) parts.add(_withBarangayPrefix(barangay));
    if (cityMunicipality.trim().isNotEmpty) parts.add(cityMunicipality.trim());
    if (province.trim().isNotEmpty) parts.add(province.trim());
    if (region.trim().isNotEmpty) parts.add(region.trim());
    if (landmark?.trim().isNotEmpty == true) parts.add('Landmark: ${landmark!.trim()}');
    return parts.join(', ');
  }

  String _withBarangayPrefix(String value) {
    final trimmed = value.trim();
    return trimmed.toLowerCase().startsWith('barangay ') ? trimmed : 'Barangay $trimmed';
  }
}

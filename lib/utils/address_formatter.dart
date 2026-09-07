String formatAddressParts({
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
  if (barangay.trim().isNotEmpty) {
    final value = barangay.trim();
    parts.add(value.toLowerCase().startsWith('barangay ') ? value : 'Barangay $value');
  }
  if (cityMunicipality.trim().isNotEmpty) parts.add(cityMunicipality.trim());
  if (province.trim().isNotEmpty) parts.add(province.trim());
  if (region.trim().isNotEmpty) parts.add(region.trim());
  if (landmark?.trim().isNotEmpty == true) parts.add('Landmark: ${landmark!.trim()}');
  return parts.join(', ');
}

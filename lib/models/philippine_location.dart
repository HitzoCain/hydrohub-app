class PhilippineLocation {
  const PhilippineLocation({required this.code, required this.name});

  final String code;
  final String name;

  factory PhilippineLocation.fromJson(Map<String, dynamic> json) {
    final code = json['code']?.toString().trim() ?? '';
    final name = json['name']?.toString().trim() ?? '';
    if (code.isEmpty || name.isEmpty) {
      throw const FormatException('Location is missing code or name');
    }
    return PhilippineLocation(code: code, name: name);
  }
}

class AddressFormData {
  const AddressFormData({
    required this.region,
    required this.province,
    required this.cityMunicipality,
    required this.barangay,
    this.street,
    this.houseNumber,
    this.landmark,
  });

  final PhilippineLocation region;
  final PhilippineLocation province;
  final PhilippineLocation cityMunicipality;
  final PhilippineLocation barangay;
  final String? street;
  final String? houseNumber;
  final String? landmark;
}

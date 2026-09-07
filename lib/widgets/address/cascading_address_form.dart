import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../models/philippine_location.dart';
import '../../services/address_service.dart';

class CascadingAddressForm extends StatefulWidget {
  const CascadingAddressForm({
    super.key,
    required this.onSave,
    required this.onPickLocation,
    this.initialData,
    this.initialLocation,
    this.showMapPicker = true,
  });

  final AddressFormData? initialData;
  final LatLng? initialLocation;
  final bool showMapPicker;
  final Future<LatLng?> Function() onPickLocation;
  final Future<void> Function(AddressFormData data, LatLng? location) onSave;

  @override
  State<CascadingAddressForm> createState() => _CascadingAddressFormState();
}

class _CascadingAddressFormState extends State<CascadingAddressForm> {
  final _service = AddressService();
  final _formKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _houseController = TextEditingController();
  final _landmarkController = TextEditingController();

  List<PhilippineLocation> _regions = [];
  List<PhilippineLocation> _provinces = [];
  List<PhilippineLocation> _cities = [];
  List<PhilippineLocation> _barangays = [];
  PhilippineLocation? _region;
  PhilippineLocation? _province;
  PhilippineLocation? _city;
  PhilippineLocation? _barangay;
  LatLng? _location;
  String? _error;
  bool _loadingRegions = false;
  bool _loadingChildren = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialData;
    _streetController.text = initial?.street ?? '';
    _houseController.text = initial?.houseNumber ?? '';
    _landmarkController.text = initial?.landmark ?? '';
    _location = widget.initialLocation;
    _loadRegions(initial);
  }

  @override
  void dispose() {
    _streetController.dispose();
    _houseController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  Future<void> _loadRegions(AddressFormData? initial) async {
    setState(() => _loadingRegions = true);
    try {
      final values = await _service.getRegions();
      if (!mounted) return;
      setState(() {
        _regions = values;
        _region = _find(values, initial?.region.code);
      });
      if (_region != null) await _loadProvinces(_region!, initial);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load regions.');
    } finally {
      if (mounted) setState(() => _loadingRegions = false);
    }
  }

  Future<void> _loadProvinces(
    PhilippineLocation region,
    AddressFormData? initial,
  ) async {
    setState(() {
      _loadingChildren = true;
      _provinces = [];
      _cities = [];
      _barangays = [];
      _province = null;
      _city = null;
      _barangay = null;
      _error = null;
    });
    try {
      final values = await _service.getProvinces(region.code);
      if (!mounted) return;
      setState(() {
        _provinces = values;
        _province = _find(values, initial?.province.code);
      });
      if (_province != null) await _loadCities(_province!, initial);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load provinces.');
    } finally {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  Future<void> _loadCities(
    PhilippineLocation province,
    AddressFormData? initial,
  ) async {
    setState(() {
      _loadingChildren = true;
      _cities = [];
      _barangays = [];
      _city = null;
      _barangay = null;
      _error = null;
    });
    try {
      final values = await _service.getCitiesMunicipalities(province.code);
      if (!mounted) return;
      setState(() {
        _cities = values;
        _city = _find(values, initial?.cityMunicipality.code);
      });
      if (_city != null) await _loadBarangays(_city!, initial);
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load cities or municipalities.');
    } finally {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  Future<void> _loadBarangays(
    PhilippineLocation city,
    AddressFormData? initial,
  ) async {
    setState(() {
      _loadingChildren = true;
      _barangays = [];
      _barangay = null;
      _error = null;
    });
    try {
      final values = await _service.getBarangays(city.code);
      if (!mounted) return;
      setState(() {
        _barangays = values;
        _barangay = _find(values, initial?.barangay.code);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Unable to load barangays.');
    } finally {
      if (mounted) setState(() => _loadingChildren = false);
    }
  }

  PhilippineLocation? _find(List<PhilippineLocation> values, String? code) {
    if (code == null) return null;
    for (final value in values) {
      if (value.code == code) return value;
    }
    return null;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false) ||
        _region == null ||
        _province == null ||
        _city == null ||
        _barangay == null) {
      return;
    }
    final location = _location;
    setState(() => _saving = true);
    try {
      await widget.onSave(
        AddressFormData(
          region: _region!,
          province: _province!,
          cityMunicipality: _city!,
          barangay: _barangay!,
          street: _streetController.text,
          houseNumber: _houseController.text,
          landmark: _landmarkController.text,
        ),
        location,
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save address: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      );

  DropdownButtonFormField<PhilippineLocation> _dropdown({
    required String label,
    required List<PhilippineLocation> items,
    required PhilippineLocation? value,
    required ValueChanged<PhilippineLocation?>? onChanged,
  }) =>
      DropdownButtonFormField<PhilippineLocation>(
        initialValue: value,
        isExpanded: true,
        decoration: _decoration(label),
        items: items
            .map((item) => DropdownMenuItem(value: item, child: Text(item.name)))
            .toList(),
        onChanged: onChanged,
        validator: (value) => value == null ? 'Please select a $label.' : null,
      );

  @override
  Widget build(BuildContext context) {
    final disabled = _loadingRegions || _loadingChildren || _saving;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            TextButton(onPressed: () => _loadRegions(widget.initialData), child: const Text('Try Again')),
          ],
          _dropdown(
            label: 'Region',
            items: _regions,
            value: _region,
            onChanged: disabled ? null : (value) {
              if (value == null) return;
              _loadProvinces(value, null);
              setState(() => _region = value);
            },
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Province',
            items: _provinces,
            value: _province,
            onChanged: _region == null || disabled ? null : (value) {
              if (value == null) return;
              _loadCities(value, null);
              setState(() => _province = value);
            },
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'City / Municipality',
            items: _cities,
            value: _city,
            onChanged: _province == null || disabled ? null : (value) {
              if (value == null) return;
              _loadBarangays(value, null);
              setState(() => _city = value);
            },
          ),
          const SizedBox(height: 12),
          _dropdown(
            label: 'Barangay',
            items: _barangays,
            value: _barangay,
            onChanged: _city == null || disabled ? null : (value) => setState(() => _barangay = value),
          ),
          const SizedBox(height: 12),
          TextFormField(controller: _houseController, decoration: _decoration('House number'), validator: (value) => value!.trim().isEmpty ? 'Please enter your house number.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _streetController, decoration: _decoration('Street'), validator: (value) => value!.trim().isEmpty ? 'Please enter your street.' : null),
          const SizedBox(height: 12),
          TextFormField(controller: _landmarkController, decoration: _decoration('Landmark (Optional)')),
          const SizedBox(height: 16),
          if (widget.showMapPicker) ...[
            OutlinedButton.icon(
              onPressed: disabled ? null : () async {
                final location = await widget.onPickLocation();
                if (mounted && location != null) setState(() => _location = location);
              },
              icon: const Icon(Icons.map_outlined),
              label: Text(_location == null ? 'Select Exact Location on Map' : 'Location Confirmed'),
            ),
            const SizedBox(height: 12),
          ],
          ElevatedButton(onPressed: disabled ? null : _save, child: Text(_saving ? 'Saving...' : 'Save Address')),
        ],
      ),
    );
  }
}

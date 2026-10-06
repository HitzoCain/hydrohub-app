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
    this.requiredLocation = false,
    this.onResolveLocation,
    this.onUseCurrentLocation,
    this.targetRegionName,
    this.targetProvinceName,
    this.targetCityMunicipalityName,
  });

  final AddressFormData? initialData;
  final LatLng? initialLocation;
  final bool showMapPicker;
  final bool requiredLocation;
  final Future<AddressLocationDetails?> Function(LatLng location)?
  onResolveLocation;
  final Future<LatLng?> Function()? onUseCurrentLocation;
  final String? targetRegionName;
  final String? targetProvinceName;
  final String? targetCityMunicipalityName;
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
  String? _locationError;
  bool _loadingRegions = false;
  bool _loadingChildren = false;
  bool _resolvingMapLocation = false;
  bool _gettingCurrentLocation = false;
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

  List<PhilippineLocation> _matchTarget(
    List<PhilippineLocation> values,
    String? target,
  ) {
    final rawTarget = target?.trim();
    if (rawTarget == null || rawTarget.isEmpty) {
      return values;
    }

    final normalized = rawTarget.toLowerCase();
    final exactMatches = values
        .where((value) => value.name.trim().toLowerCase() == normalized)
        .toList();
    if (exactMatches.isNotEmpty) return exactMatches;

    final matches = values.where((value) {
      final valueName = value.name.trim().toLowerCase();
      return valueName == normalized || valueName.contains(normalized);
    }).toList();

    return matches;
  }

  Future<void> _loadRegions(AddressFormData? initial) async {
    setState(() => _loadingRegions = true);
    try {
      final values = await _service.getRegions();
      final filtered = _matchTarget(values, widget.targetRegionName);
      if (!mounted) return;
      setState(() {
        _regions = filtered;
        _region = _find(filtered, initial?.region.code) ?? _pickFirst(filtered);
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
      final filtered = _matchTarget(values, widget.targetProvinceName);
      if (!mounted) return;
      setState(() {
        _provinces = filtered;
        _province =
            _find(filtered, initial?.province.code) ?? _pickFirst(filtered);
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
      final filtered = _matchTarget(values, widget.targetCityMunicipalityName);
      if (!mounted) return;
      setState(() {
        _cities = filtered;
        _city =
            _find(filtered, initial?.cityMunicipality.code) ??
            _pickFirst(filtered);
      });
      if (_city != null) await _loadBarangays(_city!, initial);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Unable to load cities or municipalities.');
      }
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

  PhilippineLocation? _pickFirst(List<PhilippineLocation> values) {
    return values.isEmpty ? null : values.first;
  }

  String _normalizeLocationName(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(city|municipality|barangay|province)\s+of\b'),
          '',
        )
        .replaceAll(RegExp(r'\b(city|municipality|barangay|province)\b'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  PhilippineLocation? _matchLocation(
    List<PhilippineLocation> locations,
    String? name,
  ) {
    if (name == null || name.trim().isEmpty) return null;
    final normalizedName = _normalizeLocationName(name);
    for (final location in locations) {
      if (_normalizeLocationName(location.name) == normalizedName) {
        return location;
      }
    }
    return null;
  }

  Future<void> _fillFromMapLocation(LatLng location) async {
    final resolver = widget.onResolveLocation;
    if (resolver == null) return;

    setState(() {
      _resolvingMapLocation = true;
      _locationError = null;
    });

    try {
      final details = await resolver(location);
      if (!mounted) return;
      if (details == null) {
        setState(() {
          _locationError =
              'Pin selected. Complete any address fields the map could not identify.';
        });
        return;
      }

      final previousRegion = _region;
      final previousProvince = _province;
      final previousCity = _city;
      final regions = await _service.getRegions();
      final region =
          _matchLocation(regions, details.region) ??
          _find(regions, previousRegion?.code);
      if (region == null) {
        _setResolvedAddressText(details);
        setState(() {
          _regions = regions;
          _locationError =
              'Pin selected. Choose a matching region from the address fields.';
        });
        return;
      }

      final provinces = await _service.getProvinces(region.code);
      final province =
          _matchLocation(provinces, details.province) ??
          (previousRegion?.code == region.code
              ? _find(provinces, previousProvince?.code)
              : null);
      if (province == null) {
        _setResolvedAddressText(details);
        setState(() {
          _regions = regions;
          _region = region;
          _provinces = provinces;
          _province = null;
          _cities = [];
          _city = null;
          _barangays = [];
          _barangay = null;
          _locationError =
              'Pin selected. Choose a province and complete the remaining fields.';
        });
        return;
      }

      final cities = await _service.getCitiesMunicipalities(province.code);
      final city =
          _matchLocation(cities, details.cityMunicipality) ??
          (previousProvince?.code == province.code
              ? _find(cities, previousCity?.code)
              : null);
      final barangays = city == null
          ? <PhilippineLocation>[]
          : await _service.getBarangays(city.code);
      final barangay =
          _matchLocation(barangays, details.barangay) ??
          (previousCity?.code == city?.code
              ? _find(barangays, _barangay?.code)
              : null);

      _setResolvedAddressText(details);
      setState(() {
        _regions = regions;
        _region = region;
        _provinces = provinces;
        _province = province;
        _cities = cities;
        _city = city;
        _barangays = barangays;
        _barangay = barangay;
        if (city == null || barangay == null) {
          _locationError =
              'Pin selected. Complete any address fields the map could not identify.';
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError =
            'Pin selected, but address details could not be loaded. Complete the fields manually.';
      });
      debugPrint('Could not fill address from selected map location: $error');
    } finally {
      if (mounted) setState(() => _resolvingMapLocation = false);
    }
  }

  void _setResolvedAddressText(AddressLocationDetails details) {
    final houseNumber = details.houseNumber?.trim();
    final street = details.street?.trim();
    if (houseNumber?.isNotEmpty == true) _houseController.text = houseNumber!;
    if (street?.isNotEmpty == true) _streetController.text = street!;
  }

  Future<void> _selectMapLocation() async {
    final location = await widget.onPickLocation();
    if (!mounted || location == null) return;
    setState(() {
      _location = location;
      _locationError = null;
    });
    await _fillFromMapLocation(location);
  }

  Future<void> _useCurrentLocation() async {
    final getLocation = widget.onUseCurrentLocation;
    if (getLocation == null) return;

    setState(() {
      _gettingCurrentLocation = true;
      _locationError = null;
    });

    try {
      final location = await getLocation();
      if (!mounted || location == null) return;
      setState(() {
        _location = location;
      });
      await _fillFromMapLocation(location);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _locationError = error.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _gettingCurrentLocation = false);
    }
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
    if (widget.requiredLocation && location == null) {
      setState(() {
        _locationError = 'Select the exact delivery location on the map.';
      });
      return;
    }
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
        final message = error.toString().replaceFirst('Exception: ', '');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  InputDecoration _decoration(String label) =>
      InputDecoration(labelText: label, border: const OutlineInputBorder());

  DropdownButtonFormField<PhilippineLocation> _dropdown({
    required String label,
    required List<PhilippineLocation> items,
    required PhilippineLocation? value,
    required ValueChanged<PhilippineLocation?>? onChanged,
  }) => DropdownButtonFormField<PhilippineLocation>(
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
    final disabled =
        _loadingRegions ||
        _loadingChildren ||
        _resolvingMapLocation ||
        _gettingCurrentLocation ||
        _saving;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            TextButton(
              onPressed: () => _loadRegions(widget.initialData),
              child: const Text('Try Again'),
            ),
          ],
          _dropdown(
            label: 'Region',
            items: _regions,
            value: _region,
            onChanged: disabled
                ? null
                : (value) {
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
            onChanged: _region == null || disabled
                ? null
                : (value) {
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
            onChanged: _province == null || disabled
                ? null
                : (value) {
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
            onChanged: _city == null || disabled
                ? null
                : (value) => setState(() => _barangay = value),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _houseController,
            decoration: _decoration('House number'),
            validator: (value) => value!.trim().isEmpty
                ? 'Please enter your house number.'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _streetController,
            decoration: _decoration('Street'),
            validator: (value) =>
                value!.trim().isEmpty ? 'Please enter your street.' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _landmarkController,
            decoration: _decoration('Landmark (Optional)'),
          ),
          const SizedBox(height: 16),
          if (widget.showMapPicker) ...[
            if (widget.onUseCurrentLocation != null) ...[
              OutlinedButton.icon(
                onPressed: disabled ? null : _useCurrentLocation,
                icon: const Icon(Icons.my_location_outlined),
                label: Text(
                  _gettingCurrentLocation
                      ? 'Getting current location...'
                      : 'Use My Current Location',
                ),
              ),
              const SizedBox(height: 8),
            ],
            OutlinedButton.icon(
              onPressed: disabled ? null : _selectMapLocation,
              icon: const Icon(Icons.map_outlined),
              label: Text(
                _resolvingMapLocation
                    ? 'Filling address...'
                    : _location == null
                    ? 'Select Exact Location on Map'
                    : 'Location Confirmed',
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Map selection is optional. We can estimate the location from your address.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ),
            if (_locationError != null) ...[
              const SizedBox(height: 6),
              Text(
                _locationError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 12),
          ],
          ElevatedButton(
            onPressed: disabled ? null : _save,
            child: Text(_saving ? 'Saving...' : 'Save Address'),
          ),
        ],
      ),
    );
  }
}

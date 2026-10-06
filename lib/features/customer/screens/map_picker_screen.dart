import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, this.initialLocation});

  final LatLng? initialLocation;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  LatLng? selectedLatLng;

  @override
  void initState() {
    super.initState();
    selectedLatLng = widget.initialLocation;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Location')),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: widget.initialLocation ?? const LatLng(11.775, 124.886),
              initialZoom: 15,
              onTap: (tapPosition, point) {
                setState(() {
                  selectedLatLng = point;
                });
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'io.github.hitzocain.aquainlavada',
              ),
              if (selectedLatLng != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: selectedLatLng!,
                      child: const Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: ElevatedButton(
              onPressed: selectedLatLng == null
                  ? null
                  : () {
                      Navigator.pop(context, selectedLatLng);
                    },
              child: const Text('Confirm Location'),
            ),
          ),
        ],
      ),
    );
  }
}

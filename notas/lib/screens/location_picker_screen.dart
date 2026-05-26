import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../theme.dart';

class LocationPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final double initialRadius;

  const LocationPickerScreen({
    super.key,
    this.initialLat,
    this.initialLng,
    this.initialRadius = 200,
  });

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  late LatLng _point;
  late double _radius;
  final _mapController = MapController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _radius = widget.initialRadius;
    if (widget.initialLat != null && widget.initialLng != null) {
      _point = LatLng(widget.initialLat!, widget.initialLng!);
      _loading = false;
    } else {
      _point = const LatLng(38.7169, -9.1399);
      _fetchCurrentLocation();
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.denied &&
          perm != LocationPermission.deniedForever) {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 8),
          ),
        );
        if (mounted) {
          setState(() {
            _point = LatLng(pos.latitude, pos.longitude);
            _loading = false;
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _mapController.move(_point, 15);
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher Local'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, {
              'lat': _point.latitude,
              'lng': _point.longitude,
              'radius': _radius,
            }),
            child: const Text(
              'Confirmar',
              style: TextStyle(
                  color: AppTheme.accent, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: AppTheme.accent))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _point,
                      initialZoom: 15,
                      onTap: (_, point) => setState(() => _point = point),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.notasgeo.notas',
                        maxZoom: 19,
                      ),
                      CircleLayer(
                        circles: [
                          CircleMarker(
                            point: _point,
                            radius: _radius,
                            useRadiusInMeter: true,
                            color: const Color(0x26C8F060),
                            borderColor: AppTheme.accent,
                            borderStrokeWidth: 2,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _point,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.location_pin,
                                color: AppTheme.accent, size: 40),
                          ),
                        ],
                      ),
                    ],
                  ),
          ),
          Container(
            color: AppTheme.surface,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.radar, color: AppTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Raio: ${_radius.toInt()} metros',
                      style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                Slider(
                  value: _radius,
                  min: 50,
                  max: 2000,
                  divisions: 39,
                  onChanged: (v) => setState(() => _radius = v),
                ),
                const Text(
                  'Toque no mapa para definir o ponto',
                  style:
                      TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

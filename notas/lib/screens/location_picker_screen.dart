import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/saved_place.dart';
import '../services/places_service.dart';
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

  Future<void> _saveCurrentPlace() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Guardar local'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: const InputDecoration(
            hintText: 'Nome do local',
            prefixIcon: Icon(Icons.bookmark, color: AppTheme.accent),
          ),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Guardar',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await PlacesService.save(SavedPlace(
        name: name,
        latitude: _point.latitude,
        longitude: _point.longitude,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Local "$name" guardado')),
        );
        setState(() {}); // refresh saved places list
      }
    }
  }

  void _showSavedPlaces() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final places = PlacesService.getAll();
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.bookmark, color: AppTheme.accent, size: 18),
                    const SizedBox(width: 8),
                    const Text('Locais guardados',
                        style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    if (places.isEmpty)
                      const Text('Nenhum local guardado',
                          style: TextStyle(
                              color: AppTheme.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (places.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 300),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: places.length,
                    itemBuilder: (_, i) {
                      final place = places[i];
                      return ListTile(
                        leading:
                            const Icon(Icons.place, color: AppTheme.accent),
                        title: Text(place.name,
                            style: const TextStyle(
                                color: AppTheme.textPrimary)),
                        subtitle: Text(
                          '${place.latitude.toStringAsFixed(5)}, ${place.longitude.toStringAsFixed(5)}',
                          style: const TextStyle(
                              color: AppTheme.textSecondary, fontSize: 12),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.error, size: 20),
                          onPressed: () async {
                            await PlacesService.delete(place.id);
                            setSheetState(() {});
                            setState(() {});
                          },
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          setState(() {
                            _point = LatLng(place.latitude, place.longitude);
                          });
                          _mapController.move(_point, 15);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final savedCount = PlacesService.getAll().length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Escolher Local'),
        actions: [
          if (savedCount > 0)
            IconButton(
              icon: Badge(
                label: Text('$savedCount'),
                child: const Icon(Icons.bookmark_outline),
              ),
              tooltip: 'Locais guardados',
              onPressed: _showSavedPlaces,
            ),
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
                    child:
                        CircularProgressIndicator(color: AppTheme.accent))
                : FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _point,
                      initialZoom: 15,
                      onTap: (_, point) =>
                          setState(() => _point = point),
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
                    const Icon(Icons.radar,
                        color: AppTheme.accent, size: 18),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Toque no mapa para definir o ponto',
                        style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.accent,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        side: const BorderSide(
                            color: AppTheme.accent, width: 1),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      icon: const Icon(Icons.bookmark_add_outlined,
                          size: 16),
                      label: const Text('Guardar local',
                          style: TextStyle(fontSize: 12)),
                      onPressed: _saveCurrentPlace,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

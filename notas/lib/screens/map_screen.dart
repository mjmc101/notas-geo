import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/note.dart';
import '../models/saved_place.dart';
import '../services/hive_service.dart';
import '../services/places_service.dart';
import '../theme.dart';
import 'note_form_screen.dart';

// Sky blue — distinct from the lime-green note alerts.
const Color _kSavedColor = Color(0xFF64CFFF);

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();

  List<Note> get _locationNotes => HiveService.getAllNotes()
      .where((n) => !n.isDone && !n.isArchived && n.locationAlert != null)
      .toList();

  Future<void> _centerOnMe() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 6),
        ),
      );
      _mapController.move(LatLng(pos.latitude, pos.longitude), 14);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final notes = _locationNotes;
    final places = PlacesService.getAll();
    final hasContent = notes.isNotEmpty || places.isNotEmpty;

    final center = notes.isNotEmpty
        ? LatLng(notes.first.locationAlert!.latitude,
            notes.first.locationAlert!.longitude)
        : places.isNotEmpty
            ? LatLng(places.first.latitude, places.first.longitude)
            : const LatLng(38.7169, -9.1399);

    final noteCircles = notes
        .map((n) => CircleMarker(
              point: LatLng(
                  n.locationAlert!.latitude, n.locationAlert!.longitude),
              radius: n.locationAlert!.radiusMeters,
              useRadiusInMeter: true,
              color: const Color(0x1AC8F060),
              borderColor: const Color(0x80C8F060),
              borderStrokeWidth: 1.5,
            ))
        .toList();

    final noteMarkers = notes
        .map((n) => Marker(
              point: LatLng(
                  n.locationAlert!.latitude, n.locationAlert!.longitude),
              width: 44,
              height: 44,
              child: Semantics(
                label: 'Nota: ${n.title}',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showNoteInfo(n);
                  },
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.location_pin,
                        color: AppTheme.accent, size: 32),
                  ),
                ),
              ),
            ))
        .toList();

    final placeMarkers = places
        .map((p) => Marker(
              point: LatLng(p.latitude, p.longitude),
              width: 38,
              height: 38,
              child: Semantics(
                label: 'Local guardado: ${p.name}',
                button: true,
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    _showPlaceInfo(p);
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: _kSavedColor,
                      shape: BoxShape.circle,
                      border:
                          Border.all(color: AppTheme.background, width: 2),
                    ),
                    child: const Icon(Icons.bookmark,
                        color: AppTheme.background, size: 18),
                  ),
                ),
              ),
            ))
        .toList();

    final titleParts = [
      if (notes.isNotEmpty)
        '${notes.length} aviso${notes.length != 1 ? 's' : ''}',
      if (places.isNotEmpty)
        '${places.length} guardado${places.length != 1 ? 's' : ''}',
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(
            titleParts.isNotEmpty ? titleParts.join('  •  ') : 'Mapa'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnMe,
            tooltip: 'A minha posição',
          ),
        ],
      ),
      body: !hasContent
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined,
                      size: 72, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Nenhuma nota com localização activa',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Adicione uma nota com aviso GPS ou\nguarde um local no mapa para ver aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options:
                      MapOptions(initialCenter: center, initialZoom: 12),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.notasgeo.notas',
                      maxZoom: 19,
                    ),
                    CircleLayer(circles: noteCircles),
                    MarkerLayer(
                        markers: [...noteMarkers, ...placeMarkers]),
                  ],
                ),
                if (notes.isNotEmpty && places.isNotEmpty)
                  const Positioned(
                    bottom: 12,
                    left: 12,
                    child: _MapLegend(),
                  ),
              ],
            ),
    );
  }

  String _fmtWindow(LocationAlert loc) {
    String pad(int n) => n.toString().padLeft(2, '0');
    final sh = loc.timeWindowStartMinutes! ~/ 60;
    final sm = loc.timeWindowStartMinutes! % 60;
    final eh = loc.timeWindowEndMinutes! ~/ 60;
    final em = loc.timeWindowEndMinutes! % 60;
    return '${pad(sh)}:${pad(sm)}–${pad(eh)}:${pad(em)}';
  }

  void _showNoteInfo(Note note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit, color: AppTheme.accent),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => NoteFormScreen(note: note)),
                    ).then((_) => setState(() {}));
                  },
                ),
              ],
            ),
            if (note.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(note.description,
                  style:
                      const TextStyle(color: AppTheme.textSecondary)),
            ],
            const SizedBox(height: 8),
            if (note.locationAlert?.locationName != null) ...[
              Row(children: [
                const Icon(Icons.place,
                    color: AppTheme.textSecondary, size: 15),
                const SizedBox(width: 4),
                Text(note.locationAlert!.locationName!,
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ]),
              const SizedBox(height: 4),
            ],
            Row(children: [
              const Icon(Icons.radar,
                  color: AppTheme.textSecondary, size: 15),
              const SizedBox(width: 4),
              Text(
                  'Raio: ${note.locationAlert!.radiusMeters.toInt()} m',
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 13)),
              if (note.locationAlert!.hasTimeWindow) ...[
                const SizedBox(width: 12),
                const Icon(Icons.schedule,
                    color: AppTheme.accent, size: 15),
                const SizedBox(width: 4),
                Text(
                  _fmtWindow(note.locationAlert!),
                  style: const TextStyle(
                      color: AppTheme.accent, fontSize: 13),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  void _showPlaceInfo(SavedPlace place) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.bookmark, color: _kSavedColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    place.name,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppTheme.error),
                  tooltip: 'Eliminar local guardado',
                  onPressed: () async {
                    await PlacesService.delete(place.id);
                    if (mounted) {
                      Navigator.pop(context);
                      setState(() {});
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.pin_drop,
                  color: AppTheme.textSecondary, size: 15),
              const SizedBox(width: 4),
              Text(
                '${place.latitude.toStringAsFixed(5)}, '
                '${place.longitude.toStringAsFixed(5)}',
                style: const TextStyle(
                    color: AppTheme.textSecondary, fontSize: 13),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.cardBorder),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LegendDot(color: AppTheme.accent),
          SizedBox(width: 5),
          Text('Avisos',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
          SizedBox(width: 10),
          _LegendDot(color: _kSavedColor),
          SizedBox(width: 5),
          Text('Guardados',
              style: TextStyle(
                  color: AppTheme.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

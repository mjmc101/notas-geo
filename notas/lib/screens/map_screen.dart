import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/note.dart';
import '../services/hive_service.dart';
import '../theme.dart';
import 'note_form_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();

  List<Note> get _locationNotes => HiveService.getAllNotes()
      .where((n) => !n.isDone && n.locationAlert != null)
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

    final markers = notes
        .map((n) => Marker(
              point: LatLng(
                  n.locationAlert!.latitude, n.locationAlert!.longitude),
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => _showInfo(n),
                child: const DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.location_pin,
                      color: AppTheme.accent, size: 32),
                ),
              ),
            ))
        .toList();

    final circles = notes
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

    final center = notes.isNotEmpty
        ? LatLng(notes.first.locationAlert!.latitude,
            notes.first.locationAlert!.longitude)
        : const LatLng(38.7169, -9.1399);

    return Scaffold(
      appBar: AppBar(
        title: Text('Mapa  •  ${notes.length} local${notes.length != 1 ? 'is' : ''}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _centerOnMe,
            tooltip: 'A minha posição',
          ),
        ],
      ),
      body: notes.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.map_outlined,
                      size: 72, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  const Text(
                    'Nenhuma nota com localização activa',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Adicione uma nota com aviso GPS para\nver os locais aqui.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            )
          : FlutterMap(
              mapController: _mapController,
              options: MapOptions(initialCenter: center, initialZoom: 12),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.notasgeo.notas',
                  maxZoom: 19,
                ),
                CircleLayer(circles: circles),
                MarkerLayer(markers: markers),
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

  void _showInfo(Note note) {
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
                  style: const TextStyle(color: AppTheme.textSecondary)),
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
              Text('Raio: ${note.locationAlert!.radiusMeters.toInt()} m',
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
}

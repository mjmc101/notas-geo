import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../services/backup_service.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';
import '../services/places_service.dart';
import '../theme.dart';

/// Settings / data-management screen: backup export & import, location
/// monitoring status and an about section.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const String _appVersion = '1.1.0';

  bool _busy = false;

  int get _noteCount => HiveService.getAllNotes().length;
  int get _placeCount => PlacesService.getAll().length;

  // ── Export ──────────────────────────────────────────────────────────────────

  Future<void> _export() async {
    setState(() => _busy = true);
    try {
      final json = BackupService.encode(
        HiveService.getAllNotes(),
        PlacesService.getAll(),
      );

      // Copy to clipboard so it can be pasted anywhere immediately.
      await Clipboard.setData(ClipboardData(text: json));

      // Also drop a timestamped file in the app's documents directory.
      String? path;
      try {
        final dir = await getApplicationDocumentsDirectory();
        final stamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
        final file = File('${dir.path}/notas_backup_$stamp.json');
        await file.writeAsString(json);
        path = file.path;
      } catch (_) {
        // File system unavailable (e.g. on some desktop targets) — clipboard
        // copy already succeeded, so this is non-fatal.
      }

      if (!mounted) return;
      _showInfoDialog(
        title: 'Backup criado',
        message: path == null
            ? 'Copiado para a área de transferência '
                '($_noteCount nota(s), $_placeCount local(is)).'
            : 'Copiado para a área de transferência e guardado em:\n\n$path',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Import ──────────────────────────────────────────────────────────────────

  Future<void> _import() async {
    final ctrl = TextEditingController();
    final json = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restaurar backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Cole aqui o conteúdo de um backup (JSON). As notas e locais '
              'são adicionados ou actualizados pelo id.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              maxLines: 6,
              style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{ "notes": [ ... ], "places": [ ... ] }',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              final data = await Clipboard.getData(Clipboard.kTextPlain);
              if (data?.text != null) ctrl.text = data!.text!;
            },
            child: const Text('Colar', style: TextStyle(color: AppTheme.accent)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Restaurar',
                style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );

    if (json == null || json.trim().isEmpty) return;

    setState(() => _busy = true);
    try {
      final data = BackupService.decode(json);

      for (final note in data.notes) {
        await HiveService.saveNote(note);
        // Re-arm any active alerts on the restored notes.
        if (!note.isDone && !note.isArchived) {
          if (note.timeAlert != null) {
            await NotificationService.scheduleTimeAlert(note);
          }
          if (note.locationAlert != null) {
            await LocationService.instance.startMonitoring();
          }
        }
      }
      for (final place in data.places) {
        await PlacesService.save(place);
      }

      if (!mounted) return;
      setState(() {});
      _showInfoDialog(
        title: 'Backup restaurado',
        message:
            '${data.notes.length} nota(s) e ${data.places.length} local(is) '
            'importados com sucesso.',
      );
    } on FormatException catch (e) {
      if (mounted) {
        _showInfoDialog(title: 'Backup inválido', message: e.message);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Location permissions ─────────────────────────────────────────────────────

  Future<void> _enableMonitoring() async {
    setState(() => _busy = true);
    try {
      final granted = await LocationService.instance.requestPermissions();
      if (granted) {
        await LocationService.instance.startMonitoring();
      }
      if (!mounted) return;
      _showSnack(granted
          ? 'Monitorização de localização activada.'
          : 'Permissão de localização recusada.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  void _showInfoDialog({required String title, required String message}) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(message,
              style: const TextStyle(color: AppTheme.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppTheme.accent)),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final monitoring = LocationService.instance.isRunning;
    return Scaffold(
      appBar: AppBar(title: const Text('Definições')),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              _SectionHeader('Dados'),
              _Tile(
                icon: Icons.upload_file,
                title: 'Exportar backup',
                subtitle:
                    '$_noteCount nota(s) · $_placeCount local(is) → ficheiro + área de transferência',
                onTap: _busy ? null : _export,
              ),
              _Tile(
                icon: Icons.download,
                title: 'Restaurar backup',
                subtitle: 'Importar de um JSON (cola ou área de transferência)',
                onTap: _busy ? null : _import,
              ),
              const SizedBox(height: 20),
              _SectionHeader('Localização'),
              _Tile(
                icon: monitoring ? Icons.gps_fixed : Icons.gps_off,
                title: monitoring
                    ? 'Monitorização activa'
                    : 'Activar monitorização',
                subtitle: monitoring
                    ? 'A vigiar os avisos por localização em segundo plano'
                    : 'Pedir permissão e começar a vigiar os avisos por GPS',
                onTap: _busy ? null : _enableMonitoring,
              ),
              const SizedBox(height: 20),
              _SectionHeader('Sobre'),
              const _Tile(
                icon: Icons.info_outline,
                title: 'Notas & Avisos',
                subtitle: 'Lembretes por hora e por localização · versão $_appVersion',
              ),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x66000000),
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.accent),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 0, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _Tile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.accent),
        title: Text(title,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
        trailing: onTap == null
            ? null
            : const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}

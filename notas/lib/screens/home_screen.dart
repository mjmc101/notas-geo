import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import '../services/hive_service.dart';
import '../services/location_service.dart';
import '../services/note_filter.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/note_card.dart';
import 'note_form_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: switch (_tab) {
        0 => const _NotesList(),
        1 => const MapScreen(),
        _ => const _ArchiveList(),
      },
      floatingActionButton: _tab == 0
          ? FloatingActionButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NoteFormScreen()),
                ).then((r) {
                  if (r == true) setState(() {});
                });
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) {
          HapticFeedback.selectionClick();
          setState(() => _tab = i);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes, color: AppTheme.accent),
            label: 'Notas',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map, color: AppTheme.accent),
            label: 'Mapa',
          ),
          NavigationDestination(
            icon: Icon(Icons.archive_outlined),
            selectedIcon: Icon(Icons.archive, color: AppTheme.accent),
            label: 'Arquivo',
          ),
        ],
      ),
    );
  }
}

// ── Shared note actions (with undo) ──────────────────────────────────────────

/// Re-creates a detached copy of [note] so it can be safely re-inserted into
/// Hive after a delete (the original HiveObject is removed from its box).
Note _cloneNote(Note note) => Note(
      id: note.id,
      title: note.title,
      description: note.description,
      isDone: note.isDone,
      isArchived: note.isArchived,
      createdAt: note.createdAt,
      timeAlert: note.timeAlert == null
          ? null
          : TimeAlert(
              dateTime: note.timeAlert!.dateTime,
              isRecurring: note.timeAlert!.isRecurring,
              recurringType: note.timeAlert!.recurringType,
            ),
      locationAlert: note.locationAlert == null
          ? null
          : LocationAlert(
              latitude: note.locationAlert!.latitude,
              longitude: note.locationAlert!.longitude,
              radiusMeters: note.locationAlert!.radiusMeters,
              locationName: note.locationAlert!.locationName,
              triggered: note.locationAlert!.triggered,
              timeWindowStartMinutes: note.locationAlert!.timeWindowStartMinutes,
              timeWindowEndMinutes: note.locationAlert!.timeWindowEndMinutes,
              dateRangeStart: note.locationAlert!.dateRangeStart,
              dateRangeEnd: note.locationAlert!.dateRangeEnd,
            ),
    );

/// Re-arms notifications / location monitoring for a restored, active note.
Future<void> _rearmAlerts(Note note) async {
  if (note.isDone || note.isArchived) return;
  if (note.timeAlert != null) {
    await NotificationService.scheduleTimeAlert(note);
  }
  if (note.locationAlert != null) {
    LocationService.instance.resetTrigger(note.id);
    await LocationService.instance.startMonitoring();
  }
}

void _showUndoSnack(
  BuildContext context,
  String message,
  Future<void> Function() onUndo,
) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'Anular',
          textColor: AppTheme.accent,
          onPressed: () => onUndo(),
        ),
      ),
    );
}

Future<void> _confirmDelete(BuildContext context, Note note) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Apagar nota'),
      content: Text('Quer apagar "${note.title}"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar',
              style: TextStyle(color: AppTheme.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child:
              const Text('Apagar', style: TextStyle(color: AppTheme.error)),
        ),
      ],
    ),
  );
  if (ok != true) return;

  final snapshot = _cloneNote(note);
  await NotificationService.cancelNoteNotifications(note.id);
  await HiveService.deleteNote(note.id);

  if (context.mounted) {
    _showUndoSnack(context, 'Nota apagada', () async {
      final restored = _cloneNote(snapshot);
      await HiveService.saveNote(restored);
      await _rearmAlerts(restored);
    });
  }
}

// ── Notes tab ────────────────────────────────────────────────────────────────

class _NotesList extends StatefulWidget {
  const _NotesList();

  @override
  State<_NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<_NotesList> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  NoteListFilter _filter = NoteListFilter.all;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas & Avisos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Definições',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ).then((_) => setState(() {})),
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<Note>>(
        valueListenable: HiveService.getNotesBox().listenable(),
        builder: (_, box, _) {
          final all = box.values.where((n) => !n.isArchived).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          // No notes at all → original empty state (and no search UI).
          if (all.isEmpty) {
            return const _EmptyState(
              icon: Icons.note_add_outlined,
              message: 'Ainda não há notas\nToque em + para criar',
            );
          }

          final shown = applyNoteFilter(all, _filter, _query);

          return Column(
            children: [
              _SearchField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
              ),
              _FilterChips(
                selected: _filter,
                onSelected: (f) => setState(() => _filter = f),
              ),
              Expanded(
                child: shown.isEmpty
                    ? const _EmptyState(
                        icon: Icons.search_off,
                        message: 'Sem resultados',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        itemCount: shown.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) {
                          final note = shown[i];
                          return NoteCard(
                            note: note,
                            onToggleDone: () async {
                              note.isDone = !note.isDone;
                              await note.save();
                              if (note.isDone) {
                                await NotificationService
                                    .cancelNoteNotifications(note.id);
                              } else {
                                await _rearmAlerts(note);
                              }
                            },
                            onArchive: () => _archive(ctx, note),
                            onEdit: () => Navigator.push(
                              ctx,
                              MaterialPageRoute(
                                  builder: (_) => NoteFormScreen(note: note)),
                            ),
                            onDelete: () => _confirmDelete(ctx, note),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _archive(BuildContext context, Note note) async {
    note.isArchived = true;
    await note.save();
    await NotificationService.cancelNoteNotifications(note.id);
    if (context.mounted) {
      _showUndoSnack(context, 'Nota arquivada', () async {
        note.isArchived = false;
        await note.save();
        await _rearmAlerts(note);
      });
    }
  }
}

// ── Arquivo tab ──────────────────────────────────────────────────────────────

class _ArchiveList extends StatefulWidget {
  const _ArchiveList();

  @override
  State<_ArchiveList> createState() => _ArchiveListState();
}

class _ArchiveListState extends State<_ArchiveList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Arquivo')),
      body: ValueListenableBuilder<Box<Note>>(
        valueListenable: HiveService.getNotesBox().listenable(),
        builder: (_, box, _) {
          final archived = box.values.where((n) => n.isArchived).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (archived.isEmpty) {
            return const _EmptyState(
              icon: Icons.archive_outlined,
              message: 'Arquivo vazio',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            itemCount: archived.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (ctx, i) {
              final note = archived[i];
              return NoteCard(
                note: note,
                onToggleDone: () async {
                  note.isDone = !note.isDone;
                  await note.save();
                },
                onUnarchive: () => _unarchive(ctx, note),
                onEdit: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => NoteFormScreen(note: note)),
                ),
                onDelete: () => _confirmDelete(ctx, note),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _unarchive(BuildContext context, Note note) async {
    note.isArchived = false;
    await note.save();
    await _rearmAlerts(note);
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Nota desarquivada')));
    }
  }
}

// ── Shared list widgets ──────────────────────────────────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          isDense: true,
          hintText: 'Procurar notas…',
          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.clear, color: AppTheme.textSecondary),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  final NoteListFilter selected;
  final ValueChanged<NoteListFilter> onSelected;

  const _FilterChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          for (final f in NoteListFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(f.label),
                selected: selected == f,
                showCheckmark: false,
                labelStyle: TextStyle(
                  color: selected == f
                      ? AppTheme.background
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                selectedColor: AppTheme.accent,
                backgroundColor: AppTheme.surface,
                side: BorderSide(
                  color: selected == f ? AppTheme.accent : AppTheme.cardBorder,
                ),
                onSelected: (_) => onSelected(f),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;

  const _EmptyState({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: AppTheme.textSecondary),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

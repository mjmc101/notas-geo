import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import '../services/hive_service.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/note_card.dart';
import 'note_form_screen.dart';
import 'map_screen.dart';

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

class _NotesList extends StatefulWidget {
  const _NotesList();

  @override
  State<_NotesList> createState() => _NotesListState();
}

class _NotesListState extends State<_NotesList> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notas & Avisos'),
      ),
      body: ValueListenableBuilder<Box<Note>>(
        valueListenable: HiveService.getNotesBox().listenable(),
        builder: (_, box, _) {
          final all = box.values.toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          final shown = all.where((n) => !n.isArchived).toList();

          if (shown.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.note_add_outlined,
                    size: 72,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Ainda não há notas\nToque em + para criar',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
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
                    await NotificationService.cancelNoteNotifications(note.id);
                  }
                },
                onArchive: () async {
                  note.isArchived = true;
                  await note.save();
                  await NotificationService.cancelNoteNotifications(note.id);
                },
                onEdit: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => NoteFormScreen(note: note)),
                ),
                onDelete: () => _confirmDelete(note),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Note note) async {
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
            child: const Text('Apagar',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NotificationService.cancelNoteNotifications(note.id);
      await HiveService.deleteNote(note.id);
    }
  }
}

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
          final archived = box.values
              .where((n) => n.isArchived)
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (archived.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined,
                      size: 72, color: AppTheme.textSecondary),
                  SizedBox(height: 16),
                  Text(
                    'Arquivo vazio',
                    style: TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16),
                  ),
                ],
              ),
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
                onEdit: () => Navigator.push(
                  ctx,
                  MaterialPageRoute(
                      builder: (_) => NoteFormScreen(note: note)),
                ),
                onDelete: () => _confirmDelete(note),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(Note note) async {
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
            child: const Text('Apagar',
                style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await NotificationService.cancelNoteNotifications(note.id);
      await HiveService.deleteNote(note.id);
    }
  }
}

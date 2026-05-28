// Widget tests for HomeScreen tabs (Notas and Arquivo).
//
// Tests stay on tab 0 (Notas) and tab 2 (Arquivo); tab 1 (Mapa) is skipped
// because MapScreen pulls in geolocator platform channels.
//
// Hive write operations inside testWidgets bodies MUST use tester.runAsync()
// because testWidgets wraps the body in FakeAsync, which suspends the real
// event loop. Hive's async I/O relies on the real event loop to complete.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:notas/models/note.dart';
import 'package:notas/models/saved_place.dart';
import 'package:notas/screens/home_screen.dart';
import 'package:notas/theme.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('hive_home_test_');
    Hive.init(tempDir.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(NoteAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(TimeAlertAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(LocationAlertAdapter());
    if (!Hive.isAdapterRegistered(3)) Hive.registerAdapter(SavedPlaceAdapter());
    await Hive.openBox<Note>('notes');
    await Hive.openBox<SavedPlace>('saved_places');
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  // Clear the notes box before each test so tests are isolated.
  // setUp runs outside FakeAsync so regular await works.
  setUp(() async {
    await Hive.box<Note>('notes').clear();
  });

  Widget buildApp() => MaterialApp(
        theme: AppTheme.dark,
        home: const HomeScreen(),
      );

  // Advances past any NavigationBar selection animations without risking
  // an infinite pumpAndSettle loop from continuous system animations.
  Future<void> pumpAnimation(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  // ── Notas tab (tab 0) ─────────────────────────────────────────────────────

  group('Notas tab', () {
    testWidgets('active note is shown', (tester) async {
      // runAsync: Hive write needs the real event loop (FakeAsync blocks it).
      await tester.runAsync(() async {
        await Hive.box<Note>('notes').put(
            'a1', Note(id: 'a1', title: 'Active Note', description: ''));
      });

      await tester.pumpWidget(buildApp());
      await pumpAnimation(tester);

      expect(find.text('Active Note'), findsOneWidget);
    });

    testWidgets('done note (non-archived) is shown with strikethrough',
        (tester) async {
      await tester.runAsync(() async {
        await Hive.box<Note>('notes').put(
          'd1',
          Note(id: 'd1', title: 'Done Note', description: '', isDone: true),
        );
      });

      await tester.pumpWidget(buildApp());
      await pumpAnimation(tester);

      expect(find.text('Done Note'), findsOneWidget);
      final titleWidget = tester.widget<Text>(find.text('Done Note'));
      expect(titleWidget.style?.decoration, TextDecoration.lineThrough);
    });

    testWidgets('archived note is NOT shown', (tester) async {
      await tester.runAsync(() async {
        await Hive.box<Note>('notes').put(
          'arch1',
          Note(
            id: 'arch1',
            title: 'Archived Note',
            description: '',
            isDone: true,
            isArchived: true,
          ),
        );
      });

      await tester.pumpWidget(buildApp());
      await pumpAnimation(tester);

      expect(find.text('Archived Note'), findsNothing);
    });

    testWidgets('empty state shown when no non-archived notes', (tester) async {
      // Box cleared in setUp — nothing to show.
      await tester.pumpWidget(buildApp());
      await pumpAnimation(tester);

      expect(find.text('Ainda não há notas\nToque em + para criar'),
          findsOneWidget);
    });

    testWidgets('active note visible, archived note hidden simultaneously',
        (tester) async {
      await tester.runAsync(() async {
        final box = Hive.box<Note>('notes');
        await box.put('v', Note(id: 'v', title: 'Visible Note', description: ''));
        await box.put(
          'h',
          Note(
            id: 'h',
            title: 'Hidden Archived',
            description: '',
            isDone: true,
            isArchived: true,
          ),
        );
      });

      await tester.pumpWidget(buildApp());
      await pumpAnimation(tester);

      expect(find.text('Visible Note'), findsOneWidget);
      expect(find.text('Hidden Archived'), findsNothing);
    });
  });

  // ── Arquivo tab (tab 2) ───────────────────────────────────────────────────

  group('Arquivo tab', () {
    Future<void> openArchiveTab(WidgetTester tester) async {
      await tester.pumpWidget(buildApp());
      await pumpAnimation(tester);
      // There is only one 'Arquivo' text on the initial screen: the nav label.
      await tester.tap(find.text('Arquivo'));
      await pumpAnimation(tester);
    }

    testWidgets('archived note is shown', (tester) async {
      await tester.runAsync(() async {
        await Hive.box<Note>('notes').put(
          'arch2',
          Note(
            id: 'arch2',
            title: 'My Archived Note',
            description: '',
            isDone: true,
            isArchived: true,
          ),
        );
      });

      await openArchiveTab(tester);

      expect(find.text('My Archived Note'), findsOneWidget);
    });

    testWidgets('active (non-archived) note is NOT in archive tab',
        (tester) async {
      await tester.runAsync(() async {
        await Hive.box<Note>('notes').put(
            'act', Note(id: 'act', title: 'Active Only', description: ''));
      });

      await openArchiveTab(tester);

      expect(find.text('Active Only'), findsNothing);
    });

    testWidgets('empty state when no archived notes', (tester) async {
      // Box cleared in setUp.
      await openArchiveTab(tester);

      expect(find.text('Arquivo vazio'), findsOneWidget);
    });
  });

  // ── Navigation ────────────────────────────────────────────────────────────

  testWidgets('navigation bar has 3 destinations', (tester) async {
    await tester.pumpWidget(buildApp());
    await pumpAnimation(tester);

    final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navBar.destinations.length, 3);
    expect(find.text('Notas'), findsOneWidget);
    expect(find.text('Mapa'), findsOneWidget);
    expect(find.text('Arquivo'), findsOneWidget);
  });
}

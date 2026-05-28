// Widget tests for NoteCard.
//
// Note extends HiveObject, but the constructor does not interact with Hive,
// so these tests run without any Hive initialisation.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notas/models/note.dart';
import 'package:notas/widgets/note_card.dart';
import 'package:notas/theme.dart';

Widget _buildCard(Note note, {VoidCallback? onArchive}) {
  return MaterialApp(
    theme: AppTheme.dark,
    home: Scaffold(
      body: NoteCard(
        note: note,
        onToggleDone: () {},
        onEdit: () {},
        onDelete: () {},
        onArchive: onArchive,
      ),
    ),
  );
}

void main() {
  group('NoteCard', () {
    test('sanity: Note can be constructed without Hive init', () {
      final note = Note(id: 'x', title: 'T', description: '');
      expect(note.title, 'T');
    });

    testWidgets('active note: title visible, no strikethrough, no archive button',
        (tester) async {
      final note = Note(id: 'a1', title: 'Active Note', description: '');
      await tester.pumpWidget(_buildCard(note));

      final titleWidget =
          tester.widget<Text>(find.text('Active Note'));
      expect(titleWidget.style?.decoration, isNot(TextDecoration.lineThrough));
      expect(find.byIcon(Icons.archive_outlined), findsNothing);
    });

    testWidgets(
        'done note with onArchive: strikethrough + archive button visible',
        (tester) async {
      final note =
          Note(id: 'd1', title: 'Done Note', description: '', isDone: true);
      bool archiveCalled = false;

      await tester.pumpWidget(_buildCard(note, onArchive: () {
        archiveCalled = true;
      }));

      final titleWidget = tester.widget<Text>(find.text('Done Note'));
      expect(titleWidget.style?.decoration, TextDecoration.lineThrough);
      expect(find.byIcon(Icons.archive_outlined), findsOneWidget);

      // Tapping the inline archive button calls the callback.
      await tester.tap(find.byIcon(Icons.archive_outlined).first);
      expect(archiveCalled, isTrue);
    });

    testWidgets('done note without onArchive: no archive button', (tester) async {
      final note =
          Note(id: 'd2', title: 'Done No Archive', description: '', isDone: true);
      await tester.pumpWidget(_buildCard(note));

      expect(find.byIcon(Icons.archive_outlined), findsNothing);
    });

    testWidgets('active note with onArchive: archive button still hidden',
        (tester) async {
      // Archive button only shows when BOTH done AND onArchive provided.
      final note = Note(id: 'a2', title: 'Active Arch', description: '');
      await tester.pumpWidget(_buildCard(note, onArchive: () {}));

      expect(find.byIcon(Icons.archive_outlined), findsNothing);
    });

    testWidgets('time alert: alarm icon chip visible', (tester) async {
      final note = Note(
        id: 't1',
        title: 'Timed',
        description: '',
        timeAlert: TimeAlert(
          dateTime: DateTime(2025, 12, 25, 9),
          isRecurring: false,
        ),
      );
      await tester.pumpWidget(_buildCard(note));

      expect(find.byIcon(Icons.alarm), findsOneWidget);
    });

    testWidgets('recurring time alert: repeat icon chip visible', (tester) async {
      final note = Note(
        id: 't2',
        title: 'Recurring',
        description: '',
        timeAlert: TimeAlert(
          dateTime: DateTime(2025, 12, 25, 9),
          isRecurring: true,
          recurringType: 'weekly',
        ),
      );
      await tester.pumpWidget(_buildCard(note));

      expect(find.byIcon(Icons.repeat), findsOneWidget);
    });

    testWidgets('location alert: location_on icon chip visible', (tester) async {
      final note = Note(
        id: 'l1',
        title: 'Located',
        description: '',
        locationAlert:
            LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100),
      );
      await tester.pumpWidget(_buildCard(note));

      expect(find.byIcon(Icons.location_on), findsOneWidget);
    });

    testWidgets(
        'location alert with time window: link chip visible', (tester) async {
      final note = Note(
        id: 'l2',
        title: 'LocWindow',
        description: '',
        locationAlert: LocationAlert(
          latitude: 0,
          longitude: 0,
          radiusMeters: 100,
          timeWindowStartMinutes: 540,
          timeWindowEndMinutes: 1080,
        ),
      );
      await tester.pumpWidget(_buildCard(note));

      expect(find.byIcon(Icons.link), findsOneWidget);
    });

    testWidgets('location alert without time window: no link chip', (tester) async {
      final note = Note(
        id: 'l3',
        title: 'LocNoWindow',
        description: '',
        locationAlert:
            LocationAlert(latitude: 0, longitude: 0, radiusMeters: 100),
      );
      await tester.pumpWidget(_buildCard(note));

      expect(find.byIcon(Icons.link), findsNothing);
    });
  });
}

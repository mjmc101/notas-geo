// Widget tests for the notes-list search field and filter chips.
//
// Hive writes inside testWidgets bodies use tester.runAsync() (FakeAsync
// suspends the real event loop that Hive's async I/O depends on).
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
    tempDir = await Directory.systemTemp.createTemp('hive_search_test_');
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

  setUp(() async {
    await Hive.box<Note>('notes').clear();
  });

  Widget buildApp() =>
      MaterialApp(theme: AppTheme.dark, home: const HomeScreen());

  Future<void> pumpAnimation(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> seed(WidgetTester tester) async {
    await tester.runAsync(() async {
      final box = Hive.box<Note>('notes');
      await box.put('1',
          Note(id: '1', title: 'Comprar adubo', description: ''));
      await box.put('2',
          Note(id: '2', title: 'Regar estufa', description: ''));
      await box.put(
        '3',
        Note(
          id: '3',
          title: 'Podar macieira',
          description: '',
          isDone: true,
        ),
      );
    });
  }

  testWidgets('search field is shown when notes exist', (tester) async {
    await seed(tester);
    await tester.pumpWidget(buildApp());
    await pumpAnimation(tester);

    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Procurar notas…'), findsOneWidget);
  });

  testWidgets('typing a query filters the visible notes', (tester) async {
    await seed(tester);
    await tester.pumpWidget(buildApp());
    await pumpAnimation(tester);

    expect(find.text('Comprar adubo'), findsOneWidget);
    expect(find.text('Regar estufa'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'regar');
    await pumpAnimation(tester);

    expect(find.text('Regar estufa'), findsOneWidget);
    expect(find.text('Comprar adubo'), findsNothing);
  });

  testWidgets('no-match query shows "Sem resultados"', (tester) async {
    await seed(tester);
    await tester.pumpWidget(buildApp());
    await pumpAnimation(tester);

    await tester.enterText(find.byType(TextField), 'zzzz');
    await pumpAnimation(tester);

    expect(find.text('Sem resultados'), findsOneWidget);
  });

  testWidgets('the "Concluídas" filter chip keeps only done notes',
      (tester) async {
    await seed(tester);
    await tester.pumpWidget(buildApp());
    await pumpAnimation(tester);

    await tester.tap(find.text('Concluídas'));
    await pumpAnimation(tester);

    expect(find.text('Podar macieira'), findsOneWidget);
    expect(find.text('Comprar adubo'), findsNothing);
    expect(find.text('Regar estufa'), findsNothing);
  });
}

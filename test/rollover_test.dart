import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:athkar/data/local/database.dart';
import 'package:athkar/state/athkar_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  testWidgets('prefs counters migrate into sqlite', (tester) async {
    SharedPreferences.setMockInitialValues({
      'athkar.counters':
          '[{"id":"c1","name":"استغفار","count":4,"createdAt":"2026-09-16T10:00:00.000","updatedAt":"2026-09-16T11:00:00.000"}]',
    });
    final store = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: AppDatabase.memory(),
    );
    await store.init();
    expect(store.counters.single.name, 'استغفار');
    expect(store.counters.single.count, 4);
    expect(store.collectionById('morning')!.isDefault, isTrue);
    store.dispose();
  });

  testWidgets('completing a list writes today; reset only changes today', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 9, 16, 21);
    final db = AppDatabase.memory();
    final store = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: db,
      clock: () => now,
    );
    await store.init();
    await store.addCollection(name: 'اختبار');
    final id = store.collections.last.id;
    await store.addItem(collectionId: id, text: 'سبحان الله', repeatCount: 1);
    await store.tickItem(id, store.collectionById(id)!.items.single.id);
    expect(await store.streakFor(id), 1);

    await store.resetCollectionProgress(id);
    expect(store.collectionById(id)!.items.single.progress, 0);
    expect(await store.streakFor(id), 0);
    store.dispose();
  });

  testWidgets('rollover stores yesterday and resets item progress', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    var now = DateTime(2026, 9, 16, 21);
    final db = AppDatabase.memory();
    final first = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: db,
      clock: () => now,
    );
    await first.init();
    await first.addCollection(name: 'اختبار');
    final id = first.collections.last.id;
    await first.addItem(collectionId: id, text: 'سبحان الله', repeatCount: 1);
    await first.tickItem(id, first.collectionById(id)!.items.single.id);
    expect(first.collectionById(id)!.items.single.progress, 1);
    first.dispose();

    now = DateTime(2026, 9, 17, 6);
    final second = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: db,
      clock: () => now,
    );
    await second.init();
    expect(second.collectionById(id)!.items.single.progress, 0);
    expect(await second.streakFor(id), 1);

    await second.tickItem(id, second.collectionById(id)!.items.single.id);
    expect(await second.streakFor(id), 2);
    second.dispose();

    now = DateTime(2026, 9, 18, 6);
    final third = AthkarStore(
      enableForegroundAdhanWatch: false,
      enableCloudSync: false,
      database: db,
      clock: () => now,
    );
    await third.init();
    expect(third.collectionById(id)!.items.single.progress, 0);
    expect(await third.streakFor(id), 2);
    third.dispose();
  });
}

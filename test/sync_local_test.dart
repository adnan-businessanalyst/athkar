import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:athkar/data/local/database.dart';
import 'package:athkar/models/models.dart';
import 'package:athkar/services/local_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('push body and apply response stay consistent', () async {
    final db = AppDatabase.memory();
    final now = DateTime.utc(2026, 9, 17, 12);
    final repo = LocalRepository(db, clock: () => now);
    await repo.saveCounters([
      AthkarCounter(
        id: 'c1',
        name: 'استغفار',
        count: 4,
        createdAt: now,
        updatedAt: now,
      ),
    ]);
    final body = await repo.buildPushBody(includeAll: true);
    expect((body['counters'] as List).single['count'], 4);
    expect(await repo.hasDirty(), isTrue);

    await repo.applySyncResponse({
      'revision': 3,
      'counters': [
        {
          'id': 'c1',
          'name': 'استغفار',
          'count': 7,
          'created_at': '2026-09-17T12:00:00Z',
          'updated_at': '2026-09-17T12:00:00Z',
          'deleted_at': null,
          'revision': 3,
        },
      ],
      'collections': <dynamic>[],
      'items': <dynamic>[],
      'daily_progress': <dynamic>[],
    });
    expect(await repo.serverRevision(), 3);
    expect((await repo.loadCounters()).single.count, 7);
    expect(await repo.hasDirty(), isFalse);
    await db.close();
  });
}

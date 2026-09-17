import 'dart:convert';

import 'package:drift/drift.dart';

import '../data/default_collections.dart';
import '../data/local/database.dart';
import '../models/models.dart';
import 'storage_service.dart';

class LocalRepository {
  LocalRepository(this.db, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final DateTime Function() _clock;

  static const _rolloverKey = 'last_rollover';
  static const _migratedKey = 'prefs_migrated';
  static const _revisionKey = 'server_revision';

  DateTime get _now => _clock();

  DateTime get _today {
    final now = _now;
    return DateTime(now.year, now.month, now.day);
  }

  String _dateKey(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final y = day.year.toString().padLeft(4, '0');
    final m = day.month.toString().padLeft(2, '0');
    final d = day.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  DateTime _parseDate(String value) {
    final parts = value.split('-');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  Future<String?> _meta(String key) async {
    final row = await (db.select(
      db.localMeta,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _setMeta(String key, String value) {
    return db
        .into(db.localMeta)
        .insertOnConflictUpdate(
          LocalMetaCompanion(key: Value(key), value: Value(value)),
        );
  }

  Future<void> migrateFromPrefsIfNeeded(StorageService storage) async {
    if (await _meta(_migratedKey) == '1') return;
    final counters = storage.loadCounters();
    final collections = storage.loadCollections();
    final location = storage.loadLocation();
    final settings = storage.loadSettings();
    final hasLegacy =
        counters.isNotEmpty ||
        storage.hasLegacyCollections ||
        location != null ||
        storage.hasLegacySettings;
    if (hasLegacy) {
      await saveCounters(counters);
      await saveCollections(collections);
      if (location != null) await saveLocation(location);
      await saveSettings(settings);
    }
    await _setMeta(_migratedKey, '1');
  }

  Future<void> ensureDefaults() async {
    final existing = await loadCollections();
    if (existing.isEmpty) {
      await saveCollections(DefaultCollections.seed());
      return;
    }
    final merged = DefaultCollections.mergeMissing(existing);
    if (merged.length != existing.length) {
      await saveCollections(merged);
    }
  }

  Future<void> rolloverIfNeeded() async {
    final today = _today;
    final todayKey = _dateKey(today);
    final last = await _meta(_rolloverKey);
    if (last == null) {
      await _setMeta(_rolloverKey, todayKey);
      return;
    }
    if (last == todayKey) return;

    final yesterday = today.subtract(const Duration(days: 1));
    final collections = await loadCollections();
    for (final collection in collections) {
      await upsertDailyProgress(collection, date: yesterday);
      final resetItems = [
        for (final item in collection.items)
          item.copyWith(progress: 0, updatedAt: _now),
      ];
      await _upsertCollection(
        collection.copyWith(items: resetItems, updatedAt: _now),
      );
    }
    await _setMeta(_rolloverKey, todayKey);
  }

  Future<List<AthkarCounter>> loadCounters() async {
    final rows = await (db.select(
      db.counters,
    )..where((t) => t.deletedAt.isNull())).get();
    rows.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return [
      for (final row in rows)
        AthkarCounter(
          id: row.id,
          name: row.name,
          count: row.count,
          createdAt: row.createdAt,
          updatedAt: row.updatedAt,
        ),
    ];
  }

  Future<void> saveCounters(List<AthkarCounter> counters) async {
    final seen = {for (final counter in counters) counter.id};
    for (final counter in counters) {
      await db
          .into(db.counters)
          .insertOnConflictUpdate(
            CountersCompanion(
              id: Value(counter.id),
              name: Value(counter.name),
              count: Value(counter.count),
              createdAt: Value(counter.createdAt),
              updatedAt: Value(counter.updatedAt),
              deletedAt: const Value(null),
              dirty: const Value(true),
            ),
          );
    }
    final existing = await db.select(db.counters).get();
    for (final row in existing) {
      if (!seen.contains(row.id) && row.deletedAt == null) {
        await (db.update(
          db.counters,
        )..where((t) => t.id.equals(row.id))).write(
          CountersCompanion(
            deletedAt: Value(_now),
            updatedAt: Value(_now),
            dirty: const Value(true),
          ),
        );
      }
    }
  }

  Future<List<AthkarCollection>> loadCollections() async {
    final collectionRows = await (db.select(
      db.collections,
    )..where((t) => t.deletedAt.isNull())).get();
    final itemRows = await (db.select(
      db.collectionItems,
    )..where((t) => t.deletedAt.isNull())).get();
    final itemsByCollection = <String, List<AthkarItem>>{};
    for (final row in itemRows) {
      itemsByCollection
          .putIfAbsent(row.collectionId, () => [])
          .add(
            AthkarItem(
              id: row.id,
              text: row.itemText,
              repeatCount: row.repeatCount,
              progress: row.progress,
              sortOrder: row.sortOrder,
              updatedAt: row.updatedAt,
            ),
          );
    }
    for (final items in itemsByCollection.values) {
      items.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    }
    final loaded = [
      for (final row in collectionRows)
        AthkarCollection(
          id: row.id,
          name: row.name,
          description: row.description,
          isDefault: row.isDefault,
          isFavorite: row.isFavorite,
          updatedAt: row.updatedAt,
          reminder: AthkarReminder(
            enabled: row.reminderEnabled,
            hour: row.reminderHour ?? 6,
            minute: row.reminderMinute ?? 0,
          ),
          items: itemsByCollection[row.id] ?? const [],
        ),
    ];
    return DefaultCollections.mergeMissing(loaded);
  }

  Future<void> saveCollections(List<AthkarCollection> collections) async {
    final seenCollections = <String>{};
    final seenItems = <String>{};
    for (final collection in collections) {
      seenCollections.add(collection.id);
      await _upsertCollection(collection);
      for (final item in collection.items) {
        seenItems.add(item.id);
      }
    }
    final existingCollections = await db.select(db.collections).get();
    for (final row in existingCollections) {
      if (!seenCollections.contains(row.id) && row.deletedAt == null) {
        await (db.update(
          db.collections,
        )..where((t) => t.id.equals(row.id))).write(
          CollectionsCompanion(
            deletedAt: Value(_now),
            updatedAt: Value(_now),
            dirty: const Value(true),
          ),
        );
      }
    }
    final existingItems = await db.select(db.collectionItems).get();
    for (final row in existingItems) {
      if (!seenItems.contains(row.id) && row.deletedAt == null) {
        await (db.update(
          db.collectionItems,
        )..where((t) => t.id.equals(row.id))).write(
          CollectionItemsCompanion(
            deletedAt: Value(_now),
            updatedAt: Value(_now),
            dirty: const Value(true),
          ),
        );
      }
    }
  }

  Future<void> _upsertCollection(AthkarCollection collection) async {
    final updatedAt = collection.updatedAt ?? _now;
    await db
        .into(db.collections)
        .insertOnConflictUpdate(
          CollectionsCompanion(
            id: Value(collection.id),
            name: Value(collection.name),
            description: Value(collection.description),
            isDefault: Value(collection.isDefault),
            isFavorite: Value(collection.isFavorite),
            reminderEnabled: Value(collection.reminder?.enabled ?? false),
            reminderHour: Value(collection.reminder?.hour),
            reminderMinute: Value(collection.reminder?.minute),
            updatedAt: Value(updatedAt),
            deletedAt: const Value(null),
            dirty: const Value(true),
          ),
        );
    for (var index = 0; index < collection.items.length; index++) {
      final item = collection.items[index];
      await db
          .into(db.collectionItems)
          .insertOnConflictUpdate(
            CollectionItemsCompanion(
              id: Value(item.id),
              collectionId: Value(collection.id),
              itemText: Value(item.text),
              repeatCount: Value(item.repeatCount),
              progress: Value(item.progress),
              sortOrder: Value(item.sortOrder != 0 ? item.sortOrder : index),
              updatedAt: Value(item.updatedAt ?? updatedAt),
              deletedAt: const Value(null),
              dirty: const Value(true),
            ),
          );
    }
  }

  Future<SavedLocation?> loadLocation() async {
    final row = await (db.select(
      db.locations,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row == null) return null;
    return SavedLocation(
      latitude: row.latitude,
      longitude: row.longitude,
      label: row.label,
      source: LocationSource.values.firstWhere(
        (value) => value.name == row.source,
        orElse: () => LocationSource.custom,
      ),
      city: row.city,
      country: row.country,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> saveLocation(SavedLocation location) {
    final updatedAt = location.updatedAt ?? _now;
    return db
        .into(db.locations)
        .insertOnConflictUpdate(
          LocationsCompanion(
            id: const Value(1),
            latitude: Value(location.latitude),
            longitude: Value(location.longitude),
            label: Value(location.label),
            source: Value(location.source.name),
            city: Value(location.city),
            country: Value(location.country),
            updatedAt: Value(updatedAt),
            dirty: const Value(true),
          ),
        );
  }

  Future<AppSettings> loadSettings() async {
    final row = await (db.select(
      db.settingsRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (row == null) return const AppSettings();
    final muted = (jsonDecode(row.mutedPrayers) as List<dynamic>)
        .map((item) => item as String)
        .toSet();
    return AppSettings(
      adhanEnabled: row.adhanEnabled,
      mutedPrayers: muted,
      calculationMethod: row.calculationMethod,
      madhab: row.madhab,
      updatedAt: row.updatedAt,
    );
  }

  Future<void> saveSettings(AppSettings settings) {
    return db
        .into(db.settingsRows)
        .insertOnConflictUpdate(
          SettingsRowsCompanion(
            id: const Value(1),
            adhanEnabled: Value(settings.adhanEnabled),
            mutedPrayers: Value(jsonEncode(settings.mutedPrayers.toList())),
            calculationMethod: Value(settings.calculationMethod),
            madhab: Value(settings.madhab),
            updatedAt: Value(settings.updatedAt ?? _now),
            dirty: const Value(true),
          ),
        );
  }

  Future<void> upsertDailyProgress(
    AthkarCollection collection, {
    required DateTime date,
    bool? completed,
  }) {
    final items = collection.items;
    final done = items.where((item) => item.isDone).length;
    final isComplete = completed ?? (items.isNotEmpty && done == items.length);
    return db
        .into(db.dailyProgressRows)
        .insertOnConflictUpdate(
          DailyProgressRowsCompanion(
            collectionId: Value(collection.id),
            date: Value(_dateKey(date)),
            completed: Value(isComplete),
            completedAt: Value(isComplete ? _now : null),
            itemsDone: Value(done),
            itemsTotal: Value(items.length),
            updatedAt: Value(_now),
            deletedAt: const Value(null),
            dirty: const Value(true),
          ),
        );
  }

  Future<List<DailyProgress>> loadProgress() async {
    final rows = await (db.select(
      db.dailyProgressRows,
    )..where((t) => t.deletedAt.isNull())).get();
    return [
      for (final row in rows)
        DailyProgress(
          collectionId: row.collectionId,
          date: _parseDate(row.date),
          completed: row.completed,
          completedAt: row.completedAt,
          itemsDone: row.itemsDone,
          itemsTotal: row.itemsTotal,
          updatedAt: row.updatedAt,
        ),
    ];
  }

  Future<int> serverRevision() async {
    return int.tryParse(await _meta(_revisionKey) ?? '') ?? 0;
  }

  Future<void> setServerRevision(int value) {
    return _setMeta(_revisionKey, '$value');
  }

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  DateTime _parseDt(Object? value, DateTime fallback) {
    if (value is String && value.isNotEmpty) {
      return DateTime.tryParse(value) ?? fallback;
    }
    return fallback;
  }

  Future<bool> hasDirty() async {
    final dirtyCounters = await (db.select(
      db.counters,
    )..where((t) => t.dirty.equals(true))).get();
    if (dirtyCounters.isNotEmpty) return true;
    final dirtyCollections = await (db.select(
      db.collections,
    )..where((t) => t.dirty.equals(true))).get();
    if (dirtyCollections.isNotEmpty) return true;
    final dirtyItems = await (db.select(
      db.collectionItems,
    )..where((t) => t.dirty.equals(true))).get();
    if (dirtyItems.isNotEmpty) return true;
    final dirtyProgress = await (db.select(
      db.dailyProgressRows,
    )..where((t) => t.dirty.equals(true))).get();
    if (dirtyProgress.isNotEmpty) return true;
    final location = await (db.select(
      db.locations,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (location?.dirty == true) return true;
    final settings = await (db.select(
      db.settingsRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    return settings?.dirty == true;
  }

  Future<Map<String, dynamic>> buildPushBody({required bool includeAll}) async {
    final since = await serverRevision();
    final body = <String, dynamic>{'since': since};

    final location = await (db.select(
      db.locations,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (location != null && (includeAll || location.dirty)) {
      body['location'] = {
        'latitude': location.latitude,
        'longitude': location.longitude,
        'label': location.label,
        'source': location.source,
        'city': location.city,
        'country': location.country,
        'updated_at': _iso(location.updatedAt),
        'revision': location.revision,
      };
    }

    final settings = await (db.select(
      db.settingsRows,
    )..where((t) => t.id.equals(1))).getSingleOrNull();
    if (settings != null && (includeAll || settings.dirty)) {
      body['settings'] = {
        'adhan_enabled': settings.adhanEnabled,
        'muted_prayers': jsonDecode(settings.mutedPrayers),
        'calculation_method': settings.calculationMethod,
        'madhab': settings.madhab,
        'updated_at': _iso(settings.updatedAt),
        'revision': settings.revision,
      };
    }

    final counters = await db.select(db.counters).get();
    body['counters'] = [
      for (final row in counters)
        if (includeAll || row.dirty)
          {
            'id': row.id,
            'name': row.name,
            'count': row.count,
            'created_at': _iso(row.createdAt),
            'updated_at': _iso(row.updatedAt),
            'deleted_at': row.deletedAt == null ? null : _iso(row.deletedAt!),
            'revision': row.revision,
          },
    ];

    final collections = await db.select(db.collections).get();
    body['collections'] = [
      for (final row in collections)
        if (includeAll || row.dirty)
          {
            'id': row.id,
            'name': row.name,
            'description': row.description,
            'is_default': row.isDefault,
            'is_favorite': row.isFavorite,
            'reminder_enabled': row.reminderEnabled,
            'reminder_hour': row.reminderHour,
            'reminder_minute': row.reminderMinute,
            'updated_at': _iso(row.updatedAt),
            'deleted_at': row.deletedAt == null ? null : _iso(row.deletedAt!),
            'revision': row.revision,
          },
    ];

    final items = await db.select(db.collectionItems).get();
    body['items'] = [
      for (final row in items)
        if (includeAll || row.dirty)
          {
            'id': row.id,
            'collection_id': row.collectionId,
            'text': row.itemText,
            'repeat_count': row.repeatCount,
            'progress': row.progress,
            'sort_order': row.sortOrder,
            'updated_at': _iso(row.updatedAt),
            'deleted_at': row.deletedAt == null ? null : _iso(row.deletedAt!),
            'revision': row.revision,
          },
    ];

    final progress = await db.select(db.dailyProgressRows).get();
    body['daily_progress'] = [
      for (final row in progress)
        if (includeAll || row.dirty)
          {
            'collection_id': row.collectionId,
            'date': row.date,
            'completed': row.completed,
            'completed_at': row.completedAt == null
                ? null
                : _iso(row.completedAt!),
            'items_done': row.itemsDone,
            'items_total': row.itemsTotal,
            'updated_at': _iso(row.updatedAt),
            'deleted_at': row.deletedAt == null ? null : _iso(row.deletedAt!),
            'revision': row.revision,
          },
    ];
    return body;
  }

  Future<void> applySyncResponse(Map<String, dynamic> data) async {
    final revision = data['revision'] as int? ?? await serverRevision();
    final now = _now;

    final location = data['location'];
    if (location is Map<String, dynamic>) {
      await db
          .into(db.locations)
          .insertOnConflictUpdate(
            LocationsCompanion(
              id: const Value(1),
              latitude: Value((location['latitude'] as num).toDouble()),
              longitude: Value((location['longitude'] as num).toDouble()),
              label: Value(location['label'] as String? ?? ''),
              source: Value(location['source'] as String? ?? 'custom'),
              city: Value(location['city'] as String?),
              country: Value(location['country'] as String?),
              updatedAt: Value(_parseDt(location['updated_at'], now)),
              revision: Value(location['revision'] as int? ?? revision),
              dirty: const Value(false),
            ),
          );
    }

    final settings = data['settings'];
    if (settings is Map<String, dynamic>) {
      await db
          .into(db.settingsRows)
          .insertOnConflictUpdate(
            SettingsRowsCompanion(
              id: const Value(1),
              adhanEnabled: Value(settings['adhan_enabled'] as bool? ?? true),
              mutedPrayers: Value(
                jsonEncode(settings['muted_prayers'] as List<dynamic>? ?? []),
              ),
              calculationMethod: Value(
                settings['calculation_method'] as String? ?? 'umm_al_qura',
              ),
              madhab: Value(settings['madhab'] as String? ?? 'shafi'),
              updatedAt: Value(_parseDt(settings['updated_at'], now)),
              revision: Value(settings['revision'] as int? ?? revision),
              dirty: const Value(false),
            ),
          );
    }

    for (final raw in data['counters'] as List<dynamic>? ?? []) {
      final item = raw as Map<String, dynamic>;
      await db
          .into(db.counters)
          .insertOnConflictUpdate(
            CountersCompanion(
              id: Value(item['id'] as String),
              name: Value(item['name'] as String? ?? ''),
              count: Value(item['count'] as int? ?? 0),
              createdAt: Value(_parseDt(item['created_at'], now)),
              updatedAt: Value(_parseDt(item['updated_at'], now)),
              deletedAt: Value(
                item['deleted_at'] == null
                    ? null
                    : _parseDt(item['deleted_at'], now),
              ),
              revision: Value(item['revision'] as int? ?? revision),
              dirty: const Value(false),
            ),
          );
    }

    for (final raw in data['collections'] as List<dynamic>? ?? []) {
      final item = raw as Map<String, dynamic>;
      await db
          .into(db.collections)
          .insertOnConflictUpdate(
            CollectionsCompanion(
              id: Value(item['id'] as String),
              name: Value(item['name'] as String? ?? ''),
              description: Value(item['description'] as String? ?? ''),
              isDefault: Value(item['is_default'] as bool? ?? false),
              isFavorite: Value(item['is_favorite'] as bool? ?? false),
              reminderEnabled: Value(item['reminder_enabled'] as bool? ?? false),
              reminderHour: Value(item['reminder_hour'] as int?),
              reminderMinute: Value(item['reminder_minute'] as int?),
              updatedAt: Value(_parseDt(item['updated_at'], now)),
              deletedAt: Value(
                item['deleted_at'] == null
                    ? null
                    : _parseDt(item['deleted_at'], now),
              ),
              revision: Value(item['revision'] as int? ?? revision),
              dirty: const Value(false),
            ),
          );
    }

    for (final raw in data['items'] as List<dynamic>? ?? []) {
      final item = raw as Map<String, dynamic>;
      await db
          .into(db.collectionItems)
          .insertOnConflictUpdate(
            CollectionItemsCompanion(
              id: Value(item['id'] as String),
              collectionId: Value(item['collection_id'] as String),
              itemText: Value(item['text'] as String? ?? ''),
              repeatCount: Value(item['repeat_count'] as int? ?? 1),
              progress: Value(item['progress'] as int? ?? 0),
              sortOrder: Value(item['sort_order'] as int? ?? 0),
              updatedAt: Value(_parseDt(item['updated_at'], now)),
              deletedAt: Value(
                item['deleted_at'] == null
                    ? null
                    : _parseDt(item['deleted_at'], now),
              ),
              revision: Value(item['revision'] as int? ?? revision),
              dirty: const Value(false),
            ),
          );
    }

    for (final raw in data['daily_progress'] as List<dynamic>? ?? []) {
      final item = raw as Map<String, dynamic>;
      await db
          .into(db.dailyProgressRows)
          .insertOnConflictUpdate(
            DailyProgressRowsCompanion(
              collectionId: Value(item['collection_id'] as String),
              date: Value('${item['date']}'),
              completed: Value(item['completed'] as bool? ?? false),
              completedAt: Value(
                item['completed_at'] == null
                    ? null
                    : _parseDt(item['completed_at'], now),
              ),
              itemsDone: Value(item['items_done'] as int? ?? 0),
              itemsTotal: Value(item['items_total'] as int? ?? 0),
              updatedAt: Value(_parseDt(item['updated_at'], now)),
              deletedAt: Value(
                item['deleted_at'] == null
                    ? null
                    : _parseDt(item['deleted_at'], now),
              ),
              revision: Value(item['revision'] as int? ?? revision),
              dirty: const Value(false),
            ),
          );
    }

    await setServerRevision(revision);
  }

  Future<int> streakFor(String collectionId) async {
    final rows =
        await (db.select(db.dailyProgressRows)..where(
              (t) =>
                  t.collectionId.equals(collectionId) & t.deletedAt.isNull(),
            ))
            .get();
    final byDate = {
      for (final row in rows)
        if (row.completed) row.date: true,
    };
    var cursor = _today;
    if (byDate[_dateKey(cursor)] != true) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    var streak = 0;
    while (byDate[_dateKey(cursor)] == true) {
      streak += 1;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }
}

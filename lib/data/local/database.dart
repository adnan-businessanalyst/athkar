import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class Counters extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Collections extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  BoolColumn get reminderEnabled => boolean().withDefault(const Constant(false))();
  IntColumn get reminderHour => integer().nullable()();
  IntColumn get reminderMinute => integer().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class CollectionItems extends Table {
  TextColumn get id => text()();
  TextColumn get collectionId => text()();
  TextColumn get itemText => text()();
  IntColumn get repeatCount => integer().withDefault(const Constant(1))();
  IntColumn get progress => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class Locations extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  TextColumn get label => text()();
  TextColumn get source => text()();
  TextColumn get city => text().nullable()();
  TextColumn get country => text().nullable()();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class SettingsRows extends Table {
  @override
  String get tableName => 'settings';

  IntColumn get id => integer().withDefault(const Constant(1))();
  BoolColumn get adhanEnabled => boolean().withDefault(const Constant(true))();
  TextColumn get mutedPrayers => text().withDefault(const Constant('[]'))();
  TextColumn get calculationMethod =>
      text().withDefault(const Constant('umm_al_qura'))();
  TextColumn get madhab => text().withDefault(const Constant('shafi'))();
  DateTimeColumn get updatedAt => dateTime()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

class DailyProgressRows extends Table {
  @override
  String get tableName => 'daily_progress';

  TextColumn get collectionId => text()();
  TextColumn get date => text()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  IntColumn get itemsDone => integer().withDefault(const Constant(0))();
  IntColumn get itemsTotal => integer().withDefault(const Constant(0))();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  IntColumn get revision => integer().withDefault(const Constant(0))();
  BoolColumn get dirty => boolean().withDefault(const Constant(true))();

  @override
  Set<Column<Object>> get primaryKey => {collectionId, date};
}

class LocalMeta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => {key};
}

@DriftDatabase(
  tables: [
    Counters,
    Collections,
    CollectionItems,
    Locations,
    SettingsRows,
    DailyProgressRows,
    LocalMeta,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'athkar'));

  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;
}

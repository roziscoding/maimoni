import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'backup.dart';

part 'database.g.dart';

/// Opens the database file on the device, in the folder [databaseFolder] picks.
LocalDatabase openLocalDatabase() => LocalDatabase(driftDatabase(
      name: 'maimoni',
      native: const DriftNativeOptions(databaseDirectory: databaseFolder),
    ));

/*
 * The local storage mode's tables. They mirror the server's (apps/backend/src/db/schema.ts) without
 * the owner: the whole database belongs to whoever holds the device.
 */

/// The currencies the person works with. Exactly one of them is the main one.
@DataClassName('CurrencyRow')
class Currencies extends Table {
  TextColumn get code => text()();
  BoolColumn get enabled => boolean().withDefault(const Constant(true))();
  BoolColumn get main => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {code};
}

@DataClassName('TemplateItemRow')
class TemplateItems extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get currency => text()();
  TextColumn get kind => text()();
  RealColumn get amount => real().nullable()();
  TextColumn get expression => text().nullable()();
  BoolColumn get variable => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('MonthRow')
class Months extends Table {
  TextColumn get id => text()();
  IntColumn get year => integer()();
  IntColumn get month => integer()();
  TextColumn get mainCurrency => text()();

  /// JSON map of currency code to rate.
  TextColumn get lockedRates => text().withDefault(const Constant('{}'))();
  IntColumn get activeDay => integer().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};

  @override
  List<Set<Column>> get uniqueKeys => [
        {year, month},
      ];
}

@DataClassName('MonthItemRow')
class MonthItems extends Table {
  TextColumn get id => text()();
  TextColumn get monthId => text().references(Months, #id, onDelete: KeyAction.cascade)();
  TextColumn get templateItemId => text().nullable().references(TemplateItems, #id, onDelete: KeyAction.setNull)();
  TextColumn get name => text()();
  TextColumn get currency => text()();
  TextColumn get kind => text()();
  RealColumn get amount => real().nullable()();
  TextColumn get expression => text().nullable()();
  BoolColumn get paid => boolean().withDefault(const Constant(false))();
  BoolColumn get needsReview => boolean().withDefault(const Constant(false))();
  IntColumn get position => integer()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('DailySpendRow')
class DailySpends extends Table {
  TextColumn get id => text()();
  TextColumn get monthId => text().references(Months, #id, onDelete: KeyAction.cascade)();
  IntColumn get day => integer()();
  TextColumn get currency => text()();
  RealColumn get amount => real()();
  TextColumn get expression => text().nullable()();
  TextColumn get note => text().nullable()();
  TextColumn get createdAt => text()();

  @override
  Set<Column> get primaryKey => {id};
}

/// The last rates fetched for each base currency, served as stale when the providers can't be reached.
class StoredRates extends Table {
  TextColumn get base => text()();

  /// JSON map of currency code to rate.
  TextColumn get rates => text()();
  TextColumn get source => text()();
  TextColumn get fetchedAt => text()();

  @override
  Set<Column> get primaryKey => {base};
}

/// Loose settings that travel with the data, such as whether the first-run setup is done.
@DataClassName('MetaRow')
class Meta extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

@DriftDatabase(tables: [Currencies, TemplateItems, Months, MonthItems, DailySpends, StoredRates, Meta])
class LocalDatabase extends _$LocalDatabase {
  LocalDatabase(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        // SQLite leaves foreign keys off unless every connection turns them on.
        beforeOpen: (_) => customStatement('PRAGMA foreign_keys = ON'),
      );
}

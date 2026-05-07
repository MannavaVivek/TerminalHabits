import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

String newUuid() => const Uuid().v4();

class Groups extends Table {
  TextColumn get id => text().clientDefault(newUuid)();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer()();
  BoolColumn get collapsed =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get groupId =>
      text().references(Groups, #id)();
  TextColumn get name => text()();
  TextColumn get icon =>
      text().withDefault(const Constant('●'))();
  TextColumn get color =>
      text().withDefault(const Constant('green'))();
  // 'checkbox' | 'count' | 'number' | 'health'
  TextColumn get tracking => text()();
  IntColumn get target => integer().nullable()();
  TextColumn get unit => text().nullable()();
  // JSON: {"days":[0..6]}
  TextColumn get schedule => text()();
  TextColumn get note => text().nullable()();
  IntColumn get sortIndex => integer()();
  TextColumn get healthSource => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId =>
      integer().references(Habits, #id)();
  // local midnight stored as UTC
  DateTimeColumn get day => dateTime()();
  RealColumn get value =>
      real().withDefault(const Constant(1.0))();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
        {habitId, day}
      ];
}

class Vacations extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get active =>
      boolean().withDefault(const Constant(false))();
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};

  @override
  String get tableName => 'settings';
}

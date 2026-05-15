import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

String newUuid() => const Uuid().v4();

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get username => text().unique()();
  TextColumn get displayName => text()();
  // Plaintext until Phase 10 replaces with Supabase auth.
  TextColumn get password => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}

class Groups extends Table {
  TextColumn get id => text().clientDefault(newUuid)();
  IntColumn get userId =>
      integer().withDefault(const Constant(1))();
  TextColumn get name => text()();
  IntColumn get sortIndex => integer()();
  BoolColumn get collapsed =>
      boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  TextColumn get icon => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Habits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get userId =>
      integer().withDefault(const Constant(1))();
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
  TextColumn get targetTime => text().nullable()();
  IntColumn get sortIndex => integer()();
  TextColumn get healthSource => text().nullable()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get startDate =>
      dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get endDate => dateTime().nullable()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class HabitScheduleHistory extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get habitId => integer().references(Habits, #id)();
  // UTC midnight of the first day this schedule/tracking applies.
  DateTimeColumn get effectiveFrom => dateTime()();
  TextColumn get schedule => text()();
  TextColumn get tracking => text()();
  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
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
  IntColumn get userId =>
      integer().withDefault(const Constant(1))();
  DateTimeColumn get start => dateTime()();
  DateTimeColumn get end => dateTime()();
  TextColumn get note => text().nullable()();
  BoolColumn get active =>
      boolean().withDefault(const Constant(false))();
}

class DayShields extends Table {
  IntColumn      get id        => integer().autoIncrement()();
  DateTimeColumn get day       => dateTime()();
  DateTimeColumn get appliedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [{day}];
}

class AppSettings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};

  @override
  String get tableName => 'settings';
}

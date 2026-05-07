import 'dart:convert';
import '../data/database.dart';

// Returns true if [habit] is due on [localDay].
// Schedule JSON: {"days":[0..6]} where 0=Mon, 6=Sun.
bool isHabitDueOn(Habit habit, DateTime localDay) {
  final map = jsonDecode(habit.schedule) as Map<String, dynamic>;
  final days = (map['days'] as List).cast<int>();
  // Dart weekday: 1=Mon..7=Sun → convert to 0=Mon..6=Sun
  final weekday = (localDay.weekday + 6) % 7;
  return days.contains(weekday);
}

// Convenience schedule encodings.
String dailySchedule() => '{"days":[0,1,2,3,4,5,6]}';
String weekdaySchedule() => '{"days":[0,1,2,3,4]}';
String weekendSchedule() => '{"days":[5,6]}';
String customSchedule(List<int> days) =>
    '{"days":${jsonEncode(days..sort())}}';

// Human-readable description of a schedule.
String scheduleLabel(String schedule) {
  final map = jsonDecode(schedule) as Map<String, dynamic>;
  final days = (map['days'] as List).cast<int>()..sort();
  if (days.length == 7) return 'daily';
  if (days.length == 5 && days.first == 0 && days.last == 4) return 'weekdays';
  if (days.length == 2 && days.first == 5) return 'weekends';
  const labels = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
  return days.map((d) => labels[d]).join(', ');
}

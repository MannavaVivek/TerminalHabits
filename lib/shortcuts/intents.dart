import 'package:flutter/widgets.dart';

// View names used by navigation intents.
enum ViewName { daily, stats, vacation }

// One Intent per logical user action. Both keyboard shortcuts (desktop) and
// touch widgets (mobile) dispatch these same intents.

class GoToIntent extends Intent {
  final ViewName view;
  const GoToIntent(this.view);
}

class NewHabitIntent extends Intent {
  const NewHabitIntent();
}

class ToggleFocusedHabitIntent extends Intent {
  const ToggleFocusedHabitIntent();
}

class FocusNextHabitIntent extends Intent {
  const FocusNextHabitIntent();
}

class FocusPrevHabitIntent extends Intent {
  const FocusPrevHabitIntent();
}

class OpenPaletteIntent extends Intent {
  const OpenPaletteIntent();
}

class OpenSettingsIntent extends Intent {
  const OpenSettingsIntent();
}

class StartVacationIntent extends Intent {
  const StartVacationIntent();
}

class EditFocusedHabitIntent extends Intent {
  const EditFocusedHabitIntent();
}

class ArchiveFocusedHabitIntent extends Intent {
  const ArchiveFocusedHabitIntent();
}

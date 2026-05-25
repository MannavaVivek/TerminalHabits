# TerminalHabits

A terminal-themed habit tracker for macOS and Android. Local-first (SQLite via
Drift), with optional cloud sync via your own Supabase project.

- **Local-first**: works fully offline. Sync is opt-in via sign-in.
- **Multi-device**: last-write-wins merge over Supabase Realtime.
- **Health Connect** (Android): pull steps / sleep / exercise into a habit.
- **Streaks + shields**: earn a shield every N-day milestone; one missed day
  consumes a shield instead of breaking the streak.

## Download

Pre-built binaries are attached to each
[GitHub Release](../../releases/latest):

- `TerminalHabits-macos.zip` — unzip and move `TerminalHabits.app` to
  `/Applications`. First launch: right-click → Open (unsigned build).
- `terminal-habits.apk` — sideload on Android 8.0+.

## Build from source

### Prerequisites

- Flutter SDK ≥ 3.24 (Dart 3.11+). `flutter doctor` should be clean for the
  platforms you want to target.
- A Supabase project if you want cloud sync (free tier is fine).
- Xcode + CocoaPods (macOS build only).
- Android Studio + JDK 17 (Android build only).

### Clone and configure

```sh
git clone https://github.com/<your-fork>/terminal_habits.git
cd terminal_habits

# Create the local config from the template:
cp lib/config/supabase_config.example.dart lib/config/supabase_config.dart
# Edit supabase_config.dart and fill in your project URL + anon key.
# This file is gitignored.

flutter pub get
```

If you don't care about sync, you can leave the placeholder values in
`supabase_config.dart`. The app will start, the sign-in screen will fail to
connect, and you can still use it offline by skipping sign-in.

### Run

```sh
flutter run -d macos          # desktop
flutter run -d <device-id>    # Android (use `flutter devices` to list)
```

### Release builds

```sh
flutter build macos --release
# → build/macos/Build/Products/Release/TerminalHabits.app

flutter build apk --release
# → build/app/outputs/flutter-apk/app-release.apk
```

## Supabase setup

The app uses Supabase Auth (email + password) and Postgres with RLS. Setting
up a fresh project takes ~5 minutes.

### 1. Create the project

- Create a new project at [supabase.com](https://supabase.com).
- Settings → API → copy the **Project URL** and the **anon / publishable
  key** into `lib/config/supabase_config.dart`.
- Authentication → Providers → keep **Email** enabled. Disable "Confirm
  email" if you want sign-in to work without an SMTP setup.

### 2. Create the schema

Open SQL Editor and run:

```sql
-- groups
create table public.groups (
  id           text primary key,
  user_id      uuid not null references auth.users(id) on delete cascade,
  name         text not null,
  sort_index   int  not null,
  collapsed    boolean not null default false,
  note         text,
  icon         text,
  updated_at   bigint not null,
  deleted      boolean not null default false
);

-- habits
create table public.habits (
  id            bigint primary key,
  user_id       uuid not null references auth.users(id) on delete cascade,
  group_id      text not null,
  name          text not null,
  icon          text not null default '●',
  color         text not null default 'green',
  tracking      text not null,
  target        int,
  unit          text,
  schedule      text not null,
  note          text,
  target_time   text,
  sort_index    int  not null,
  health_source text,
  created_at    bigint not null,
  start_date    bigint not null,
  end_date      bigint,
  archived_at   bigint,
  updated_at    bigint not null,
  deleted       boolean not null default false
);

-- habit_schedule_history
create table public.habit_schedule_history (
  id             bigint primary key,
  user_id        uuid not null references auth.users(id) on delete cascade,
  habit_id       bigint not null,
  effective_from bigint not null,
  schedule       text not null,
  tracking       text not null,
  created_at     bigint not null
);

-- completions
create table public.completions (
  id          bigint primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  habit_id    bigint not null,
  day         bigint not null,
  value       double precision not null default 1.0,
  created_at  bigint not null,
  updated_at  bigint not null,
  deleted     boolean not null default false
);

-- vacations
create table public.vacations (
  id        bigint primary key,
  user_id   uuid not null references auth.users(id) on delete cascade,
  start_ts  bigint not null,
  end_ts    bigint not null,
  active    boolean not null default false,
  note      text
);

-- day_shields
create table public.day_shields (
  id          bigint primary key,
  user_id     uuid not null references auth.users(id) on delete cascade,
  day         bigint not null,
  applied_at  bigint not null
);
```

### 3. Row Level Security

Every table must restrict access to the row's owner. Run:

```sql
alter table public.groups                 enable row level security;
alter table public.habits                 enable row level security;
alter table public.habit_schedule_history enable row level security;
alter table public.completions            enable row level security;
alter table public.vacations              enable row level security;
alter table public.day_shields            enable row level security;

-- Same policy shape for every table:
do $$
declare t text;
begin
  foreach t in array array[
    'groups','habits','habit_schedule_history',
    'completions','vacations','day_shields'
  ] loop
    execute format($f$
      create policy %1$I_owner on public.%1$I
        for all
        using  (auth.uid() = user_id)
        with check (auth.uid() = user_id);
    $f$, t);
  end loop;
end $$;
```

### 4. Enable Realtime

Database → Replication → enable the `supabase_realtime` publication for all
six tables above. The client subscribes to changes filtered by `user_id` so
edits from one device propagate to the others within a second.

That's it. Launch the app, sign up, and your data starts syncing.

## Health Connect (Android only)

Habits with `tracking: health` pull their value from Health Connect rather
than user input. To wire it up:

1. Install **Health Connect** from the Play Store on Android < 14 (it's
   built in on 14+).
2. In TerminalHabits, add a habit and pick a health source (`steps`,
   `sleep`, or `exercise`).
3. The first launch will request the relevant Health Connect permission.

Values are pulled in the background and on app foreground. You can still
manually override the value by tapping the habit row.

## Project layout

```
lib/
  app.dart, main.dart        # entry, theming
  app_info.dart              # version string
  config/                    # gitignored Supabase config lives here
  data/                      # Drift schema + sync service
  domain/                    # streaks, schedule, shields, export/import
  state/                     # Riverpod providers
  ui/                        # views, modals, widgets, mobile/desktop split
  theme/                     # color palettes + tokens
specs/
  *.md                       # design + roadmap + per-phase logs
```

## License

No license declared. Personal project — fork freely for your own use.

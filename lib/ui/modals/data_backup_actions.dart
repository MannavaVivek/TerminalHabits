import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/database.dart';
import '../../data/sync_service.dart';
import '../../domain/data_export.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Asks the user where to save a JSON snapshot of the local DB, runs the
/// export, writes the file.
Future<void> handleExportBackup(BuildContext context, WidgetRef ref) async {
  final db = ref.read(dbProvider);
  final col = AppColors.of(context);
  final isoDate = DateTime.now().toIso8601String().split('T').first;
  final defaultName = 'terminal_habits_backup_$isoDate.json';

  String jsonStr;
  try {
    jsonStr = await exportAllToJson(db);
  } catch (e) {
    if (context.mounted) {
      await _showInfoDialog(
          context, 'export failed', 'could not read local data: $e', col);
    }
    return;
  }

  final bytes = utf8.encode(jsonStr);
  String? path;
  try {
    // file_picker on macOS rejects the `bytes` argument; on Android it
    // requires bytes for the platform save UI to actually persist a file.
    path = await FilePicker.platform.saveFile(
      dialogTitle: 'save terminal_habits backup',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: Platform.isAndroid ? bytes : null,
    );
  } catch (e) {
    if (context.mounted) {
      await _showInfoDialog(
          context, 'export failed', 'could not pick save location: $e', col);
    }
    return;
  }

  if (path == null) return; // user cancelled

  if (!Platform.isAndroid) {
    try {
      await File(path).writeAsBytes(bytes, flush: true);
    } catch (e) {
      if (context.mounted) {
        await _showInfoDialog(
            context, 'export failed', 'could not write file: $e', col);
      }
      return;
    }
  }

  if (context.mounted) {
    await _showInfoDialog(
        context, 'export complete', 'saved to:\n$path', col);
  }
}

/// Confirms, picks file, detects habit-name conflicts, asks for resolution,
/// merges into local data. Pushes to Supabase afterwards if signed in.
Future<void> handleImportBackup(BuildContext context, WidgetRef ref) async {
  final col = AppColors.of(context);
  final db = ref.read(dbProvider);
  final loggedIn = Supabase.instance.client.auth.currentSession != null;

  // ── Pick the file first; no commitment yet. ─────────────────────────
  FilePickerResult? picked;
  try {
    picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'choose backup file',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
  } catch (e) {
    if (context.mounted) {
      await _showInfoDialog(
          context, 'import failed', 'could not open file: $e', col);
    }
    return;
  }
  if (picked == null || picked.files.isEmpty) return;
  final file = picked.files.single;

  String jsonStr;
  try {
    if (file.bytes != null) {
      jsonStr = utf8.decode(file.bytes!);
    } else if (file.path != null) {
      jsonStr = await File(file.path!).readAsString();
    } else {
      if (context.mounted) {
        await _showInfoDialog(
            context, 'import failed', 'no file data available.', col);
      }
      return;
    }
  } catch (e) {
    if (context.mounted) {
      await _showInfoDialog(
          context, 'import failed', 'could not read file: $e', col);
    }
    return;
  }

  // ── Detect name conflicts before doing anything destructive. ────────
  List<String> conflicts;
  try {
    conflicts = await peekImportConflicts(db, jsonStr);
  } on ImportError catch (e) {
    if (context.mounted) {
      await _showInfoDialog(context, 'import failed', e.message, col);
    }
    return;
  }

  ImportConflictResolution? resolution =
      ImportConflictResolution.keepLocal; // default if no conflicts
  if (conflicts.isNotEmpty) {
    if (!context.mounted) return;
    resolution = await _askConflictResolution(context, conflicts, col);
    if (resolution == null) return; // user cancelled
  } else {
    if (!context.mounted) return;
    final go = await _confirmMerge(context, loggedIn: loggedIn, col: col);
    if (go != true) return;
  }

  // ── Run the import. ─────────────────────────────────────────────────
  ImportResult result;
  try {
    result = await importFromJson(db, jsonStr,
        conflictResolution: resolution);
  } on ImportError catch (e) {
    if (context.mounted) {
      await _showInfoDialog(context, 'import failed', e.message, col);
    }
    return;
  } catch (e) {
    if (context.mounted) {
      await _showInfoDialog(context, 'import failed', '$e', col);
    }
    return;
  }

  // ── Push so the imported data survives the next pull. ───────────────
  String pushNote = '';
  if (loggedIn) {
    try {
      await SyncService(db).pushAll();
      pushNote = '\npushed to cloud.';
    } catch (e) {
      pushNote = '\nlocal merge succeeded but cloud push failed: $e';
    }
  }

  if (context.mounted) {
    final lines = <String>[
      'added: ${result.habitsAdded} habit(s), '
          '${result.completionsAdded} completion(s), '
          '${result.groupsAdded} group(s)',
      if (result.habitsReplaced > 0)
        'replaced: ${result.habitsReplaced} habit(s) (old completions cleared)',
      if (result.habitsSkipped > 0)
        'kept local: ${result.habitsSkipped} habit(s)',
      if (result.vacationsAdded > 0)
        'added: ${result.vacationsAdded} vacation(s)',
      if (result.shieldsAdded > 0)
        'added: ${result.shieldsAdded} shield(s)',
    ];
    await _showInfoDialog(
        context, 'import complete', '${lines.join('\n')}$pushNote', col);
  }
}

Future<bool?> _confirmMerge(
  BuildContext context, {
  required bool loggedIn,
  required AppColors col,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('merge backup?',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                'this will add habits, completions, and groups from the\n'
                'file to your existing data. groups with the same name\n'
                'will be merged.',
                style: TextStyle(color: col.fgDim, fontSize: 12),
              ),
              if (loggedIn) ...[
                const SizedBox(height: TH.s8),
                Text(
                  '// signed in — the merged data will also be pushed to\n'
                  '// supabase.',
                  style: TextStyle(color: col.fgFaint, fontSize: 11),
                ),
              ],
              const SizedBox(height: TH.s22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(false),
                    child: Text('[ cancel ]',
                        style:
                            TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                  const SizedBox(width: TH.s14),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.green),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ merge ]',
                          style:
                              TextStyle(color: col.green, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<ImportConflictResolution?> _askConflictResolution(
  BuildContext context,
  List<String> conflicts,
  AppColors col,
) {
  final preview = conflicts.length <= 5
      ? conflicts.map((n) => '• $n').join('\n')
      : '${conflicts.take(5).map((n) => '• $n').join('\n')}\n'
          '… and ${conflicts.length - 5} more';
  return showDialog<ImportConflictResolution>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('habit name conflicts',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                '${conflicts.length} habit${conflicts.length == 1 ? '' : 's'} '
                'in the file share a name with an existing habit:',
                style: TextStyle(color: col.fgDim, fontSize: 12),
              ),
              const SizedBox(height: TH.s8),
              Text(preview,
                  style: TextStyle(color: col.fg, fontSize: 12)),
              const SizedBox(height: TH.s14),
              Text(
                '// replace: discards the local habit + its history,\n'
                '// uses the imported version instead.\n'
                '// keep: leaves your local habits untouched and skips\n'
                '// these from the file.',
                style: TextStyle(color: col.fgFaint, fontSize: 11),
              ),
              const SizedBox(height: TH.s22),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(null),
                    child: Text('[ cancel ]',
                        style:
                            TextStyle(color: col.fgMute, fontSize: 12)),
                  ),
                  const SizedBox(width: TH.s14),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx)
                        .pop(ImportConflictResolution.keepLocal),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.line2),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ keep local ]',
                          style: TextStyle(
                              color: col.fgDim, fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: TH.s8),
                  GestureDetector(
                    onTap: () => Navigator.of(ctx)
                        .pop(ImportConflictResolution.replace),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.amber),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ replace ]',
                          style: TextStyle(
                              color: col.amber, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showInfoDialog(
    BuildContext context, String title, String body, AppColors col) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) => Dialog(
      backgroundColor: col.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: const BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 360,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(body,
                  style: TextStyle(color: col.fgDim, fontSize: 12)),
              const SizedBox(height: TH.s22),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(ctx).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TH.s22, vertical: TH.s8),
                    decoration: BoxDecoration(
                      border: Border.all(color: col.green),
                      borderRadius: const BorderRadius.all(TH.r4),
                    ),
                    child: Text('[ ok ]',
                        style:
                            TextStyle(color: col.green, fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

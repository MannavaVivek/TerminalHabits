import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/database.dart';
import '../../domain/data_export.dart';
import '../../state/providers.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';

/// Asks the user where to save a JSON snapshot of the local DB, runs the
/// export, writes the file. Returns silently on cancel or error.
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
    path = await FilePicker.platform.saveFile(
      dialogTitle: 'save terminal_habits backup',
      fileName: defaultName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
  } catch (e) {
    if (context.mounted) {
      await _showInfoDialog(
          context, 'export failed', 'could not write file: $e', col);
    }
    return;
  }

  if (path == null) return; // user cancelled

  // On some platforms file_picker doesn't actually write the bytes for us
  // (it just returns the chosen path). Fall back to writing manually.
  try {
    final f = File(path);
    if (!await f.exists() || (await f.length()) == 0) {
      await f.writeAsBytes(bytes, flush: true);
    }
  } catch (_) {
    // saveFile already wrote it on platforms that handle bytes natively.
  }

  if (context.mounted) {
    await _showInfoDialog(
        context, 'export complete', 'saved to:\n$path', col);
  }
}

/// Confirms with the user, picks a JSON file, validates schema, replaces
/// local data. Blocks when signed in (the next pull would overwrite the
/// import — the user must sign out first to avoid that surprise).
Future<void> handleImportBackup(BuildContext context, WidgetRef ref) async {
  final col = AppColors.of(context);
  final db = ref.read(dbProvider);

  if (Supabase.instance.client.auth.currentSession != null) {
    await _showInfoDialog(
        context,
        'sign out first',
        'import replaces local data. while signed in, your cloud account '
            'would re-sync after import and undo it. sign out, import, then '
            "sign back in if you want the import to be 'the' state.",
        col);
    return;
  }

  // Confirm the wipe.
  final go = await showDialog<bool>(
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
              Text('import backup?',
                  style: TextStyle(
                      color: col.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              Text(
                'this will erase all local data and replace it with the\n'
                'contents of the chosen file. this cannot be undone.',
                style: TextStyle(color: col.fgDim, fontSize: 12),
              ),
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
                        border: Border.all(color: col.red),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ replace ]',
                          style:
                              TextStyle(color: col.red, fontSize: 12)),
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
  if (go != true || !context.mounted) return;

  // Pick the file.
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

  ImportResult result;
  try {
    result = await importFromJson(db, jsonStr);
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

  if (context.mounted) {
    await _showInfoDialog(
        context,
        'import complete',
        'restored ${result.habits} habit(s), ${result.completions} '
            'completion(s), ${result.groups} group(s).\n'
            '\nrestart the app to refresh the daily view.',
        col);
  }
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

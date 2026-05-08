import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../state/providers.dart';
import '../../theme/tokens.dart';
import 'new_habit_dialog.dart';

class _Command {
  final String key;
  final String label;
  final String hint;

  const _Command({required this.key, required this.label, required this.hint});
}

class CommandPalette extends ConsumerStatefulWidget {
  // The context that opened the palette. Used to dispatch follow-up
  // dialogs/intents AFTER this dialog pops (the dialog's own context is
  // unmounted by then, so it can't host new modal routes).
  final BuildContext invokerContext;

  const CommandPalette({super.key, required this.invokerContext});

  static Future<void> show(BuildContext context) => showDialog(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => CommandPalette(invokerContext: context),
      );

  @override
  ConsumerState<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends ConsumerState<CommandPalette> {
  final _ctrl = TextEditingController();
  late final FocusNode _focus;
  String _query = '';
  int _selected = 0;

  static const _allCommands = [
    _Command(key: 'daily', label: 'go to daily view', hint: '⌘1'),
    _Command(key: 'stats', label: 'go to stats view', hint: '⌘2'),
    _Command(key: 'profile', label: 'go to profile view', hint: '⌘3'),
    _Command(key: 'new', label: 'new habit', hint: '⌘N'),
  ];

  @override
  void initState() {
    super.initState();
    _focus = FocusNode(onKeyEvent: _handleFieldKey);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  // Intercept arrow up/down on the text field's focus node so they navigate
  // the result list instead of moving the text caret.
  KeyEventResult _handleFieldKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveSelection(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveSelection(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      Navigator.of(context).pop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  List<_Command> get _filtered {
    if (_query.isEmpty) return _allCommands;
    final q = _query.toLowerCase();
    return _allCommands.where((c) => c.label.contains(q)).toList();
  }

  void _moveSelection(int delta) {
    final results = _filtered;
    if (results.isEmpty) return;
    setState(() {
      _selected = (_selected + delta).clamp(0, results.length - 1);
    });
  }

  void _activate() {
    final results = _filtered;
    if (results.isEmpty) return;
    final idx = _selected.clamp(0, results.length - 1);
    _invoke(results[idx]);
  }

  void _invoke(_Command cmd) {
    final invoker = widget.invokerContext;
    Navigator.of(context).pop();
    switch (cmd.key) {
      case 'daily':
        ref.read(currentViewProvider.notifier).state = 'daily';
      case 'stats':
        ref.read(currentViewProvider.notifier).state = 'stats';
      case 'profile':
        ref.read(currentViewProvider.notifier).state = 'profile';
      case 'new':
        if (invoker.mounted) NewHabitDialog.show(invoker);
    }
  }

  @override
  Widget build(BuildContext context) {
    final results = _filtered;
    final selectedIdx =
        results.isEmpty ? -1 : _selected.clamp(0, results.length - 1);

    return Dialog(
      backgroundColor: TH.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(TH.s14, TH.s14, TH.s14, 0),
              child: TextField(
                controller: _ctrl,
                focusNode: _focus,
                autofocus: true,
                style: const TextStyle(color: TH.fg, fontSize: 14),
                decoration: InputDecoration(
                  hintText: '> type a command…',
                  hintStyle:
                      const TextStyle(color: TH.fgFaint, fontSize: 14),
                  enabledBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.line2),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: TH.green),
                    borderRadius: BorderRadius.all(TH.r4),
                  ),
                  fillColor: TH.bg1,
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: TH.s8, vertical: TH.s8),
                ),
                onChanged: (v) => setState(() {
                  _query = v;
                  _selected = 0;
                }),
                onSubmitted: (_) => _activate(),
              ),
            ),
            const SizedBox(height: TH.s8),
            if (results.isEmpty)
              const Padding(
                padding: EdgeInsets.all(TH.s22),
                child: Text('no commands match',
                    style: TextStyle(color: TH.fgFaint, fontSize: 13)),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.only(
                    left: TH.s8, right: TH.s8, bottom: TH.s8),
                itemCount: results.length,
                itemBuilder: (_, i) => _CommandRow(
                  command: results[i],
                  selected: i == selectedIdx,
                  onTap: () => _invoke(results[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CommandRow extends StatelessWidget {
  final _Command command;
  final bool selected;
  final VoidCallback onTap;

  const _CommandRow({
    required this.command,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: TH.s8, vertical: TH.s8),
        decoration: BoxDecoration(
          color: selected ? TH.bg3 : Colors.transparent,
          border: const Border(
              bottom: BorderSide(color: TH.line, width: 1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 14,
              child: selected
                  ? const Text('▸',
                      style:
                          TextStyle(color: TH.amber, fontSize: 12))
                  : null,
            ),
            Text(command.label,
                style: TextStyle(
                    color: selected ? TH.fg : TH.fgDim,
                    fontSize: 13)),
            const Spacer(),
            Text(command.hint,
                style:
                    const TextStyle(color: TH.fgMute, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

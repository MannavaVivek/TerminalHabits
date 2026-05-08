import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../../theme/tokens.dart';

const _chromeHeight = 38.0;

class WindowChrome extends StatelessWidget {
  const WindowChrome({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _chromeHeight,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: TH.bg1,
          border: Border(bottom: BorderSide(color: TH.line, width: 1)),
        ),
        child: DragToMoveArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: TH.s14),
            child: Row(
              children: [
                // Native macOS traffic lights live here.
                const SizedBox(width: 72),
                const Expanded(
                  child: Center(
                    child: Text(
                      'TerminalHabits',
                      style: TextStyle(fontSize: 12, color: TH.fgDim),
                    ),
                  ),
                ),
                const _VersionMeta(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VersionMeta extends StatelessWidget {
  const _VersionMeta();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'v0.2.0 · matrix',
      style: TextStyle(fontSize: 11, color: TH.fgMute),
    );
  }
}

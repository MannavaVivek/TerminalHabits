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
                const _TrafficLights(),
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

class _TrafficLights extends StatelessWidget {
  const _TrafficLights();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _TrafficLight(color: TH.red, onTap: () async => windowManager.close()),
        const SizedBox(width: 6),
        _TrafficLight(
          color: TH.amber,
          onTap: () async => windowManager.minimize(),
        ),
        const SizedBox(width: 6),
        _TrafficLight(
          color: TH.green,
          onTap: () async {
            if (await windowManager.isMaximized()) {
              await windowManager.unmaximize();
            } else {
              await windowManager.maximize();
            }
          },
        ),
      ],
    );
  }
}

class _TrafficLight extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;

  const _TrafficLight({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _VersionMeta extends StatelessWidget {
  const _VersionMeta();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'v0.1.0 · matrix',
      style: TextStyle(fontSize: 11, color: TH.fgMute),
    );
  }
}

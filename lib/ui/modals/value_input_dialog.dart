import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/database.dart';
import '../../theme/tokens.dart';

/// Returns:
///   null  → user cancelled, no-op
///   0     → clear the completion for today
///   > 0   → set the completion to this value
class ValueInputDialog extends StatefulWidget {
  final Habit habit;
  final double currentValue;

  const ValueInputDialog(
      {super.key, required this.habit, required this.currentValue});

  static Future<double?> show(
    BuildContext context, {
    required Habit habit,
    required double currentValue,
  }) =>
      showDialog<double>(
        context: context,
        barrierColor: Colors.black54,
        builder: (_) => ValueInputDialog(
            habit: habit, currentValue: currentValue),
      );

  @override
  State<ValueInputDialog> createState() => _ValueInputDialogState();
}

class _ValueInputDialogState extends State<ValueInputDialog> {
  late final TextEditingController _ctrl;
  late double _value;

  bool get _isDuration => widget.habit.tracking == 'duration';
  String get _unit => _isDuration ? 'min' : '';
  int get _step => 1;

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue;
    _ctrl = TextEditingController(
        text: _value > 0 ? _value.toInt().toString() : '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _applyText() {
    final parsed = double.tryParse(_ctrl.text.trim());
    if (parsed != null && parsed >= 0) {
      setState(() => _value = parsed);
    }
  }

  void _increment() {
    _applyText();
    setState(() {
      _value = (_value + _step).clamp(0, 999).toDouble();
      _ctrl.text = _value.toInt().toString();
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  void _decrement() {
    _applyText();
    setState(() {
      _value = (_value - _step).clamp(0, 999).toDouble();
      _ctrl.text = _value > 0 ? _value.toInt().toString() : '';
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  void _confirm() {
    _applyText();
    Navigator.of(context).pop(_value);
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.habit.target;
    final subtitle = target != null
        ? '${widget.habit.tracking} · target $target$_unit'
        : widget.habit.tracking;

    return Dialog(
      backgroundColor: TH.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 300,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.habit.name,
                            style: const TextStyle(
                                color: TH.fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(subtitle,
                            style: const TextStyle(
                                color: TH.fgMute, fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: const Text('[ cancel ]',
                        style: TextStyle(
                            color: TH.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s22),
              Row(
                children: [
                  // ── decrement ────────────────────────────────────
                  _ArrowButton(
                    label: '−',
                    onTap: _decrement,
                  ),
                  const SizedBox(width: TH.s8),

                  // ── value field ──────────────────────────────────
                  Expanded(
                    child: KeyboardListener(
                      focusNode: FocusNode(),
                      onKeyEvent: (e) {
                        if (e is KeyDownEvent) {
                          if (e.logicalKey ==
                              LogicalKeyboardKey.arrowUp) {
                            _increment();
                          } else if (e.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            _decrement();
                          } else if (e.logicalKey ==
                              LogicalKeyboardKey.enter) {
                            _confirm();
                          }
                        }
                      },
                      child: TextField(
                        controller: _ctrl,
                        autofocus: true,
                        textAlign: TextAlign.center,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(3),
                        ],
                        style: const TextStyle(
                            color: TH.fg,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: const TextStyle(
                              color: TH.fgFaint, fontSize: 20),
                          suffix: _unit.isNotEmpty
                              ? Text(_unit,
                                  style: const TextStyle(
                                      color: TH.fgMute, fontSize: 13))
                              : null,
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: TH.line2),
                            borderRadius: BorderRadius.all(TH.r4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                const BorderSide(color: TH.green),
                            borderRadius: BorderRadius.all(TH.r4),
                          ),
                          fillColor: TH.bg1,
                          filled: true,
                          isDense: true,
                          contentPadding:
                              const EdgeInsets.symmetric(
                                  horizontal: TH.s8, vertical: TH.s14),
                        ),
                        onSubmitted: (_) => _confirm(),
                      ),
                    ),
                  ),
                  const SizedBox(width: TH.s8),

                  // ── increment ────────────────────────────────────
                  _ArrowButton(
                    label: '+',
                    onTap: _increment,
                  ),
                ],
              ),
              const SizedBox(height: TH.s14),

              // ── quick-set chips when target is known ─────────────
              if (target != null) ...[
                Wrap(
                  spacing: 6,
                  children: _quickValues(target)
                      .map((v) => _QuickChip(
                            label: '$v$_unit',
                            onTap: () {
                              setState(() {
                                _value = v.toDouble();
                                _ctrl.text = '$v';
                                _ctrl.selection = TextSelection.collapsed(
                                    offset: _ctrl.text.length);
                              });
                            },
                          ))
                      .toList(),
                ),
                const SizedBox(height: TH.s14),
              ],

              Row(
                children: [
                  // ── clear ────────────────────────────────────────
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(0.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: TH.line2),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ clear ]',
                          style: TextStyle(
                              color: TH.fgMute, fontSize: 12)),
                    ),
                  ),
                  const Spacer(),
                  // ── set ──────────────────────────────────────────
                  GestureDetector(
                    onTap: _confirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s22, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: TH.green),
                        borderRadius: BorderRadius.all(TH.r4),
                      ),
                      child: const Text('[ set ]',
                          style: TextStyle(
                              color: TH.green, fontSize: 13)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<int> _quickValues(int target) {
    if (_isDuration) {
      // Sensible duration chips: 25%, 50%, 75%, 100% of target
      final q = (target / 4).round();
      return {q, q * 2, q * 3, target}
          .where((v) => v > 0)
          .toList()
        ..sort();
    } else {
      // Counter: 25%, 50%, 75%, 100% of target
      final q = (target / 4).round();
      return {q, q * 2, q * 3, target}
          .where((v) => v > 0)
          .toList()
        ..sort();
    }
  }
}

class _ArrowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _ArrowButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: TH.line2),
          borderRadius: BorderRadius.all(TH.r4),
          color: TH.bg1,
        ),
        child: Center(
          child: Text(label,
              style: const TextStyle(
                  color: TH.fgDim,
                  fontSize: 20,
                  fontWeight: FontWeight.w300)),
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: TH.line2),
          borderRadius: BorderRadius.all(TH.r4),
        ),
        child: Text(label,
            style: const TextStyle(color: TH.fgDim, fontSize: 11)),
      ),
    );
  }
}

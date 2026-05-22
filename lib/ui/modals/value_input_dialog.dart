import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/database.dart';
import '../../theme/app_colors.dart';
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
  bool _overflowWarning = false;

  bool get _isDuration => widget.habit.tracking == 'duration';
  bool get _isHealth => widget.habit.tracking == 'health';
  String get _unit => _isDuration
      ? 'min'
      : (_isHealth ? (widget.habit.unit ?? '') : '');

  // Larger types (health) get a larger step + max so the +/− buttons and
  // text field can handle realistic ranges (steps, calories, etc.).
  int get _max => _isHealth ? 999999 : 999;
  int get _maxDigits => _isHealth ? 6 : 3;
  int get _step {
    if (_isHealth) {
      final target = widget.habit.target ?? 8000;
      // Round-ish quarter-target step, clamped to a sane range.
      final s = (target / 20).round();
      return s.clamp(50, 1000);
    }
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _value = widget.currentValue.clamp(0, _max).toDouble();
    _ctrl = TextEditingController(
        text: _value > 0 ? _value.toInt().toString() : '');
    _ctrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final parsed = double.tryParse(_ctrl.text.trim());
    if (parsed != null && parsed > _max) {
      final clamped = _max.toString();
      _ctrl
        ..text = clamped
        ..selection = TextSelection.collapsed(offset: clamped.length);
      setState(() {
        _value = _max.toDouble();
        _overflowWarning = true;
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => _overflowWarning = false);
      });
    }
  }

  void _applyText() {
    final parsed = double.tryParse(_ctrl.text.trim());
    if (parsed != null && parsed >= 0) {
      setState(() => _value = parsed.clamp(0, _max).toDouble());
    }
  }

  void _increment() {
    _applyText();
    setState(() {
      _value = (_value + _step).clamp(0, _max).toDouble();
      _ctrl.text = _value.toInt().toString();
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
    });
  }

  void _decrement() {
    _applyText();
    setState(() {
      _value = (_value - _step).clamp(0, _max).toDouble();
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
    final col = context.col;
    final target = widget.habit.target;
    final subtitle = target != null
        ? '${widget.habit.tracking} · target $target$_unit'
        : widget.habit.tracking;

    return Dialog(
      backgroundColor: col.bg2,
      shape:
          RoundedRectangleBorder(borderRadius: const BorderRadius.all(TH.r10)),
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
                            style: TextStyle(
                                color: col.fg,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                        Text(subtitle,
                            style: TextStyle(
                                color: col.fgMute, fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text('[ cancel ]',
                        style: TextStyle(
                            color: col.fgMute, fontSize: 12)),
                  ),
                ],
              ),
              const SizedBox(height: TH.s22),
              Row(
                children: [
                  _ArrowButton(label: '−', onTap: _decrement, col: col),
                  const SizedBox(width: TH.s8),
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
                          LengthLimitingTextInputFormatter(_maxDigits),
                        ],
                        style: TextStyle(
                            color: col.fg,
                            fontSize: 20,
                            fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: '0',
                          hintStyle: TextStyle(
                              color: col.fgFaint, fontSize: 20),
                          suffix: _unit.isNotEmpty
                              ? Text(_unit,
                                  style: TextStyle(
                                      color: col.fgMute, fontSize: 13))
                              : null,
                          enabledBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: col.line2),
                            borderRadius: const BorderRadius.all(TH.r4),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide:
                                BorderSide(color: col.green),
                            borderRadius: const BorderRadius.all(TH.r4),
                          ),
                          fillColor: col.bg1,
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
                  _ArrowButton(label: '+', onTap: _increment, col: col),
                ],
              ),
              if (_overflowWarning) ...[
                const SizedBox(height: TH.s4),
                Text('// max is $_max',
                    style: TextStyle(color: col.red, fontSize: 11)),
              ],
              const SizedBox(height: TH.s14),
              if (target != null) ...[
                Wrap(
                  spacing: 6,
                  children: _quickValues(target)
                      .map((v) => _QuickChip(
                            label: '$v$_unit',
                            col: col,
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
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(0.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s14, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.line2),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ clear ]',
                          style: TextStyle(
                              color: col.fgMute, fontSize: 12)),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: _confirm,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: TH.s22, vertical: TH.s8),
                      decoration: BoxDecoration(
                        border: Border.all(color: col.green),
                        borderRadius: const BorderRadius.all(TH.r4),
                      ),
                      child: Text('[ set ]',
                          style: TextStyle(
                              color: col.green, fontSize: 13)),
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
    final q = (target / 4).round();
    return {q, q * 2, q * 3, target}
        .where((v) => v > 0)
        .toList()
      ..sort();
  }
}

class _ArrowButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final AppColors col;
  const _ArrowButton({required this.label, required this.onTap, required this.col});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 48,
        decoration: BoxDecoration(
          border: Border.all(color: col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
          color: col.bg1,
        ),
        child: Center(
          child: Text(label,
              style: TextStyle(
                  color: col.fgDim,
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
  final AppColors col;
  const _QuickChip({required this.label, required this.onTap, required this.col});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: TH.s8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: col.line2),
          borderRadius: const BorderRadius.all(TH.r4),
        ),
        child: Text(label,
            style: TextStyle(color: col.fgDim, fontSize: 11)),
      ),
    );
  }
}

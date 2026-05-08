import 'package:flutter/material.dart';
import '../../theme/tokens.dart';

// Shows a "marking future days is disabled" notice. Always returns false —
// the caller never proceeds with the toggle.
Future<bool> confirmFutureToggle(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (_) => const _FutureWarnDialog(),
  );
  return false;
}

class _FutureWarnDialog extends StatelessWidget {
  const _FutureWarnDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TH.bg2,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(TH.r10)),
      child: SizedBox(
        width: 400,
        child: Padding(
          padding: const EdgeInsets.all(TH.s22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("can't mark a future day",
                  style: TextStyle(
                      color: TH.fg,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: TH.s8),
              const Text(
                "this day hasn't happened yet.\n"
                "track habits in the present — come back when it's today.",
                style: TextStyle(color: TH.fgDim, fontSize: 12),
              ),
              const SizedBox(height: TH.s22),
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: TH.s14, vertical: TH.s8),
                    decoration: BoxDecoration(
                      border: Border.all(color: TH.amber),
                      borderRadius: BorderRadius.all(TH.r4),
                    ),
                    child: const Text('[ understood ]',
                        style: TextStyle(
                            color: TH.amber, fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

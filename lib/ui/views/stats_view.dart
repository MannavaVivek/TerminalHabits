import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    final col = context.col;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(TH.s14),
          child: const PromptLine(user: 'you', command: 'stats'),
        ),
        Expanded(
          child: Center(
            child: Text(
              'stats — coming in Phase 2',
              style: TextStyle(color: col.fgFaint, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

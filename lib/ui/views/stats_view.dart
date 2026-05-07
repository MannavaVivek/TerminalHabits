import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';

class StatsView extends StatelessWidget {
  const StatsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Padding(
          padding: EdgeInsets.all(TH.s14),
          child: PromptLine(user: 'you', command: 'stats'),
        ),
        Expanded(
          child: Center(
            child: Text(
              'stats — coming in Phase 2',
              style: TextStyle(color: TH.fgFaint, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

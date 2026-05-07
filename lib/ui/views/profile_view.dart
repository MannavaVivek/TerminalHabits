import 'package:flutter/material.dart';
import '../../theme/tokens.dart';
import '../widgets/prompt_line.dart';

class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Padding(
          padding: EdgeInsets.all(TH.s14),
          child: PromptLine(user: 'you', command: 'profile'),
        ),
        Expanded(
          child: Center(
            child: Text(
              'profile — coming in Phase 3',
              style: TextStyle(color: TH.fgFaint, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}

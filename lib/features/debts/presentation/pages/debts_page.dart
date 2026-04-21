import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        SectionCard(
          title: 'Settlement Plan',
          subtitle: 'Simplified debts will show minimum payments between members.',
          icon: Icons.swap_horiz,
        ),
        SectionCard(
          title: 'Greedy Simplification',
          subtitle: 'Floating-point safe settlements with tolerance checks.',
          icon: Icons.functions,
        ),
      ],
    );
  }
}

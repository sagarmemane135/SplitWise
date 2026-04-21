import 'package:flutter/material.dart';

import '../../../../core/widgets/section_card.dart';

class SharesPage extends StatelessWidget {
  const SharesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const <Widget>[
        SectionCard(
          title: 'Who Gets Back',
          subtitle: 'Creditors will appear here once expenses are added.',
          icon: Icons.trending_up,
        ),
        SectionCard(
          title: 'Who Owes',
          subtitle: 'Debtors and payable totals are summarized here.',
          icon: Icons.trending_down,
        ),
      ],
    );
  }
}

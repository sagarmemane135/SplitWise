import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class SharesPage extends StatelessWidget {
  const SharesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;

    if (group == null) {
      return const Center(child: Text('Create a group from Manage to view shares.'));
    }

    final Map<String, double> balances = appState.activeGroupBalances;

    final List<MapEntry<String, double>> creditors = balances.entries
        .where((MapEntry<String, double> e) => e.value > 0.01)
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => b.value.compareTo(a.value));

    final List<MapEntry<String, double>> debtors = balances.entries
        .where((MapEntry<String, double> e) => e.value < -0.01)
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));

    return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SectionCard(
            title: 'Gets Back',
            subtitle: 'These members paid more than their share and are owed money.',
            icon: Icons.trending_up,
          ),
          if (creditors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 24),
              child: Text('Nobody is owed money right now.', style: TextStyle(color: Colors.grey)),
            )
          else ...[
            for (final MapEntry<String, double> c in creditors)
              _BalanceTile(
                member: _getMember(group, c.key),
                amount: c.value,
                isPositive: true,
              ),
            const SizedBox(height: 16),
          ],
          const SectionCard(
            title: 'Owes',
            subtitle: 'These members paid less than their share and owe money to the group.',
            icon: Icons.trending_down,
          ),
          if (debtors.isEmpty)
            const Padding(
              padding: EdgeInsets.only(left: 16, bottom: 24),
              child: Text('Nobody owes any money right now.', style: TextStyle(color: Colors.grey)),
            )
          else ...[
            for (final MapEntry<String, double> d in debtors)
              _BalanceTile(
                member: _getMember(group, d.key),
                amount: d.value,
                isPositive: false,
              ),
          ],
        ],
    );
  }

  GroupMember? _getMember(ExpenseGroup group, String id) {
    for (final GroupMember m in group.members) {
      if (m.id == id) return m;
    }
    return null;
  }
}

class _BalanceTile extends StatelessWidget {
  const _BalanceTile({required this.member, required this.amount, required this.isPositive});

  final GroupMember? member;
  final double amount;
  final bool isPositive;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = member?.name ?? 'Unknown';
    final Color amountColor = isPositive ? theme.colorScheme.secondary : theme.colorScheme.error;
    final String prefix = isPositive ? '+' : '-';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.surfaceVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: amountColor.withValues(alpha: 0.2),
          foregroundColor: amountColor,
          child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?'),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          '$prefix ₹${amount.abs().toStringAsFixed(2)}',
          style: TextStyle(
            color: amountColor,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}

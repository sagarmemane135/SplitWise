import 'package:flutter/material.dart';
import 'dart:math';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class Settlement {
  const Settlement({required this.fromId, required this.toId, required this.amount});
  final String fromId;
  final String toId;
  final double amount;
}

class DebtsPage extends StatelessWidget {
  const DebtsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;

    if (group == null) {
      return const Center(child: Text('Create a group from Manage to view optimal settlements.'));
    }

    final Map<String, double> balances = appState.activeGroupBalances;
    final List<Settlement> settlements = _calculateSettlements(balances);

    return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const SectionCard(
            title: 'Settlement Plan',
            subtitle: 'The algorithm condenses all transactions into the absolute minimum payments.',
            icon: Icons.account_balance_wallet,
          ),
          const SizedBox(height: 16),
          if (settlements.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Everyone is perfectly settled up!', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...settlements.map((Settlement s) {
              final GroupMember? fromMem = _getMember(group, s.fromId);
              final GroupMember? toMem = _getMember(group, s.toId);
              return _DebtCard(fromMem: fromMem, toMem: toMem, amount: s.amount);
            }),
        ],
    );
  }

  List<Settlement> _calculateSettlements(Map<String, double> balances) {
    final List<MapEntry<String, double>> creditors = balances.entries
        .where((MapEntry<String, double> e) => e.value > 0.01)
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));

    final List<MapEntry<String, double>> debtors = balances.entries
        .where((MapEntry<String, double> e) => e.value < -0.01)
        .toList()
      ..sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));

    final List<Settlement> settlements = <Settlement>[];

    while (creditors.isNotEmpty && debtors.isNotEmpty) {
      final MapEntry<String, double> creditor = creditors.removeLast();
      final MapEntry<String, double> debtor = debtors.removeFirst(); // lowest negative is largest absolute debt

      final double debtAbs = debtor.value.abs();
      final double credit = creditor.value;
      final double settledAmount = min(debtAbs, credit);

      if (settledAmount < 0.01) continue;

      settlements.add(Settlement(fromId: debtor.key, toId: creditor.key, amount: settledAmount));

      final double remainingCredit = credit - settledAmount;
      final double remainingDebt = debtAbs - settledAmount;

      if (remainingCredit > 0.01) {
        creditors.add(MapEntry<String, double>(creditor.key, remainingCredit));
        creditors.sort((MapEntry<String, double> a, MapEntry<String, double> b) => a.value.compareTo(b.value));
      }
      if (remainingDebt > 0.01) {
        debtors.insert(0, MapEntry<String, double>(debtor.key, -remainingDebt));
      }
    }

    return settlements;
  }

  GroupMember? _getMember(ExpenseGroup group, String id) {
    for (final GroupMember m in group.members) {
      if (m.id == id) return m;
    }
    return null;
  }
}

extension ListExtensions<T> on List<T> {
  T removeFirst() {
    return removeAt(0);
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.fromMem, required this.toMem, required this.amount});

  final GroupMember? fromMem;
  final GroupMember? toMem;
  final double amount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String fromName = fromMem?.name ?? 'Unknown';
    final String toName = toMem?.name ?? 'Unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.surfaceVariant),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.error.withValues(alpha: 0.2),
                  child: Text(
                    fromName.isNotEmpty ? fromName.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(fromName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: <Widget>[
                Text(
                  '₹${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: theme.colorScheme.primary),
              ],
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  radius: 18,
                  backgroundColor: theme.colorScheme.secondary.withValues(alpha: 0.2),
                  child: Text(
                    toName.isNotEmpty ? toName.substring(0, 1).toUpperCase() : '?',
                    style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                Text(toName, style: const TextStyle(fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';
import 'expense_detail_page.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;
    final List<ExpenseItem> expenses = appState.activeGroupExpenses;

    if (group == null) {
      return const Center(child: Text('Create a group from Manage to begin.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        const _HeroBanner(
          title: 'Active Group Overview',
          subtitle: 'Track all expenses and who paid what at a glance.',
        ),
        const SizedBox(height: 16),
        SectionCard(
          title: 'Group: ${group.name}',
          subtitle: 'Members: ${group.members.length} | Expenses: ${expenses.length}',
          icon: Icons.groups,
        ),
        if (expenses.isEmpty)
          const SectionCard(
            title: 'Recent Expenses',
            subtitle: 'No expenses yet. Tap Add to create your first one.',
            icon: Icons.receipt_long,
          )
        else
          ...expenses.map((ExpenseItem expense) {
            final GroupMember? creator = _memberById(group.members, expense.createdBy);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ExpenseDetailPage(expenseId: expense.id),
                    ),
                  );
                },
                child: SectionCard(
                  title: expense.title,
                  subtitle:
                      'Total: ${expense.totalAmount.toStringAsFixed(2)} | By: ${creator?.name ?? 'Unknown'}',
                  icon: Icons.receipt_long,
                ),
              ),
            );
          }),
      ],
    );
  }
}

GroupMember? _memberById(List<GroupMember> members, String id) {
  for (final GroupMember member in members) {
    if (member.id == id) {
      return member;
    }
  }
  return null;
}

class _HeroBanner extends StatelessWidget {
  const _HeroBanner({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          colors: <Color>[
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Colors.white.withValues(alpha: 0.9)),
          ),
        ],
      ),
    );
  }
}

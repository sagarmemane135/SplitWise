import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/state/app_state.dart';
import '../../../../domain/entities/group.dart';
import '../../../debts/presentation/pages/debts_page.dart';
import '../../../expenses/presentation/pages/add_expense_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../shares/presentation/pages/shares_page.dart';

class GroupDetailsPage extends StatelessWidget {
  const GroupDetailsPage({super.key, required this.group});

  final ExpenseGroup group;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(group.name),
          actions: <Widget>[
            IconButton(
              icon: const Icon(Icons.group),
              tooltip: 'Group Members',
              onPressed: () => _showMembers(context, group),
            ),
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: 'Share Invite',
              onPressed: () => _copyInviteLink(context),
            ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(text: 'Expenses'),
              Tab(text: 'Balances'),
              Tab(text: 'Settle Up'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            ExpensesPage(),
            SharesPage(),
            DebtsPage(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AddExpensePage(),
                fullscreenDialog: true,
              ),
            );
          },
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  void _showMembers(BuildContext context, ExpenseGroup group) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return ListView(
          padding: const EdgeInsets.symmetric(vertical: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                '${group.members.length} Members',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            ...group.members.map((member) => ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                  leading: CircleAvatar(
                    child: Text(member.name.isNotEmpty ? member.name.substring(0, 1).toUpperCase() : '?'),
                  ),
                  title: Text(member.name),
                  subtitle: Text(member.role.name),
                )),
          ],
        );
      },
    );
  }

  Future<void> _copyInviteLink(BuildContext context) async {
    final AppStateController appState = AppStateScope.of(context);
    final String? link = appState.buildInviteLinkForActiveGroup();
    if (link == null) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite link copied.')),
      );
    }
  }
}

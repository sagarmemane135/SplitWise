import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';

import 'package:share_plus/share_plus.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/utils/export.dart';
import '../../../../core/utils/pdf_generator.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';
import '../../../debts/presentation/pages/debts_page.dart';
import '../../../expenses/presentation/pages/add_expense_page.dart';
import '../../../expenses/presentation/pages/expenses_page.dart';
import '../../../shares/presentation/pages/shares_page.dart';
import '../../../activity/presentation/pages/group_activity_tab.dart';

class GroupDetailsPage extends StatelessWidget {
  const GroupDetailsPage({super.key, required this.group});

  final ExpenseGroup group;

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);

    // Check if current user is admin of this group
    final String? myUserId = appState.localProfileUserId;
    final bool isAdmin = myUserId != null &&
        group.members.any((GroupMember m) => m.id == myUserId && m.role == MemberRole.admin);

    return DefaultTabController(
      length: 4,
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
              onPressed: () => _shareInviteLink(context),
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              tooltip: 'Export PDF',
              onPressed: () => _downloadPDFReport(context, group),
            ),
            if (isAdmin)
              IconButton(
                icon: const Icon(Icons.delete_forever_rounded),
                tooltip: 'Delete Group',
                color: Colors.red,
                onPressed: () => _confirmDeleteGroup(context, appState),
              ),
          ],
          bottom: const TabBar(
            tabs: <Widget>[
              Tab(icon: Icon(Icons.receipt_long, size: 18), text: 'Expenses'),
              Tab(icon: Icon(Icons.account_balance_wallet, size: 18), text: 'Balances'),
              Tab(icon: Icon(Icons.handshake_outlined, size: 18), text: 'Settle Up'),
              Tab(icon: Icon(Icons.timeline_rounded, size: 18), text: 'Activity'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            ExpensesPage(),
            SharesPage(),
            DebtsPage(),
            const GroupActivityTab(),
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

  Future<void> _shareInviteLink(BuildContext context) async {
    final AppStateController appState = AppStateScope.of(context);
    final String? link = appState.buildInviteLinkForActiveGroup();
    if (link == null) return;
    
    final String message = 'Hey! Join my Splitwise group "${group.name}" to track our shared expenses and easily settle up: $link';
    
    // Fallback to clipboard if share isn't supported, but share_plus handles that on Web too
    await Share.share(message, subject: 'Join ${group.name} on Splitwise');
  }

  Future<void> _downloadPDFReport(BuildContext context, ExpenseGroup group) async {
    final AppStateController appState = AppStateScope.of(context);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF Report...')),
      );
    }
    
    final Uint8List pdfBytes = await generateGroupReportPdf(
      group: group,
      expenses: appState.activeGroupExpenses,
      balances: appState.activeGroupBalances,
      currencyCode: appState.localCurrencyCode ?? 'USD',
    );
    
    final String filename = 'Splitwise_${group.name.replaceAll(' ', '_')}_Report.pdf';
    downloadFile(filename, pdfBytes, mimeType: 'application/pdf');
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report Downloaded!')),
      );
    }
  }

  Future<void> _confirmDeleteGroup(BuildContext context, AppStateController appState) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          icon: const Icon(Icons.delete_forever_rounded, color: Colors.red, size: 36),
          title: const Text('Delete Group?'),
          content: Text(
            'Are you sure you want to permanently delete "${group.name}"?\n\nThis will remove all expenses, comments and activity history. This action cannot be undone.',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      final String? error = appState.deleteGroup(group.id);
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        // Pop back to the groups list
        Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      }
    }
  }
}

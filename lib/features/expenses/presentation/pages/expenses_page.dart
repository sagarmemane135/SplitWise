import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class ExpensesPage extends StatelessWidget {
  const ExpensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;
    final List<ExpenseItem> expenses = appState.activeGroupExpenses;
    final List<GroupComment> comments = appState.activeGroupComments;

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
        SizedBox(height: 16),
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
          ...expenses.take(5).map((ExpenseItem expense) {
            final GroupMember? creator = _memberById(group.members, expense.createdBy);
            return SectionCard(
              title: expense.title,
              subtitle:
                  'Total: ${expense.totalAmount.toStringAsFixed(2)} | By: ${creator?.name ?? 'Unknown'}',
              icon: Icons.receipt_long,
            );
          }),
        const SectionCard(
          title: 'Comments Feed',
          subtitle: 'Notes from collaborators sync across all peers.',
          icon: Icons.comment,
        ),
        _CommentComposer(appState: appState),
        const SizedBox(height: 8),
        if (comments.isEmpty)
          const SectionCard(
            title: 'No comments yet',
            subtitle: 'Post a quick note to confirm live message sync.',
            icon: Icons.forum_outlined,
          )
        else
          ...comments.take(12).map((GroupComment comment) {
            final GroupMember? author = _memberById(group.members, comment.authorMemberId);
            return SectionCard(
              title: author?.name ?? 'Unknown',
              subtitle: comment.message,
              icon: Icons.chat_bubble_outline,
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
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF0B3B6E), Color(0xFF1565C0)],
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

class _CommentComposer extends StatefulWidget {
  const _CommentComposer({required this.appState});

  final AppStateController appState;

  @override
  State<_CommentComposer> createState() => _CommentComposerState();
}

class _CommentComposerState extends State<_CommentComposer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Write a comment for your group',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            final String? error = widget.appState.addComment(_controller.text);
            if (error == null) {
              _controller.clear();
              return;
            }
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
          },
          child: const Text('Post'),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../domain/entities/expense.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';
import 'add_expense_page.dart';

class ExpenseDetailPage extends StatelessWidget {
  const ExpenseDetailPage({super.key, required this.expenseId});

  final String expenseId;

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;
    final ExpenseItem? expense = _findExpense(appState, expenseId);
    final List<GroupComment> comments = appState.groupCommentsForExpense(expenseId);

    if (group == null || expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Expense Error')),
        body: const Center(child: Text('Expense not found or group missing.')),
      );
    }

    final GroupMember? creator = _memberById(group.members, expense.createdBy);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(expense.title),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Expense',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => AddExpensePage(editExpenseId: expenseId),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          SectionCard(
            title: 'Expense Overview',
            subtitle:
                'Total: ${expense.totalAmount.toStringAsFixed(2)}\nCreated by ${creator?.name ?? 'Unknown'} on ${expense.date.year}-${expense.date.month.toString().padLeft(2, '0')}-${expense.date.day.toString().padLeft(2, '0')}',
            icon: Icons.info_outline,
          ),
          const SizedBox(height: 16),
          const SectionCard(
            title: 'Expense Comments Feed',
            subtitle: 'Discuss this specific expense with your group.',
            icon: Icons.comment,
          ),
          _ExpenseCommentComposer(appState: appState, expenseId: expenseId),
          const SizedBox(height: 8),
          if (comments.isEmpty)
            const SectionCard(
              title: 'No comments yet',
              subtitle: 'Start the discussion down below.',
              icon: Icons.forum_outlined,
            )
          else
            ...comments.map((GroupComment comment) {
              final GroupMember? author = _memberById(group.members, comment.authorMemberId);
              final bool isMe = appState.localProfileUserId == comment.authorMemberId;
              final String name = author?.name ?? 'Unknown';
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    if (!isMe)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
                      ),
                    if (!isMe) const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: isMe ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceVariant,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(16),
                            topRight: const Radius.circular(16),
                            bottomLeft: isMe ? const Radius.circular(16) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(16),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(name, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                              ),
                            Text(
                              comment.message,
                              style: TextStyle(color: isMe ? Theme.of(context).colorScheme.onPrimary : Theme.of(context).colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isMe) const SizedBox(width: 8),
                    if (isMe)
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(name.isNotEmpty ? name.substring(0, 1).toUpperCase() : '?', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onPrimary)),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  ExpenseItem? _findExpense(AppStateController appState, String id) {
    for (final ExpenseItem ex in appState.activeGroupExpenses) {
      if (ex.id == id) {
        return ex;
      }
    }
    return null;
  }

  GroupMember? _memberById(List<GroupMember> members, String id) {
    for (final GroupMember member in members) {
      if (member.id == id) {
        return member;
      }
    }
    return null;
  }
}

class _ExpenseCommentComposer extends StatefulWidget {
  const _ExpenseCommentComposer({required this.appState, required this.expenseId});

  final AppStateController appState;
  final String expenseId;

  @override
  State<_ExpenseCommentComposer> createState() => _ExpenseCommentComposerState();
}

class _ExpenseCommentComposerState extends State<_ExpenseCommentComposer> {
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
            textInputAction: TextInputAction.send,
            onSubmitted: (String val) => _submitComment(),
            decoration: const InputDecoration(
              hintText: 'Write a comment on this expense',
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _submitComment,
          child: const Text('Post'),
        ),
      ],
    );
  }

  void _submitComment() {
    if (_controller.text.trim().isEmpty) return;
    final String? error = widget.appState.addComment(
      expenseId: widget.expenseId,
      message: _controller.text,
    );
    if (error == null) {
      _controller.clear();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }
}

import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../domain/entities/activity_log.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class GroupActivityTab extends StatelessWidget {
  const GroupActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? group = appState.activeGroup;
    final List<ActivityLog> activities = appState.activeGroupActivities;

    if (group == null) return const SizedBox.shrink();

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.timeline_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Activity will appear here as you add\nexpenses and your group members join.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.7),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      itemCount: activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 2),
      itemBuilder: (BuildContext context, int index) {
        final ActivityLog activity = activities[index];
        final GroupMember? member = _memberById(group.members, activity.memberId);
        final String name = member?.name ?? 'Someone';
        final bool isMe = appState.localProfileUserId == activity.memberId;

        return _ActivityTile(
          activity: activity,
          memberName: name,
          isMe: isMe,
        );
      },
    );
  }

  GroupMember? _memberById(List<GroupMember> members, String id) {
    for (final GroupMember m in members) {
      if (m.id == id) return m;
    }
    return null;
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.activity,
    required this.memberName,
    required this.isMe,
  });

  final ActivityLog activity;
  final String memberName;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final _ActivityStyle style = _styleForAction(activity.action, colorScheme);
    final String timeAgo = _formatTimeAgo(activity.timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style.bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: style.borderColor, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Icon badge
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: style.iconBg,
              shape: BoxShape.circle,
            ),
            child: Icon(style.icon, color: style.iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                RichText(
                  text: TextSpan(
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                        ),
                    children: <InlineSpan>[
                      TextSpan(
                        text: isMe ? 'You' : memberName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(text: activity.description),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  timeAgo,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: colorScheme.outline,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  _ActivityStyle _styleForAction(ActivityAction action, ColorScheme colorScheme) {
    switch (action) {
      case ActivityAction.groupCreated:
        return _ActivityStyle(
          icon: Icons.groups_rounded,
          iconColor: Colors.teal,
          iconBg: Colors.teal.withValues(alpha: 0.15),
          bgColor: Colors.teal.withValues(alpha: 0.04),
          borderColor: Colors.teal.withValues(alpha: 0.2),
        );
      case ActivityAction.memberJoined:
        return _ActivityStyle(
          icon: Icons.person_add_rounded,
          iconColor: Colors.green,
          iconBg: Colors.green.withValues(alpha: 0.15),
          bgColor: Colors.green.withValues(alpha: 0.04),
          borderColor: Colors.green.withValues(alpha: 0.2),
        );
      case ActivityAction.memberNameChanged:
        return _ActivityStyle(
          icon: Icons.edit_rounded,
          iconColor: Colors.orange,
          iconBg: Colors.orange.withValues(alpha: 0.15),
          bgColor: Colors.orange.withValues(alpha: 0.04),
          borderColor: Colors.orange.withValues(alpha: 0.2),
        );
      case ActivityAction.expenseAdded:
        return _ActivityStyle(
          icon: Icons.receipt_long_rounded,
          iconColor: colorScheme.primary,
          iconBg: colorScheme.primary.withValues(alpha: 0.15),
          bgColor: colorScheme.primary.withValues(alpha: 0.04),
          borderColor: colorScheme.primary.withValues(alpha: 0.2),
        );
      case ActivityAction.expenseUpdated:
        return _ActivityStyle(
          icon: Icons.sync_rounded,
          iconColor: Colors.blue,
          iconBg: Colors.blue.withValues(alpha: 0.15),
          bgColor: Colors.blue.withValues(alpha: 0.04),
          borderColor: Colors.blue.withValues(alpha: 0.2),
        );
      case ActivityAction.expenseDeleted:
        return _ActivityStyle(
          icon: Icons.delete_outline_rounded,
          iconColor: Colors.red,
          iconBg: Colors.red.withValues(alpha: 0.15),
          bgColor: Colors.red.withValues(alpha: 0.04),
          borderColor: Colors.red.withValues(alpha: 0.2),
        );
      case ActivityAction.settlementRecorded:
        return _ActivityStyle(
          icon: Icons.check_circle_outline_rounded,
          iconColor: Colors.purple,
          iconBg: Colors.purple.withValues(alpha: 0.15),
          bgColor: Colors.purple.withValues(alpha: 0.04),
          borderColor: Colors.purple.withValues(alpha: 0.2),
        );
    }
  }

  String _formatTimeAgo(DateTime dt) {
    final Duration diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _ActivityStyle {
  const _ActivityStyle({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.bgColor,
    required this.borderColor,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color bgColor;
  final Color borderColor;
}

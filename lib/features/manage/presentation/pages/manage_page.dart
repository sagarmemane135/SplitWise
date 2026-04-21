import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';
import '../../../../domain/entities/group.dart';
import '../../../../domain/entities/group_member.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final ExpenseGroup? activeGroup = appState.activeGroup;
    final GroupMember? activeIdentity = appState.activeIdentity;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        SectionCard(
          title: 'Local profile',
          subtitle:
              '${appState.localProfileName ?? 'Not set'} (${appState.localCurrencyCode})\nThis identity is reused for create/join operations.',
          icon: Icons.account_circle,
        ),
        SectionCard(
          title: 'Groups',
          subtitle: 'Create, switch, and delete groups from this section.',
          icon: Icons.groups,
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Create group',
            onPressed: () => _showCreateGroupDialog(context, appState),
          ),
        ),
        if (appState.groups.isNotEmpty)
          DropdownButtonFormField<String>(
            initialValue: activeGroup?.id,
            decoration: const InputDecoration(
              labelText: 'Active group',
              border: OutlineInputBorder(),
            ),
            items: appState.groups
                .map(
                  (ExpenseGroup group) => DropdownMenuItem<String>(
                    value: group.id,
                    child: Text(group.name),
                  ),
                )
                .toList(),
            onChanged: (String? groupId) {
              if (groupId != null) {
                appState.setActiveGroup(groupId);
              }
            },
          ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: appState.groups.length <= 1 || activeGroup == null
              ? null
              : () => _confirmDeleteGroup(context, appState, activeGroup),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Delete active group'),
        ),
        if (appState.groups.length <= 1)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text('Create another group before deleting this one.'),
          ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Identity & Roles',
          subtitle: activeIdentity == null
              ? 'Your profile is not yet part of this group. Join via invite link.'
              : 'Current identity (from local profile): ${activeIdentity.name} (${activeIdentity.role.name}).',
          icon: Icons.badge,
        ),
        const SizedBox(height: 20),
        const Divider(),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Member onboarding policy',
          subtitle:
              'Admins cannot add users by name. Members must join only through invite/join links and their names come from local profile.',
          icon: Icons.policy,
        ),
        if (activeGroup != null)
          ...activeGroup.members.map(
            (GroupMember member) => Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(member.name.isEmpty ? '?' : member.name.substring(0, 1).toUpperCase()),
                ),
                title: Text(member.name),
                subtitle: Text('Role: ${member.role.name}'),
                trailing: const Icon(Icons.link),
              ),
            ),
          ),
        const SizedBox(height: 12),
        SectionCard(
          title: 'Collaboration',
          subtitle:
              'Status: ${appState.collaborationReady ? 'Ready' : 'Initializing'} | Host Peer: ${appState.localPeerId ?? '-'} | Connected: ${appState.connectedPeerCount}',
          icon: Icons.wifi_tethering,
        ),
        const Padding(
          padding: EdgeInsets.only(top: 8, bottom: 8),
          child: Text(
            'Flow: Sharing is automatic. Share the invite link and anyone with that link can join directly.',
          ),
        ),
        if (appState.collaborationError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              appState.collaborationError!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            FilledButton.tonalIcon(
              onPressed: (activeGroup == null || !appState.isHostingSession || appState.localPeerId == null)
                  ? null
                  : () => _showInviteLinkDialog(context, appState),
              icon: const Icon(Icons.link),
              label: const Text('Share invite link'),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _showJoinLinkDialog(context, appState),
              icon: const Icon(Icons.login),
              label: const Text('Paste/open invite link'),
            ),
          ],
        ),
        const SectionCard(
          title: 'Export & Reset',
          subtitle: 'PDF export and full reset action will be connected in next iteration.',
          icon: Icons.picture_as_pdf,
        ),
      ],
    );
  }

  Future<void> _showCreateGroupDialog(BuildContext context, AppStateController appState) async {
    final TextEditingController groupController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Create group'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: groupController,
                    decoration: const InputDecoration(labelText: 'Group name'),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Admin will be set as ${appState.localProfileName ?? 'your local profile'}.',
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final String? error = appState.createGroup(
                      groupName: groupController.text,
                    );
                    if (error == null) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Group created.')),
                      );
                    } else {
                      setState(() {
                        errorText = error;
                      });
                    }
                  },
                  child: const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _confirmDeleteGroup(
    BuildContext context,
    AppStateController appState,
    ExpenseGroup group,
  ) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete group'),
          content: Text('Delete "${group.name}"? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton.tonal(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    if (!context.mounted) {
      return;
    }

    final String? error = appState.deleteGroup(group.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Group deleted.')),
    );
  }

  Future<void> _showInviteLinkDialog(BuildContext context, AppStateController appState) async {
    final String? link = appState.buildInviteLinkForActiveGroup();
    if (link == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select or create a group first.')),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Invite link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text('Share this link with users to join this group:'),
              const SizedBox(height: 10),
              SelectableText(link),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: link));
                if (!context.mounted) {
                  return;
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite link copied.')),
                );
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copy'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showJoinLinkDialog(BuildContext context, AppStateController appState) async {
    final TextEditingController linkController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Join via link'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: linkController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Paste invite link',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(errorText!, style: const TextStyle(color: Colors.red)),
                    ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final JoinLinkResult result = appState.joinGroupViaLink(linkController.text);
                    if (result.success) {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(result.message)),
                      );
                    } else {
                      setState(() {
                        errorText = result.message;
                      });
                    }
                  },
                  child: const Text('Join'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

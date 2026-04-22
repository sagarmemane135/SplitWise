import 'package:flutter/material.dart';

import '../../../../core/state/app_state.dart';
import '../../../../core/widgets/section_card.dart';

class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                const SizedBox(height: 24),
                CircleAvatar(
                  radius: 48,
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  child: Text(
                    appState.localProfileName?.isNotEmpty == true
                        ? appState.localProfileName!.substring(0, 1).toUpperCase()
                        : '?',
                    style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  appState.localProfileName ?? 'Unknown User',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Default Currency: ${appState.localCurrencyCode ?? 'None'}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SettingsGroup(
            title: 'PREFERENCES',
            children: <Widget>[
              _SettingsTile(
                icon: Icons.person_outline,
                title: 'Account Settings',
                subtitle: 'Manage your name and identity',
                onTap: () => _showEditProfileDialog(context, appState),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            title: 'NETWORK & DIAGNOSTICS',
            children: <Widget>[
              _SettingsTile(
                icon: Icons.wifi_tethering,
                title: 'Host ID',
                subtitle: appState.localPeerId ?? '-',
              ),
              _SettingsTile(
                icon: appState.collaborationReady ? Icons.check_circle_outline : Icons.pending_outlined,
                title: 'Connection Status',
                subtitle: appState.collaborationReady ? 'Ready' : 'Initializing',
                iconColor: appState.collaborationReady ? Colors.green : Colors.orange,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditProfileDialog(BuildContext context, AppStateController appState) async {
    final TextEditingController nameController = TextEditingController(text: appState.localProfileName ?? '');
    final TextEditingController currencyController = TextEditingController(text: appState.localCurrencyCode);
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Display name', hintText: 'Enter your name'),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: currencyController,
                    decoration: const InputDecoration(labelText: 'Default Currency (e.g. INR)'),
                    textCapitalization: TextCapitalization.characters,
                  ),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
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
                  onPressed: () async {
                    final String? error = await appState.saveLocalProfile(
                      displayName: nameController.text,
                      currencyCode: currencyController.text,
                    );
                    if (error == null) {
                      if (context.mounted) Navigator.of(context).pop();
                    } else {
                      setState(() => errorText = error);
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
            child: Text(
              title,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Theme.of(context).colorScheme.surfaceVariant),
          ),
          child: Column(
            children: children.asMap().entries.map((entry) {
              final int index = entry.key;
              final Widget child = entry.value;
              if (index == children.length - 1) {
                return child;
              }
              return Column(
                children: <Widget>[
                  child,
                  Divider(height: 1, indent: 56, color: Theme.of(context).colorScheme.surfaceVariant),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final Color actualIconColor = iconColor ?? Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16), // Simplification since clipping is complex, just round it
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: actualIconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: actualIconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: titleColor ?? Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron) const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }
}

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
          const SectionCard(
            title: 'Identity & Roles',
            subtitle: 'You participate in groups under this name. Admins cannot change your name.',
            icon: Icons.shield,
          ),
          SectionCard(
            title: 'Network Collaboration',
            subtitle:
                'Host ID: ${appState.localPeerId ?? '-'}\nStatus: ${appState.collaborationReady ? 'Ready' : 'Initializing'}',
            icon: Icons.wifi_tethering,
          ),
          const SizedBox(height: 32),
          const SectionCard(
            title: 'Export & Diagnostics',
            subtitle: 'Data portability options will be added in future updates.',
            icon: Icons.data_usage,
          ),
        ],
      ),
    );
  }
}

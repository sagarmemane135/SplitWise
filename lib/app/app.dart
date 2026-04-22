import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/state/app_state.dart';
import '../features/groups/presentation/pages/groups_page.dart';
import '../features/manage/presentation/pages/manage_page.dart';
import '../features/onboarding/presentation/pages/profile_setup_page.dart';
import 'theme/app_theme.dart';

class SplitEaseApp extends StatelessWidget {
  const SplitEaseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      child: MaterialApp(
        title: 'SplitEase',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        onGenerateRoute: (RouteSettings settings) {
          if (settings.name != null && settings.name!.startsWith('/join')) {
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const AppRootGate(),
            );
          }
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: '/'),
            builder: (_) => const AppRootGate(),
          );
        },
      ),
    );
  }
}

class AppRootGate extends StatefulWidget {
  const AppRootGate({super.key});

  @override
  State<AppRootGate> createState() => _AppRootGateState();
}

class _AppRootGateState extends State<AppRootGate> {
  bool _handledLaunchLink = false;
  String? _pendingLaunchJoinUrl;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      final String launchUrl = Uri.base.toString();
      if (launchUrl.contains('groupId=') &&
          (launchUrl.contains('hostPeerId=') || launchUrl.contains('token='))) {
        _pendingLaunchJoinUrl = launchUrl;
      }
    }
  }

  void _tryHandleWebLaunchJoinLink(AppStateController appState) {
    if (!kIsWeb || _handledLaunchLink || !appState.hasLocalProfile) {
      return;
    }

    final String? launchUrl = _pendingLaunchJoinUrl;
    if (launchUrl == null) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledLaunchLink) {
        return;
      }
      final JoinLinkResult result = appState.joinGroupViaLink(launchUrl);
      _handledLaunchLink = true;
      _pendingLaunchJoinUrl = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);

    if (!appState.isInitialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!appState.hasLocalProfile) {
      return ProfileSetupPage(
        onSubmit: ({required String displayName, required String currencyCode}) {
          return appState.saveLocalProfile(
            displayName: displayName,
            currencyCode: currencyCode,
          );
        },
      );
    }

    _tryHandleWebLaunchJoinLink(appState);

    return const SplitEaseShellPage();
  }
}

class SplitEaseShellPage extends StatefulWidget {
  const SplitEaseShellPage({super.key});

  @override
  State<SplitEaseShellPage> createState() => _SplitEaseShellPageState();
}

class _SplitEaseShellPageState extends State<SplitEaseShellPage> {
  int _currentIndex = 0;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(2, (_) => GlobalKey<NavigatorState>());

  static const List<String> _titles = <String>[
    'Groups',
    'Account',
  ];

  static const List<Widget> _pages = <Widget>[
    GroupsPage(),
    ManagePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: _currentIndex,
        children: _navigatorKeys.asMap().entries.map((entry) {
          final int i = entry.key;
          return Navigator(
            key: entry.value,
            onGenerateRoute: (RouteSettings settings) {
              return MaterialPageRoute<void>(
                builder: (_) => _pages[i],
              );
            },
          );
        }).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.group_outlined), selectedIcon: Icon(Icons.group), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Account'),
        ],
        onDestinationSelected: (int index) {
          setState(() {
            if (_currentIndex == index) {
              // If tapping the same tab, pop to root of that tab's navigator
              _navigatorKeys[index].currentState?.popUntil((Route<dynamic> route) => route.isFirst);
            }
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

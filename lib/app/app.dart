import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../core/state/app_state.dart';
import '../features/debts/presentation/pages/debts_page.dart';
import '../features/expenses/presentation/pages/add_expense_page.dart';
import '../features/expenses/presentation/pages/expenses_page.dart';
import '../features/manage/presentation/pages/manage_page.dart';
import '../features/onboarding/presentation/pages/profile_setup_page.dart';
import '../features/shares/presentation/pages/shares_page.dart';
import 'theme/app_theme.dart';

class SplitwiseApp extends StatelessWidget {
  const SplitwiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AppStateScope(
      child: MaterialApp(
        title: 'Splitwise',
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

    return const SplitwiseShellPage();
  }
}

class SplitwiseShellPage extends StatefulWidget {
  const SplitwiseShellPage({super.key});

  @override
  State<SplitwiseShellPage> createState() => _SplitwiseShellPageState();
}

class _SplitwiseShellPageState extends State<SplitwiseShellPage> {
  int _currentIndex = 0;
  late final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  static const List<String> _titles = <String>[
    'Expenses',
    'Shares',
    'Add',
    'Debts',
    'Manage',
  ];

  static const List<Widget> _pages = <Widget>[
    ExpensesPage(),
    SharesPage(),
    AddExpensePage(),
    DebtsPage(),
    ManagePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final AppStateController appState = AppStateScope.of(context);
    final bool hasGroup = appState.activeGroup != null;

    final List<String> activeTitles = hasGroup ? _titles : const <String>['Manage'];
    final List<Widget> activePages = hasGroup ? _pages : const <Widget>[ManagePage()];
    final List<NavigationDestination> activeDestinations = hasGroup
        ? const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
            NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Shares'),
            NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Add'),
            NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Debts'),
            NavigationDestination(icon: Icon(Icons.settings), label: 'Manage'),
          ]
        : const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.settings), label: 'Manage'),
          ];

    int displayIndex = _currentIndex;
    if (displayIndex >= activePages.length) {
      displayIndex = 0;
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(
        index: displayIndex,
        children: _navigatorKeys.asMap().entries.map((entry) {
          final int i = entry.key;
          return Navigator(
            key: entry.value,
            onGenerateRoute: (RouteSettings settings) {
              return MaterialPageRoute<void>(
                builder: (_) => activePages[i],
              );
            },
          );
        }).toList(),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: displayIndex,
        destinations: activeDestinations,
        onDestinationSelected: (int index) {
          setState(() {
            if (!hasGroup) {
              _currentIndex = 0;
            } else {
              if (_currentIndex == index) {
                // If tapping the same tab, pop to root of that tab's navigator
                _navigatorKeys[index].currentState?.popUntil((Route<dynamic> route) => route.isFirst);
              }
              _currentIndex = index;
            }
          });
        },
      ),
    );
  }
}

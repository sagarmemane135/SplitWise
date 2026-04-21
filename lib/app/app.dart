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
    return MaterialApp(
      title: 'Splitwise',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppStateScope(child: AppRootGate()),
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

  void _tryHandleWebLaunchJoinLink(AppStateController appState) {
    if (!kIsWeb || _handledLaunchLink || !appState.hasLocalProfile) {
      return;
    }

    final String currentUrl = Uri.base.toString();
    if (!currentUrl.contains('groupId=') || !currentUrl.contains('token=')) {
      _handledLaunchLink = true;
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _handledLaunchLink) {
        return;
      }
      final JoinLinkResult result = appState.joinGroupViaLink(currentUrl);
      _handledLaunchLink = true;
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
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_currentIndex])),
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.receipt_long), label: 'Expenses'),
          NavigationDestination(icon: Icon(Icons.pie_chart), label: 'Shares'),
          NavigationDestination(icon: Icon(Icons.add_circle_outline), label: 'Add'),
          NavigationDestination(icon: Icon(Icons.swap_horiz), label: 'Debts'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Manage'),
        ],
        onDestinationSelected: (int index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
}

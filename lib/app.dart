import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/home/home_screen.dart';
import 'ui/library/library_screen.dart';
import 'ui/practice/practice_screen.dart';
import 'ui/theme/atlas_theme.dart';

class KjcApp extends StatelessWidget {
  const KjcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KJC 7-Day Trip',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AtlasTheme.green,
          primary: AtlasTheme.green,
          surface: AtlasTheme.paper,
        ),
        scaffoldBackgroundColor: AtlasTheme.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AtlasTheme.background,
          foregroundColor: AtlasTheme.heading,
          surfaceTintColor: Colors.transparent,
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AtlasTheme.paper,
          indicatorColor: AtlasTheme.selected,
          surfaceTintColor: Colors.transparent,
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => TextStyle(
              color: states.contains(WidgetState.selected)
                  ? AtlasTheme.green
                  : AtlasTheme.muted,
              fontSize: 12,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              color: states.contains(WidgetState.selected)
                  ? AtlasTheme.green
                  : AtlasTheme.muted,
            ),
          ),
        ),
        dividerColor: AtlasTheme.line,
        useMaterial3: true,
      ),
      home: const _RootScaffold(),
    );
  }
}

class _RootScaffold extends StatefulWidget {
  const _RootScaffold();

  @override
  State<_RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<_RootScaffold> {
  var _index = 0;
  final _navigatorKeys = List<GlobalKey<NavigatorState>>.generate(
    3,
    (_) => GlobalKey<NavigatorState>(),
  );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: AtlasTheme.background,
        body: IndexedStack(
          index: _index,
          children: [
            _TabNavigator(
              navigatorKey: _navigatorKeys[0],
              root: const HomeScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[1],
              root: const PracticeScreen(),
            ),
            _TabNavigator(
              navigatorKey: _navigatorKeys[2],
              root: const LibraryScreen(),
            ),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          height: 75,
          selectedIndex: _index,
          onDestinationSelected: _selectTab,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.map_outlined),
              selectedIcon: Icon(Icons.map_outlined),
              label: 'Travel',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble_outline),
              label: 'Practice',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_border),
              selectedIcon: Icon(Icons.bookmark_border),
              label: 'Saved',
            ),
          ],
        ),
      ),
    );
  }

  void _selectTab(int index) {
    if (index == _index) {
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
      return;
    }
    setState(() => _index = index);
  }

  Future<void> _handleBack() async {
    final handled = await _navigatorKeys[_index].currentState?.maybePop();
    if (handled == true || !mounted) return;
    if (_index != 0) {
      setState(() => _index = 0);
      return;
    }
    await SystemNavigator.pop();
  }
}

class _TabNavigator extends StatelessWidget {
  const _TabNavigator({required this.navigatorKey, required this.root});

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget root;

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => root),
    );
  }
}

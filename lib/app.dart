import 'package:flutter/material.dart';

import 'ui/home/home_screen.dart';
import 'ui/library/library_screen.dart';

class KjcApp extends StatelessWidget {
  const KjcApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KJC 7-Day Trip',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2E6B5E)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), LibraryScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff),
            label: 'Travel',
          ),
          NavigationDestination(
            icon: Icon(Icons.collections_bookmark),
            label: 'Saved',
          ),
        ],
      ),
    );
  }
}

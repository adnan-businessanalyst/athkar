import 'package:flutter/material.dart';

import 'athkar_screen.dart';
import 'counters_screen.dart';
import 'prayers_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _pages = [
    PrayersScreen(),
    AthkarScreen(),
    CountersScreen(),
    SettingsScreen(),
  ];

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.mosque_outlined),
      selectedIcon: Icon(Icons.mosque),
      label: 'الصلاة',
    ),
    NavigationDestination(
      icon: Icon(Icons.menu_book_outlined),
      selectedIcon: Icon(Icons.menu_book),
      label: 'الأذكار',
    ),
    NavigationDestination(
      icon: Icon(Icons.touch_app_outlined),
      selectedIcon: Icon(Icons.touch_app),
      label: 'العداد',
    ),
    NavigationDestination(
      icon: Icon(Icons.settings_outlined),
      selectedIcon: Icon(Icons.settings),
      label: 'الإعدادات',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      body: Row(
        children: [
          if (wide)
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (index) {
                setState(() => _index = index);
              },
              labelType: NavigationRailLabelType.all,
              destinations: [
                for (final destination in _destinations)
                  NavigationRailDestination(
                    icon: destination.icon,
                    selectedIcon: destination.selectedIcon,
                    label: Text(destination.label),
                  ),
              ],
            ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: wide
                        ? constraints.maxWidth.clamp(0, 1100)
                        : constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: IndexedStack(index: _index, children: _pages),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (index) {
                setState(() => _index = index);
              },
              destinations: _destinations,
            ),
    );
  }
}

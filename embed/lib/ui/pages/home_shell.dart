import 'package:flutter/material.dart';

import 'account_page.dart';
import 'activity_page.dart';
import 'dashboard_page.dart';
import 'schedule_page.dart';

enum HomeTab { dashboard, schedule, activity, account }

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  /// Memungkinkan halaman di dalam shell berpindah tab.
  static HomeShellState? of(BuildContext context) =>
      context.findAncestorStateOfType<HomeShellState>();

  @override
  State<HomeShell> createState() => HomeShellState();
}

class HomeShellState extends State<HomeShell> {
  HomeTab _tab = HomeTab.dashboard;

  void open(HomeTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab.index,
        children: const [
          DashboardPage(),
          SchedulePage(),
          ActivityPage(),
          AccountPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab.index,
        onDestinationSelected: (index) => open(HomeTab.values[index]),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.water_outlined),
            selectedIcon: Icon(Icons.water_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded),
            label: 'Jadwal',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            selectedIcon: Icon(Icons.history_rounded),
            label: 'Riwayat',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Akun',
          ),
        ],
      ),
    );
  }
}

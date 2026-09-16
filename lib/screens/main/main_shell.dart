import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../home/dashboard_screen.dart';
import '../placeholder/placeholder_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  void _goToTab(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(onQuickAction: _goToTab),
      const PlaceholderScreen(
        title: 'Safety Map',
        icon: Icons.map_outlined,
        phaseNote: 'The safety map gets built in Phase 6.',
      ),
      const PlaceholderScreen(
        title: 'AI Assistant',
        icon: Icons.chat_bubble_outline,
        phaseNote: 'The AI safety assistant gets built in Phase 5.',
      ),
      const PlaceholderScreen(
        title: 'Safety',
        icon: Icons.health_and_safety_outlined,
        phaseNote: 'Safety tips and your safety plan get built in Phase 8.',
      ),
      const PlaceholderScreen(
        title: 'Profile',
        icon: Icons.person_outline,
        phaseNote: 'Profile and settings get built in Phase 3.',
      ),
    ];

    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _goToTab,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Map',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Assistant',
          ),
          NavigationDestination(
            icon: Icon(Icons.health_and_safety_outlined),
            selectedIcon: Icon(Icons.health_and_safety),
            label: 'Safety',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

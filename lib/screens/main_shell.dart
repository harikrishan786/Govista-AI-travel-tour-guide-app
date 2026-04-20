// lib/screens/main_shell.dart

import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'hotels_screen.dart';
import 'ai_guide_screen.dart';
import 'profile_screen.dart';

class MainShell extends StatefulWidget {
  final int initialIndex;
  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;

  // GlobalKeys to call refresh on screens
  final _homeKey = GlobalKey<HomeScreenState>();
  final _profileKey = GlobalKey<ProfileScreenState>();

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _screens = [
      HomeScreen(key: _homeKey),
      const TripsScreen(),
      const HotelsScreen(),
      const AIGuideScreen(),
      ProfileScreen(key: _profileKey),
    ];
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);

    // Refresh profile data when switching to profile tab
    if (index == 4) {
      _profileKey.currentState?.refreshData();
    }
    // Refresh home when switching to home tab
    if (index == 0) {
      _homeKey.currentState?.refreshUnreadCount();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _currentIndex != 0) {
          setState(() => _currentIndex = 0);
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: AppBottomNavBar(
          selectedIndex: _currentIndex,
          onTap: _onTabTapped,
        ),
      ),
    );
  }
}
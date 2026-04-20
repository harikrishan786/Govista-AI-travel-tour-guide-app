import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ============================================
// THEME PROVIDER - Manages dark/light mode
// ============================================
class ThemeProvider extends ChangeNotifier {
  bool _isDarkMode = false;
  bool get isDarkMode => _isDarkMode;

  void toggleTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void setDarkMode(bool value) {
    _isDarkMode = value;
    notifyListeners();
  }
}

// ============================================
// APP COLORS - Use this in all your screens
// ============================================
class AppColors {
  // Primary colors (same in both modes)
  static const Color primary = Color(0xFF1B8A6B);
  static const Color primaryLight = Color(0xFFE8F5F1);
  static const Color accent = Color(0xFFE8A54B);

  // ═══ ALL METHODS NOW USE listen:true ═══
  // This ensures widgets rebuild when theme changes

  static Color background(BuildContext context) =>
      _isDark(context) ? const Color(0xFF1A1A2E) : Colors.white;

  static Color surface(BuildContext context) =>
      _isDark(context) ? const Color(0xFF252542) : Colors.white;

  static Color card(BuildContext context) =>
      _isDark(context) ? const Color(0xFF252542) : Colors.white;

  static Color cardAlt(BuildContext context) =>
      _isDark(context) ? const Color(0xFF2D2D4A) : Colors.grey[50]!;

  static Color textPrimary(BuildContext context) =>
      _isDark(context) ? Colors.white : Colors.black87;

  static Color textSecondary(BuildContext context) =>
      _isDark(context) ? Colors.grey[400]! : Colors.grey[600]!;

  static Color textHint(BuildContext context) =>
      _isDark(context) ? Colors.grey[600]! : Colors.grey[400]!;

  static Color divider(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3A3A5A) : Colors.grey[200]!;

  static Color border(BuildContext context) =>
      _isDark(context) ? const Color(0xFF3A3A5A) : Colors.grey[200]!;

  static Color searchBar(BuildContext context) =>
      _isDark(context) ? const Color(0xFF252542) : Colors.grey[100]!;

  static Color navBar(BuildContext context) =>
      _isDark(context) ? const Color(0xFF252542) : Colors.white;

  static Color navInactive(BuildContext context) =>
      _isDark(context) ? Colors.grey[600]! : Colors.grey[400]!;

  static Color shadow(BuildContext context) => _isDark(context)
      ? Colors.black.withOpacity(0.3)
      : Colors.black.withOpacity(0.08);

  static Color iconPrimary(BuildContext context) =>
      _isDark(context) ? Colors.white : Colors.black87;

  static Color iconSecondary(BuildContext context) =>
      _isDark(context) ? Colors.grey[400]! : Colors.grey[600]!;

  // ═══ FIXED: Now uses listen:true so widgets auto-rebuild ═══
  static bool _isDark(BuildContext context) {
    try {
      return Provider.of<ThemeProvider>(context).isDarkMode;
    } catch (e) {
      return false;
    }
  }

  // Kept for backward compatibility
  static bool isDarkMode(BuildContext context) {
    try {
      return Provider.of<ThemeProvider>(context).isDarkMode;
    } catch (e) {
      return false;
    }
  }
}

// ============================================
// REUSABLE BOTTOM NAV BAR
// ============================================
class AppBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTap;

  const AppBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.navBar(context),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(context, 0, Icons.explore_outlined, Icons.explore, 'Explore'),
              _buildNavItem(context, 1, Icons.map_outlined, Icons.map, 'Trips'),
              _buildNavItem(context, 2, Icons.luggage_outlined, Icons.luggage, 'Book'),
              _buildNavItem(context, 3, Icons.auto_awesome_outlined, Icons.auto_awesome, 'AI Guide'),
              _buildNavItem(context, 4, Icons.person_outline, Icons.person, 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index, IconData icon, IconData activeIcon, String label) {
    final isSelected = selectedIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSelected ? activeIcon : icon,
            color: isSelected ? AppColors.primary : AppColors.navInactive(context),
            size: 26,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isSelected ? AppColors.primary : AppColors.navInactive(context),
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================
// NAVIGATION HELPER
// ============================================
class AppNavigator {
  static void goToHome(BuildContext context) => Navigator.pushReplacementNamed(context, '/home');
  static void goToTrips(BuildContext context) => Navigator.pushReplacementNamed(context, '/trips');
  static void goToAIGuide(BuildContext context) => Navigator.pushReplacementNamed(context, '/ai-guide');
  static void goToProfile(BuildContext context) => Navigator.pushReplacementNamed(context, '/profile');
  static void goToSettings(BuildContext context) => Navigator.pushNamed(context, '/settings');
}
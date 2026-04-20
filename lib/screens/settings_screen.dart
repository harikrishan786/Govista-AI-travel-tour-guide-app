import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../services/notification_service.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'hotels_screen.dart';
import 'ai_guide_screen.dart';
import 'auth_screen.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final int _selectedNavIndex = 4;
  final NotificationService _notifService = NotificationService();

  String get userName =>
      FirebaseAuth.instance.currentUser?.displayName ?? "User";
  String get userEmail => FirebaseAuth.instance.currentUser?.email ?? "";
  String? get userAvatarUrl => FirebaseAuth.instance.currentUser?.photoURL;
  String membershipStatus = "collecting moments, not things";

  bool _pushNotifications = true;
  final String _offlineMapsSize = "2.4 GB";
  String _voiceSelection = "Aurora (Soft Melodic)";
  String _assistantLanguage = "English (United Kingdom)";
  String _personality = "Adventurous & Witty";

  @override
  void initState() {
    super.initState();
    FirebaseAuth.instance.currentUser?.reload();
    _loadNotifPreference();
  }

  Future<void> _loadNotifPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _pushNotifications = prefs.getBool('push_notifications') ?? true;
    });
  }

  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('push_notifications', value);
    setState(() => _pushNotifications = value);

    if (value) {
      // Send a test notification to confirm it works
      await _notifService.showPushNotification(
        title: '🔔 Notifications Enabled!',
        body: 'You\'ll receive travel tips, trip reminders and weather alerts.',
        id: 99,
      );
    }
  }

  void _onBackTapped() => Navigator.pop(context);

  void _onEditProfileTapped() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditProfileScreen()),
    );
    if (result == true) {
      await FirebaseAuth.instance.currentUser?.reload();
      setState(() {});
    }
  }

  void _onChangePasswordTapped() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ChangePasswordScreen()),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Out', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Text('Are you sure you want to log out?',
          style: TextStyle(color: AppColors.textSecondary(context))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const AuthScreen()),
                (route) => false,
              );
            },
            child: const Text('Log Out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSelectionDialog(
    String title, List<String> options, String currentValue, Function(String) onSelect,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: TextStyle(color: AppColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((option) => ListTile(
            title: Text(option, style: TextStyle(color: AppColors.textPrimary(context))),
            trailing: currentValue == option
                ? const Icon(Icons.check, color: AppColors.primary) : null,
            onTap: () { onSelect(option); Navigator.pop(ctx); },
          )).toList(),
        ),
      ),
    );
  }

  void _handleNavTap(int index) {
    if (index == _selectedNavIndex) { Navigator.pop(context); return; }
    switch (index) {
      case 0: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen())); break;
      case 1: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const TripsScreen())); break;
      case 2: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HotelsScreen())); break;
      case 3: Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AIGuideScreen())); break;
      case 4: Navigator.pop(context); break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: _onBackTapped,
          child: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        ),
        title: Text('Settings', style: TextStyle(
          color: AppColors.textPrimary(context), fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildUserSection(context),
            const SizedBox(height: 30),
            _buildSectionTitle('ACCOUNT', context),
            const SizedBox(height: 12),
            _buildAccountSection(context),
            const SizedBox(height: 30),
            _buildSectionTitle('AI ASSISTANT', context),
            const SizedBox(height: 12),
            _buildAISection(context),
            const SizedBox(height: 30),
            _buildSectionTitle('APP SETTINGS', context),
            const SizedBox(height: 12),
            _buildAppSettings(context, themeProvider),
            const SizedBox(height: 30),
            _buildSectionTitle('SUPPORT', context),
            const SizedBox(height: 12),
            _buildSupportSection(context),
            const SizedBox(height: 30),
            _buildVersionInfo(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: AppBottomNavBar(
        selectedIndex: _selectedNavIndex,
        onTap: _handleNavTap,
      ),
    );
  }

  Widget _buildUserSection(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 2)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: userAvatarUrl != null
                ? Image.network(userAvatarUrl!, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _buildDefaultAvatar())
                : _buildDefaultAvatar(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(userName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context)), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              const Text(
                'collecting moments, not things',
                style: TextStyle(fontSize: 14, color: AppColors.primary)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFFFDE8E8),
      child: const Center(child: Icon(Icons.person, color: Color(0xFFE88B8B), size: 30)),
    );
  }

  Widget _buildSectionTitle(String title, BuildContext context) {
    return Text(title, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textHint(context), letterSpacing: 0.5));
  }

  Widget _buildAccountSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _buildTile(context, Icons.person_outline, 'Edit Profile', onTap: _onEditProfileTapped, showArrow: true),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.lock_outline, 'Change Password', onTap: _onChangePasswordTapped, showArrow: true),
      ]),
    );
  }

  Widget _buildAISection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _buildTile(context, Icons.record_voice_over_outlined, 'Voice selection',
          subtitle: _voiceSelection,
          onTap: () => _showSelectionDialog('Voice Selection',
            ['Aurora (Soft Melodic)', 'Jasper (Energetic)', 'Nova (Professional)'],
            _voiceSelection, (v) => setState(() => _voiceSelection = v)),
          showArrow: true),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.language, 'Assistant Language',
          subtitle: _assistantLanguage,
          onTap: () => _showSelectionDialog('Assistant Language',
            ['English (United Kingdom)', 'English (United States)', 'Hindi', 'Spanish'],
            _assistantLanguage, (v) => setState(() => _assistantLanguage = v)),
          showArrow: true),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.psychology_outlined, 'Personality',
          subtitle: _personality,
          onTap: () => _showSelectionDialog('Personality',
            ['Adventurous & Witty', 'Professional & Informative', 'Friendly & Casual'],
            _personality, (v) => setState(() => _personality = v)),
          showArrow: true),
      ]),
    );
  }

  Widget _buildAppSettings(BuildContext context, ThemeProvider themeProvider) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _buildTile(context, Icons.notifications_outlined, 'Push Notifications',
          trailing: Switch(
            value: _pushNotifications,
            onChanged: _toggleNotifications,
            activeThumbColor: AppColors.primary,
          ),
        ),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.dark_mode_outlined, 'Dark Mode',
          trailing: Switch(
            value: themeProvider.isDarkMode,
            onChanged: (v) => themeProvider.setDarkMode(v),
            activeThumbColor: AppColors.primary,
          ),
        ),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.map_outlined, 'Offline Maps', onTap: () {},
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(_offlineMapsSize, style: TextStyle(color: AppColors.textHint(context), fontSize: 14)),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textHint(context)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildSupportSection(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(16)),
      child: Column(children: [
        _buildTile(context, Icons.help_outline, 'Help Center', onTap: () {},
          trailing: Icon(Icons.open_in_new, color: AppColors.textHint(context), size: 20)),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.verified_user_outlined, 'Privacy Policy', onTap: () {}, showArrow: true),
        Divider(height: 1, color: AppColors.divider(context)),
        _buildTile(context, Icons.logout, 'Log Out',
          iconColor: Colors.red, titleColor: Colors.red,
          onTap: () => _showLogoutDialog(context)),
      ]),
    );
  }

  Widget _buildTile(BuildContext context, IconData icon, String title, {
    String? subtitle, Color? iconColor, Color? titleColor,
    VoidCallback? onTap, Widget? trailing, bool showArrow = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor == Colors.red ? const Color(0xFFFDE8E8) : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor ?? AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500,
                  color: titleColor ?? AppColors.textPrimary(context))),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 13, color: AppColors.primary)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing,
          if (showArrow) Icon(Icons.chevron_right, color: AppColors.textHint(context)),
        ]),
      ),
    );
  }

  Widget _buildVersionInfo(BuildContext context) {
    return Center(
      child: Column(children: [
        Text('GoVista v1.0.0', style: TextStyle(fontSize: 14, color: AppColors.textHint(context))),
        const SizedBox(height: 4),
        Text('DESIGNED FOR EXPLORATION',
          style: TextStyle(fontSize: 10, color: AppColors.textHint(context), letterSpacing: 1)),
      ]),
    );
  }
}
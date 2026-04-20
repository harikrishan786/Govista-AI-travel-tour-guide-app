import 'dart:math';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../widgets/cached_image.dart';
import '../services/firebase_service.dart';
import '../services/itinerary_service.dart';
import '../services/notification_service.dart';
import '../models/destination_model_fixed.dart';
import 'trips_screen.dart';
import 'profile_screen.dart';
import 'ai_guide_screen.dart';
import 'edit_profile_screen.dart';
import 'search_screen.dart';
import 'day_picker_sheet.dart';
import 'itinerary_view_screen.dart';
import 'notification_screen.dart';
import 'hotels_screen.dart';
import '../templates/region_template_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  /// Called by MainShell when home tab is selected
  void refreshUnreadCount() {
    _loadUnreadCount();
  }
  int _selectedIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final ItineraryService _itineraryService = ItineraryService();

  String get userName =>
      FirebaseAuth.instance.currentUser?.displayName ?? "User";
  String? get userAvatarUrl => FirebaseAuth.instance.currentUser?.photoURL;

  final List<IconData> categoryIcons = [
    Icons.hiking,
    Icons.home_outlined,
    Icons.coffee_outlined,
    Icons.temple_hindu_outlined,
    Icons.water_outlined,
  ];

  final List<Map<String, String>> regions = [
    {
      'name': 'Himachal Pradesh',
      'subtitle': 'The Land of Gods',
      'image': 'assets/images/himachal.jpg',
      'key': 'himachal',
    },
    {
      'name': 'Uttarakhand',
      'subtitle': 'Devbhumi',
      'image': 'assets/images/uttarakhand.jpg',
      'key': 'uttarakhand',
    },
    {
      'name': 'Kashmir',
      'subtitle': 'Paradise on Earth',
      'image': 'assets/images/kashmir.jpg',
      'key': 'kashmir',
    },
    {
      'name': 'Ladakh',
      'subtitle': 'Land of High Passes',
      'image': 'assets/images/ladakh.jpg',
      'key': 'ladakh',
    },
  ];

  // ═══ DYNAMIC ITINERARY SUGGESTIONS ═══
  List<_ItinerarySuggestion> _suggestions = [];
  bool _loadingSuggestions = true;
  bool _isGenerating = false;

  final List<Map<String, dynamic>> _styles = [
    {'label': '3-DAY TREK', 'days': 3, 'icon': Icons.hiking},
    {'label': '2-DAY ESCAPE', 'days': 2, 'icon': Icons.spa},
    {'label': '5-DAY JOURNEY', 'days': 5, 'icon': Icons.explore},
    {'label': '4-DAY ADVENTURE', 'days': 4, 'icon': Icons.paragliding},
    {'label': '1-DAY TRIP', 'days': 1, 'icon': Icons.wb_sunny},
    {'label': '3-DAY RETREAT', 'days': 3, 'icon': Icons.self_improvement},
  ];

  // ═══ NOTIFICATIONS ═══
  final NotificationService _notificationService = NotificationService();
  int _unreadNotifCount = 0;

  @override
  void initState() {
    super.initState();
    _loadItinerarySuggestions();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) setState(() => _unreadNotifCount = count);
  }

  Future<void> _loadItinerarySuggestions() async {
    try {
      final all = await _firebaseService.getAllDestinations();
      if (all.isEmpty) {
        setState(() => _loadingSuggestions = false);
        return;
      }

      final shuffled = List<Destination>.from(all)..shuffle(Random());
      final picked = shuffled.take(4).toList();

      final suggestions = <_ItinerarySuggestion>[];
      for (int i = 0; i < picked.length; i++) {
        final dest = picked[i];
        final style = _styles[i % _styles.length];

        String tagline;
        if (dest.activities.isNotEmpty) {
          final acts = dest.activities.take(3).join(', ');
          tagline = 'Experience $acts in the heart of ${dest.state}.';
        } else if (dest.description.isNotEmpty) {
          tagline = dest.description;
        } else {
          tagline =
              'Discover the hidden beauty of ${dest.name}, ${dest.state}.';
        }

        suggestions.add(
          _ItinerarySuggestion(
            destination: dest,
            title: '${dest.name} ${style['label']}',
            tagline: tagline,
            durationLabel: style['label'] as String,
            days: style['days'] as int,
            icon: style['icon'] as IconData,
          ),
        );
      }

      setState(() {
        _suggestions = suggestions;
        _loadingSuggestions = false;
      });
    } catch (e) {
      print('Error loading suggestions: $e');
      setState(() => _loadingSuggestions = false);
    }
  }

  Future<void> _generateForSuggestion(_ItinerarySuggestion s) async {
    if (_isGenerating) return;
    setState(() => _isGenerating = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Creating your itinerary...',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${s.days} days in ${s.destination.name}',
              style: TextStyle(color: Colors.grey[500]),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    final itinerary = await _itineraryService.generateItinerary(
      cityName: s.destination.name,
      state: s.destination.state,
      days: s.days,
      existingAttractions: s.destination.places.map((p) => p.name).toList(),
      existingActivities: s.destination.activities,
    );

    if (mounted) Navigator.pop(context);
    setState(() => _isGenerating = false);

    if (itinerary != null && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItineraryViewScreen(itinerary: itinerary),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onCustomGenerate(_ItinerarySuggestion s) {
    DayPickerSheet.show(
      context: context,
      cityName: s.destination.name,
      onDaysSelected: (days) {
        final custom = _ItinerarySuggestion(
          destination: s.destination,
          title: s.title,
          tagline: s.tagline,
          durationLabel: '$days-DAY PLAN',
          days: days,
          icon: s.icon,
        );
        _generateForSuggestion(custom);
      },
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  // Navigation handled by MainShell
  void _handleNavTap(int index) {
    if (index == _selectedIndex) return;
    setState(() => _selectedIndex = index);
  }

  void _onRegionTapped(Map<String, String> region) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RegionTemplateScreen(
          regionName: region['name']!,
          regionKey: region['key']!,
          subtitle: region['subtitle']!,
          backgroundImage: region['image'],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildSearchBar(context),
              const SizedBox(height: 24),
              _buildExploreRegions(context),
              const SizedBox(height: 20),
              const SizedBox(height: 24),
              _buildItineraries(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
      // bottomNavigationBar handled by MainShell
    );
  }

  Widget _buildHeader(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final avatarUrl = user?.photoURL;
    final displayName = user?.displayName ?? "User";

    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          ).then((_) => setState(() {})),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.cardAlt(context),
              backgroundImage: avatarUrl != null
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl == null
                  ? Icon(Icons.person, color: AppColors.textSecondary(context))
                  : null,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _getGreeting(),
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary(context),
              ),
            ),
            Text(
              'Hello, $displayName.',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationScreen()),
            );
            _loadUnreadCount();
          },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border(context)),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.notifications_outlined,
                  color: AppColors.primary,
                  size: 24,
                ),
                if (_unreadNotifCount > 0)
                  Positioned(
                    top: -6,
                    right: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        '$_unreadNotifCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SearchScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.searchBar(context),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.textHint(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Ask AI where to go next...',
                style: TextStyle(
                  color: AppColors.textHint(context),
                  fontSize: 16,
                ),
              ),
            ),
            Container(padding: const EdgeInsets.all(8)),
          ],
        ),
      ),
    );
  }

  Widget _buildExploreRegions(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Explore Regions',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const Text(
              'See All',
              style: TextStyle(
                fontSize: 16,
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: regions.length,
            itemBuilder: (context, index) =>
                _buildRegionCard(context, regions[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildRegionCard(BuildContext context, Map<String, String> region) {
    return GestureDetector(
      onTap: () => _onRegionTapped(region),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(context),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                region['image']!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.teal[300]!, Colors.teal[700]!],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.landscape,
                      size: 60,
                      color: Colors.white54,
                    ),
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                  ),
                ),
              ),
              Positioned(
                bottom: 16,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      region['name']!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      region['subtitle']!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // CURATED ITINERARIES — RANDOM FROM FIRESTORE
  // ═══════════════════════════════════════════
  Widget _buildItineraries(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Curated Itineraries',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            GestureDetector(
              onTap: () {
                setState(() => _loadingSuggestions = true);
                _loadItinerarySuggestions();
              },
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 16, color: AppColors.primary),
                  const SizedBox(width: 4),
                  const Text(
                    'Refresh',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        if (_loadingSuggestions)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_suggestions.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    size: 50,
                    color: AppColors.textHint(context),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No destinations available yet.',
                    style: TextStyle(color: AppColors.textHint(context)),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _suggestions.length,
            itemBuilder: (context, index) =>
                _buildSuggestionCard(context, _suggestions[index]),
          ),
      ],
    );
  }

  Widget _buildSuggestionCard(BuildContext context, _ItinerarySuggestion s) {
    final dest = s.destination;
    final hasImage =
        dest.image.isNotEmpty &&
        !dest.image.contains('unsplash.com/photo-1626621341517');

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow(context),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ═══ IMAGE — NOW CACHED ═══
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(20),
                ),
                child: SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: hasImage
                      ? AppCachedImage(
                          url: dest.image,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : _buildGradientBg(dest),
                ),
              ),
              // Duration badge
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(s.icon, color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        s.durationLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Custom days button
              Positioned(
                top: 16,
                right: 16,
                child: GestureDetector(
                  onTap: () => _onCustomGenerate(s),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.edit_calendar,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              // State badge
              Positioned(
                bottom: 12,
                left: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        dest.state,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // ═══ INFO ═══
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        dest.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary(context),
                        ),
                      ),
                    ),
                    if (dest.rating > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              dest.rating.toString(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  s.tagline,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                    height: 1.5,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 14),

                // Info chips + generate button
                Row(
                  children: [
                    if (dest.places.isNotEmpty)
                      _buildChip(
                        Icons.place,
                        '${dest.places.length} places',
                        context,
                      ),
                    if (dest.places.isNotEmpty) const SizedBox(width: 8),
                    _buildChip(Icons.category, dest.category, context),
                    const Spacer(),
                    GestureDetector(
                      onTap: _isGenerating
                          ? null
                          : () => _generateForSuggestion(s),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1A2A3A), Color(0xFF2C3E50)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${s.days}-Day Plan',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(IconData icon, String text, BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientBg(Destination dest) {
    final hash = dest.name.hashCode.abs();
    final gradients = [
      [const Color(0xFF1E5F74), const Color(0xFF133B5C)],
      [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
      [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
      [const Color(0xFFE65100), const Color(0xFFBF360C)],
      [const Color(0xFF00838F), const Color(0xFF006064)],
      [const Color(0xFF283593), const Color(0xFF1A237E)],
    ];
    final colors = gradients[hash % gradients.length];
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.terrain, size: 50, color: Colors.white24),
            const SizedBox(height: 8),
            Text(
              dest.name,
              style: const TextStyle(color: Colors.white54, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _ItinerarySuggestion {
  final Destination destination;
  final String title;
  final String tagline;
  final String durationLabel;
  final int days;
  final IconData icon;

  _ItinerarySuggestion({
    required this.destination,
    required this.title,
    required this.tagline,
    required this.durationLabel,
    required this.days,
    required this.icon,
  });
}
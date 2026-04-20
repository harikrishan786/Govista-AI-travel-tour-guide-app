import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_theme.dart';
import '../widgets/cached_image.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../models/destination_model_fixed.dart';
import 'home_screen.dart';
import 'hotels_screen.dart';
import 'ai_guide_screen.dart';
import 'profile_screen.dart';
import 'search_screen.dart';
import 'destination_detail_screen.dart';
import 'notification_screen.dart';

class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key});

  @override
  State<TripsScreen> createState() => _TripsScreenState();
}

class _TripsScreenState extends State<TripsScreen> {
  final int _selectedNavIndex = 1;
  int _selectedCategoryIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();
  final NotificationService _notificationService = NotificationService();
  int _unreadCount = 0;

  final List<String> categories = [
    'All',
    'Hill Station',
    'Trekking',
    'Spiritual',
    'Adventure',
    'Offbeat',
    'Lake',
  ];

  List<String> _recentSearches = [];
  List<Destination> _allDestinations = [];
  List<Destination> _displayDestinations = [];
  bool _isLoading = true;

  @override
  @override
  void initState() {
    super.initState();
    _loadData();
    _loadUnreadCount();
  }

  Future<void> _loadUnreadCount() async {
    final count = await _notificationService.getUnreadCount();
    if (mounted) setState(() => _unreadCount = count);
  }

  Future<void> _refreshContent() async {
    setState(() => _isLoading = true);
    await _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadDestinations(),
      _loadSearchHistory(),
    ]);
  }

  Future<void> _loadDestinations() async {
    try {
      final destinations = await _firebaseService.getAllDestinations();
      if (destinations.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Shuffle and pick random destinations
      final shuffled = List<Destination>.from(destinations)..shuffle(Random());
      
      setState(() {
        _allDestinations = destinations;
        _displayDestinations = shuffled.take(6).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading destinations: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _recentSearches = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _addToSearchHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    _recentSearches.remove(query); // Remove if exists (avoid duplicates)
    _recentSearches.insert(0, query); // Add to front
    if (_recentSearches.length > 10) {
      _recentSearches = _recentSearches.sublist(0, 10); // Keep max 10
    }
    await prefs.setStringList('search_history', _recentSearches);
    setState(() {});
  }

  Future<void> _clearSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('search_history', []);
    setState(() => _recentSearches.clear());
  }

  void _filterByCategory(int index) {
    setState(() {
      _selectedCategoryIndex = index;
      final category = categories[index];
      
      if (category == 'All') {
        final shuffled = List<Destination>.from(_allDestinations)..shuffle(Random());
        _displayDestinations = shuffled.take(6).toList();
      } else {
        final filtered = _allDestinations.where((d) {
          return d.category.toLowerCase().contains(category.toLowerCase()) ||
              d.categories.any((c) => c.toLowerCase().contains(category.toLowerCase())) ||
              d.tags.any((t) => t.toLowerCase().contains(category.toLowerCase()));
        }).toList();
        
        if (filtered.isNotEmpty) {
          filtered.shuffle(Random());
          _displayDestinations = filtered.take(6).toList();
        } else {
          _displayDestinations = [];
        }
      }
    });
  }

  void _onDestinationTapped(Destination destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(destination: destination),
      ),
    );
  }

  void _handleNavTap(int index) {
    // Navigation handled by MainShell
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refreshContent,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context),
              const SizedBox(height: 20),
              _buildSearchBar(context),
              const SizedBox(height: 20),
              if (_recentSearches.isNotEmpty) _buildRecentSearches(context),
              if (_recentSearches.isNotEmpty) const SizedBox(height: 20),
              _buildCategoryChips(context),
              const SizedBox(height: 24),
              _buildDestinations(context),
              const SizedBox(height: 100),
            ],
          ),
        ),
        ),
      ),
      // bottomNavigationBar handled by MainShell
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.equalizer, color: AppColors.primary, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Explore',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context))),
            Row(
              children: [
                Container(width: 8, height: 8,
                  decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                const Text('AI ASSISTANT ACTIVE',
                  style: TextStyle(fontSize: 12, color: AppColors.primary,
                    fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ],
            ),
          ],
        ),
        const Spacer(),
        GestureDetector(
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen()));
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
                Icon(Icons.notifications_outlined,
                  color: AppColors.textSecondary(context), size: 24),
                if (_unreadCount > 0)
                  Positioned(
                    right: -6, top: -6,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        _unreadCount > 9 ? '9+' : _unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
      onTap: () async {
        final result = await Navigator.push<String>(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
        // If search screen returns a query, add to history
        if (result != null && result.isNotEmpty) {
          _addToSearchHistory(result);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.searchBar(context),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.search, color: AppColors.textHint(context)),
            const SizedBox(width: 12),
            Expanded(
              child: Text('Search destinations, treks, cafes...',
                style: TextStyle(color: AppColors.textHint(context), fontSize: 16)),
            ),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.tune, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ REAL SEARCH HISTORY ═══
  Widget _buildRecentSearches(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('RECENT SEARCHES',
              style: TextStyle(fontSize: 12, color: AppColors.textHint(context),
                fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            GestureDetector(
              onTap: _clearSearchHistory,
              child: const Text('Clear All',
                style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _recentSearches.length,
            itemBuilder: (context, index) => GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => SearchScreen(initialQuery: _recentSearches[index]),
                ));
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.border(context)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.history, size: 16, color: AppColors.textHint(context)),
                    const SizedBox(width: 8),
                    Text(_recentSearches[index],
                      style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final isSelected = _selectedCategoryIndex == index;
          return GestureDetector(
            onTap: () => _filterByCategory(index),
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : AppColors.surface(context),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border(context)),
              ),
              child: Text(categories[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary(context),
                  fontWeight: FontWeight.w600, fontSize: 15)),
            ),
          );
        },
      ),
    );
  }

  // ═══ RANDOM DESTINATIONS FROM FIRESTORE ═══
  Widget _buildDestinations(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Discover Destinations',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,
            color: AppColors.textPrimary(context))),
        const SizedBox(height: 16),

        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          )
        else if (_displayDestinations.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.explore_off, size: 50, color: AppColors.textHint(context)),
                  const SizedBox(height: 12),
                  Text('No destinations found for this category',
                    style: TextStyle(color: AppColors.textHint(context)),
                    textAlign: TextAlign.center),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.65,
            ),
            itemCount: _displayDestinations.length,
            itemBuilder: (context, index) =>
                _buildDestinationCard(context, _displayDestinations[index]),
          ),
      ],
    );
  }

  Widget _buildDestinationCard(BuildContext context, Destination destination) {
    final hasImage = destination.image.isNotEmpty &&
        !destination.image.contains('unsplash.com/photo-1626621341517');

    return GestureDetector(
      onTap: () => _onDestinationTapped(destination),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.shadow(context), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    child: SizedBox(
                      width: double.infinity,
                      child: hasImage
                          ? AppCachedImage(url: destination.image, width: double.infinity, fit: BoxFit.cover)
                          : _buildCardGradient(destination),
                    ),
                  ),
                  // Rating badge
                  if (destination.rating > 0)
                    Positioned(
                      top: 10, left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(destination.rating.toString(),
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  // Category badge
                  Positioned(
                    bottom: 10, left: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(destination.category,
                        style: const TextStyle(color: Colors.white, fontSize: 10,
                          fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
            ),

            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary(context)),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 12, color: AppColors.textHint(context)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(destination.state,
                            style: TextStyle(fontSize: 12, color: AppColors.textHint(context)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Expanded(
                      child: Text(
                        destination.description.isNotEmpty
                            ? destination.description
                            : '${destination.places.length} places to visit',
                        style: TextStyle(fontSize: 12,
                          color: AppColors.textSecondary(context), height: 1.3),
                        maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardGradient(Destination destination) {
    final hash = destination.name.hashCode.abs();
    final gradients = [
      [Colors.teal[400]!, Colors.teal[700]!],
      [Colors.indigo[400]!, Colors.indigo[700]!],
      [Colors.orange[400]!, Colors.orange[700]!],
      [Colors.purple[400]!, Colors.purple[700]!],
      [Colors.blue[400]!, Colors.blue[700]!],
      [Colors.green[400]!, Colors.green[700]!],
    ];
    final colors = gradients[hash % gradients.length];
    return Container(
      decoration: BoxDecoration(gradient: LinearGradient(colors: colors)),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.landscape, size: 40, color: Colors.white54),
            const SizedBox(height: 4),
            Text(destination.name, style: const TextStyle(color: Colors.white70, fontSize: 12),
              textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
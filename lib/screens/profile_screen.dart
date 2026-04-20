import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/destination_model_fixed.dart';
import '../services/firebase_service.dart';
import 'home_screen.dart';
import 'trips_screen.dart';
import 'hotels_screen.dart';
import 'ai_guide_screen.dart';
import 'settings_screen.dart';
import 'itinerary_view_screen.dart';
import 'destination_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => ProfileScreenState();
}

class ProfileScreenState extends State<ProfileScreen> {
  final int _selectedNavIndex = 4;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Called by MainShell when profile tab is selected
  void refreshData() {
    _loadSavedTrips();
    _loadLikedPlaces();
  }

  String get userName =>
      FirebaseAuth.instance.currentUser?.displayName ?? "User";
  String get userEmail => FirebaseAuth.instance.currentUser?.email ?? "";
  String? get userAvatarUrl => FirebaseAuth.instance.currentUser?.photoURL;
  String? get userId => FirebaseAuth.instance.currentUser?.uid;

  int tripsTaken = 0;
  int placesSaved = 0;

  String voicePersona = "Jasper (Energetic)";
  String responseStyle = "Historical Guide";
  bool predictivePlanning = true;

  List<Map<String, dynamic>> _savedTrips = [];
  bool _loadingTrips = true;
  List<Destination> _likedPlaces = [];
  bool _loadingLiked = true;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _loadSavedTrips();
    _loadStats();
    _loadLikedPlaces();
  }

  Future<void> _loadLikedPlaces() async {
    if (userId == null) {
      setState(() => _loadingLiked = false);
      return;
    }
    try {
      final favIds = await _firebaseService.getUserFavorites();
      if (favIds.isEmpty) {
        setState(() {
          _likedPlaces = [];
          _loadingLiked = false;
          placesSaved = 0;
        });
        return;
      }

      List<Destination> places = [];
      for (final id in favIds) {
        final dest = await _firebaseService.getDestinationById(id);
        if (dest != null) places.add(dest);
      }

      setState(() {
        _likedPlaces = places.reversed.toList();
        placesSaved = places.length;
        _loadingLiked = false;
      });
    } catch (e) {
      print('Error loading liked places: $e');
      setState(() => _loadingLiked = false);
    }
  }

  Future<void> _loadSavedTrips() async {
    if (userId == null) {
      setState(() => _loadingTrips = false);
      return;
    }
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_itineraries')
          .orderBy('savedAt', descending: true)
          .get();

      setState(() {
        _savedTrips = snapshot.docs.map((doc) {
          final data = doc.data();
          data['docId'] = doc.id;
          return data;
        }).toList();
        _loadingTrips = false;
        tripsTaken = _savedTrips.length;
      });
    } catch (e) {
      print('Error loading saved trips: $e');
      setState(() => _loadingTrips = false);
    }
  }

  Future<void> _loadStats() async {
    // Counts come from _loadSavedTrips and _loadLikedPlaces
  }

  Future<void> _deleteTrip(String docId, int index) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Trip?'),
        content: const Text('This itinerary will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || userId == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('saved_itineraries')
          .doc(docId)
          .delete();
      setState(() {
        _savedTrips.removeAt(index);
        tripsTaken = _savedTrips.length;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Trip deleted'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('Delete error: $e');
    }
  }

  void _openSavedItinerary(Map<String, dynamic> tripData) {
    try {
      final dayPlansJson = tripData['dayPlans'] as List<dynamic>? ?? [];
      final dayPlans = dayPlansJson.map((d) {
        final map = d as Map<String, dynamic>;
        final acts = (map['activities'] as List<dynamic>? ?? []).map((a) {
          final aMap = a as Map<String, dynamic>;
          return Activity(
            time: aMap['time'] ?? '',
            title: aMap['title'] ?? '',
            description: aMap['description'] ?? '',
            icon: aMap['icon'] ?? 'place',
          );
        }).toList();
        return DayPlan(
          day: map['day'] ?? 1,
          title: map['title'] ?? '',
          activities: acts,
        );
      }).toList();

      final itinerary = Itinerary(
        id: tripData['docId'] ?? '',
        destinationId: tripData['destinationId'] ?? '',
        title: tripData['title'] ?? '',
        days: tripData['days'] ?? dayPlans.length,
        description: tripData['description'] ?? '',
        dayPlans: dayPlans,
        budget: tripData['budget'] ?? '',
        travelTips: tripData['travelTips'] ?? '',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ItineraryViewScreen(itinerary: itinerary),
        ),
      );
    } catch (e) {
      print('Error opening itinerary: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error opening itinerary')),
      );
    }
  }

  // Navigation handled by MainShell

  void _onSettingsTapped() {
    Navigator.push(
        context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(context),
            _buildStatsCard(context),
            const SizedBox(height: 24),
            _buildSavedItineraries(context),
            const SizedBox(height: 24),
            _buildLikedPlaces(context),
            const SizedBox(height: 24),
            _buildAISettings(context),
            const SizedBox(height: 100),
          ],
        ),
      ),
      // bottomNavigationBar handled by MainShell
    );
  }

  // ═══════════════════════════════════════════
  // PROFILE HEADER — avatar + name + email only
  // ═══════════════════════════════════════════
  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1E5F74), Color(0xFF133B5C)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: _onSettingsTapped,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.settings_outlined,
                          color: Colors.white, size: 22),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.share_outlined,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Avatar — no PRO badge
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: const Color(0xFF5C6B7A), width: 3),
                ),
                child: CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: userAvatarUrl != null
                      ? NetworkImage(userAvatarUrl!)
                      : null,
                  child: userAvatarUrl == null
                      ? Icon(Icons.person,
                          size: 50, color: Colors.grey[600])
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Name
              Text(userName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              // Email only
              Text(userEmail,
                  style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // STATS CARD
  // ═══════════════════════════════════════════
  Widget _buildStatsCard(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -25),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: AppColors.card(context),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                  color: AppColors.shadow(context),
                  blurRadius: 20,
                  offset: const Offset(0, 10)),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('TRIPS SAVED',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint(context),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(tripsTaken.toString(),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context))),
                  ],
                ),
              ),
              Container(
                  width: 1, height: 50, color: AppColors.divider(context)),
              Expanded(
                child: Column(
                  children: [
                    Text('LIKED PLACES',
                        style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textHint(context),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 6),
                    Text(placesSaved.toString(),
                        style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context))),
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
  // SAVED ITINERARIES
  // ═══════════════════════════════════════════
  Widget _buildSavedItineraries(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Saved Itineraries',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context))),
              if (_savedTrips.isNotEmpty)
                Text('${_savedTrips.length} trips',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingTrips)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_savedTrips.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.map_outlined,
                        color: AppColors.primary.withValues(alpha: 0.5), size: 40),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Your adventures await',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Every journey begins with a plan.\nGenerate your first AI itinerary and save it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textHint(context),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  OutlinedButton.icon(
                    onPressed: () {
                      // Navigate back to home tab via pop (MainShell handles tabs)
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('Explore Destinations'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 200,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _savedTrips.length,
                itemBuilder: (context, index) =>
                    _buildTripCard(context, _savedTrips[index], index),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTripCard(
      BuildContext context, Map<String, dynamic> trip, int index) {
    final title = trip['title'] ?? 'Trip';
    final days = trip['days'] ?? 0;
    final description = trip['description'] ?? '';
    final destinationId = trip['destinationId'] ?? '';
    final colors = _getTripColors(destinationId);

    return GestureDetector(
      onTap: () => _openSavedItinerary(trip),
      onLongPress: () => _deleteTrip(trip['docId'], index),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: colors[0].withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
              ),
              Positioned(
                right: -20, top: -20,
                child: Icon(Icons.terrain,
                    size: 120, color: Colors.white.withValues(alpha: 0.08)),
              ),
              Positioned(
                left: -10, bottom: -10,
                child: Icon(Icons.landscape,
                    size: 80, color: Colors.white.withValues(alpha: 0.06)),
              ),
              Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$days ${days == 1 ? 'Day' : 'Days'}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Spacer(),
                    Text(title,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1.2),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    if (description.isNotEmpty)
                      Text(description,
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 12,
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.touch_app,
                            color: Colors.white.withValues(alpha: 0.6), size: 12),
                        const SizedBox(width: 4),
                        Text('Tap to view • Hold to delete',
                            style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 10)),
                      ],
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

  List<Color> _getTripColors(String destination) {
    final hash = destination.hashCode.abs();
    final palettes = [
      [const Color(0xFF1E5F74), const Color(0xFF133B5C)],
      [const Color(0xFF2E7D32), const Color(0xFF1B5E20)],
      [const Color(0xFF6A1B9A), const Color(0xFF4A148C)],
      [const Color(0xFFE65100), const Color(0xFFBF360C)],
      [const Color(0xFF00838F), const Color(0xFF006064)],
      [const Color(0xFF4527A0), const Color(0xFF311B92)],
      [const Color(0xFF283593), const Color(0xFF1A237E)],
      [const Color(0xFF00695C), const Color(0xFF004D40)],
    ];
    return palettes[hash % palettes.length];
  }

  // ═══════════════════════════════════════════
  // LIKED PLACES
  // ═══════════════════════════════════════════
  Widget _buildLikedPlaces(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Liked Places',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary(context))),
              if (_likedPlaces.isNotEmpty)
                Text('${_likedPlaces.length} places',
                    style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 16),
          if (_loadingLiked)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            )
          else if (_likedPlaces.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.06),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite_outline,
                        color: Colors.red.withValues(alpha: 0.4), size: 36),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No liked places yet',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tap the heart on any destination to save\nyour favorite spots here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textHint(context),
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 180,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _likedPlaces.length,
                itemBuilder: (context, index) =>
                    _buildLikedPlaceCard(context, _likedPlaces[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLikedPlaceCard(BuildContext context, Destination destination) {
    final hasImage = destination.image.isNotEmpty &&
        !destination.image.contains('unsplash.com/photo-1626621341517');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                DestinationDetailScreen(destination: destination),
          ),
        ).then((_) {
          _loadLikedPlaces();
        });
      },
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadow(context),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasImage)
                Image.network(destination.image, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _buildPlaceGradient(destination))
              else
                _buildPlaceGradient(destination),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.75),
                    ],
                  ),
                ),
              ),
              Positioned(
                top: 10, right: 10,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.favorite,
                      color: Colors.red, size: 16),
                ),
              ),
              Positioned(
                bottom: 12, left: 12, right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(destination.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(Icons.location_on,
                            color: Colors.white.withValues(alpha: 0.8), size: 12),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(destination.state,
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    if (destination.rating > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.star,
                              color: Colors.amber, size: 13),
                          const SizedBox(width: 3),
                          Text(destination.rating.toString(),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceGradient(Destination destination) {
    final hash = destination.name.hashCode.abs();
    final gradients = [
      [const Color(0xFF0D7377), const Color(0xFF14FFEC)],
      [const Color(0xFF642B73), const Color(0xFFC6426E)],
      [const Color(0xFF2C3E50), const Color(0xFF3498DB)],
      [const Color(0xFF1D4350), const Color(0xFFA43931)],
      [const Color(0xFF134E5E), const Color(0xFF71B280)],
      [const Color(0xFF4B1248), const Color(0xFFF0C27F)],
    ];
    final colors = gradients[hash % gradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(colors[0].value), Color(colors[1].value)],
        ),
      ),
      child: Center(
        child: Icon(Icons.landscape,
            size: 50, color: Colors.white.withValues(alpha: 0.2)),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // AI SETTINGS
  // ═══════════════════════════════════════════
  Widget _buildAISettings(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('AI Assistant Settings',
              style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary(context))),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: AppColors.shadow(context),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                _buildSettingsTile(context, Icons.record_voice_over_outlined,
                    'Voice Persona', voicePersona,
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.textHint(context))),
                Divider(height: 1, color: AppColors.divider(context)),
                _buildSettingsTile(
                    context, Icons.help_outline, 'Response Style', responseStyle,
                    trailing: Icon(Icons.chevron_right,
                        color: AppColors.textHint(context))),
                Divider(height: 1, color: AppColors.divider(context)),
                _buildSettingsTile(context, Icons.auto_awesome,
                    'Predictive Planning', 'Based on your activity',
                    trailing: Switch(
                      value: predictivePlanning,
                      onChanged: (v) =>
                          setState(() => predictivePlanning = v),
                      activeThumbColor: AppColors.primary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(
      BuildContext context, IconData icon, String title, String subtitle,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary(context))),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textHint(context))),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }
}
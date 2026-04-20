import 'package:flutter/material.dart';
import '../models/destination_model_fixed.dart';
import '../services/itinerary_service.dart';
import '../services/firebase_service.dart';
import '../screens/day_picker_sheet.dart';
import '../screens/itinerary_view_screen.dart';
import '../widgets/place_detail_sheet.dart';

class DestinationTemplateScreen extends StatefulWidget {
  final Destination destination;

  const DestinationTemplateScreen({super.key, required this.destination});

  @override
  State<DestinationTemplateScreen> createState() =>
      _DestinationTemplateScreenState();
}

class _DestinationTemplateScreenState extends State<DestinationTemplateScreen> {
  bool _isFavorite = false;
  bool _isGenerating = false;
  String _selectedFilter = 'All';
  final ItineraryService _itineraryService = ItineraryService();
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    _checkFavorite();
  }

  Future<void> _checkFavorite() async {
    final isFav = await _firebaseService.isFavorite(widget.destination.id);
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    if (_isFavorite) {
      await _firebaseService.removeFromFavorites(widget.destination.id);
    } else {
      await _firebaseService.addToFavorites(widget.destination.id);
    }
    setState(() => _isFavorite = !_isFavorite);
  }

  List<String> get _filterOptions {
    Set<String> types = {'All'};
    for (var place in widget.destination.places) {
      types.add(place.type);
    }
    return types.toList();
  }

  List<Place> get _filteredPlaces {
    if (_selectedFilter == 'All') return widget.destination.places;
    return widget.destination.places
        .where((p) => p.type == _selectedFilter)
        .toList();
  }

  void _onGenerateItinerary() {
    DayPickerSheet.show(
      context: context,
      cityName: widget.destination.name,
      onDaysSelected: (days) => _generateItinerary(days),
    );
  }

  Future<void> _generateItinerary(int days) async {
    setState(() => _isGenerating = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            const SizedBox(
              width: 50, height: 50,
              child: CircularProgressIndicator(
                color: Color(0xFF1E88E5), strokeWidth: 3,
              ),
            ),
            const SizedBox(height: 24),
            const Text('Creating your itinerary...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('$days days in ${widget.destination.name}',
                style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    final itinerary = await _itineraryService.generateItinerary(
      cityName: widget.destination.name,
      state: widget.destination.state,
      days: days,
      existingAttractions:
          widget.destination.places.map((p) => p.name).toList(),
      existingActivities: widget.destination.activities,
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
          content: Text('Failed to generate itinerary. Try again.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = widget.destination;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF121212)
          : const Color(0xFFF5F5F5),
      body: CustomScrollView(
        slivers: [
          // Hero Image
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white),
              ),
            ),
            actions: [
              GestureDetector(
                onTap: _toggleFavorite,
                child: Container(
                  margin: const EdgeInsets.all(8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: _isFavorite ? Colors.red : Colors.white,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Share coming soon!')),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share, color: Colors.white),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    destination.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: const Color(0xFF1E88E5).withOpacity(0.3),
                      child: const Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.7),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            destination.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          destination.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              color: Colors.white70,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destination.state,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            const Icon(
                              Icons.star,
                              color: Colors.amber,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              destination.rating.toString(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Info
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoCard(
                          Icons.calendar_month,
                          'Best Time',
                          destination.bestTime,
                          const Color(0xFF4CAF50),
                          isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildInfoCard(
                          Icons.place,
                          'Places',
                          '${destination.places.length} spots',
                          const Color(0xFF2196F3),
                          isDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Description
                  Text(
                    'About',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    destination.description,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : const Color(0xFF666666),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Activities
                  if (destination.activities.isNotEmpty) ...[
                    Text(
                      'Things to Do',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: destination.activities
                          .map(
                            (activity) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF1E88E5).withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _getActivityIcon(activity),
                                    color: const Color(0xFF1E88E5),
                                    size: 16,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    activity,
                                    style: const TextStyle(
                                      color: Color(0xFF1E88E5),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Places Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Places to Visit',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        '${destination.places.length} places',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white70 : const Color(0xFF666666),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _filterOptions.map((filter) {
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _selectedFilter = filter),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFF1E88E5)
                                    : (isDark
                                        ? const Color(0xFF2C2C2C)
                                        : Colors.white),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1E88E5)
                                      : (isDark
                                          ? Colors.white12
                                          : const Color(0xFFE0E0E0)),
                                ),
                              ),
                              child: Text(
                                filter,
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? Colors.white70
                                          : const Color(0xFF666666)),
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Places List
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) =>
                    _buildPlaceCard(_filteredPlaces[index], isDark),
                childCount: _filteredPlaces.length,
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),

      // ═══ GENERATE ITINERARY BUTTON (FIXED) ═══
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: _isGenerating ? null : _onGenerateItinerary,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A2A3A),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Generate AI Itinerary',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard(
    IconData icon, String title, String value, Color color, bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : const Color(0xFFE0E0E0),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                  style: TextStyle(fontSize: 12,
                    color: isDark ? Colors.white70 : const Color(0xFF666666))),
                const SizedBox(height: 2),
                Text(value,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                  maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceCard(Place place, bool isDark) {
    return GestureDetector(
      onTap: () => PlaceDetailSheet.show(
        context: context,
        place: place,
        destinationName: widget.destination.name,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.white12 : const Color(0xFFE0E0E0)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Image.network(place.image, width: 110, height: 110, fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 110, height: 110,
                  color: const Color(0xFF1E88E5).withOpacity(0.2),
                  child: const Icon(Icons.image, color: Color(0xFF1E88E5)),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(place.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 2),
                              Text(place.rating.toString(),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E88E5))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getTypeColor(place.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4)),
                      child: Text(place.type,
                        style: TextStyle(fontSize: 11, color: _getTypeColor(place.type),
                          fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 6),
                    Text(place.description,
                      style: TextStyle(fontSize: 12,
                        color: isDark ? Colors.white70 : const Color(0xFF666666), height: 1.3),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12,
                          color: isDark ? Colors.white38 : const Color(0xFF999999)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(place.timing,
                            style: TextStyle(fontSize: 11,
                              color: isDark ? Colors.white38 : const Color(0xFF999999)),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        Text(place.entryFee,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E88E5),
                            fontWeight: FontWeight.w600)),
                      ],
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

  IconData _getActivityIcon(String activity) {
    switch (activity.toLowerCase()) {
      case 'trekking': return Icons.hiking;
      case 'camping': return Icons.cabin;
      case 'skiing': return Icons.downhill_skiing;
      case 'paragliding': return Icons.paragliding;
      case 'river rafting': return Icons.kayaking;
      case 'yoga': return Icons.self_improvement;
      case 'meditation': return Icons.spa;
      case 'photography': return Icons.camera_alt;
      case 'shopping': return Icons.shopping_bag;
      case 'temple visit': return Icons.temple_hindu;
      case 'sightseeing': return Icons.remove_red_eye;
      case 'boating': return Icons.rowing;
      default: return Icons.local_activity;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'temple': return const Color(0xFFFF9800);
      case 'adventure': return const Color(0xFF4CAF50);
      case 'viewpoint': return const Color(0xFF2196F3);
      case 'lake': return const Color(0xFF00BCD4);
      case 'waterfall': return const Color(0xFF3F51B5);
      case 'trek': return const Color(0xFF8BC34A);
      case 'monastery': return const Color(0xFF9C27B0);
      case 'village': return const Color(0xFF795548);
      case 'shopping': return const Color(0xFFE91E63);
      case 'religious': return const Color(0xFFFF5722);
      case 'historical': return const Color(0xFF607D8B);
      default: return const Color(0xFF1E88E5);
    }
  }
}
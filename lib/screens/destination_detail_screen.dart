import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../models/destination_model_fixed.dart';
import '../services/firebase_service.dart';
import '../services/itinerary_service.dart';
import '../services/place_image_service.dart';
import '../widgets/place_detail_sheet.dart';
import 'day_picker_sheet.dart';
import 'itinerary_view_screen.dart';

class DestinationDetailScreen extends StatefulWidget {
  final Destination destination;

  const DestinationDetailScreen({super.key, required this.destination});

  @override
  State<DestinationDetailScreen> createState() =>
      _DestinationDetailScreenState();
}

class _DestinationDetailScreenState extends State<DestinationDetailScreen> {
  final FirebaseService _firebaseService = FirebaseService();
  final ItineraryService _itineraryService = ItineraryService();
  final PlaceImageService _imageService = PlaceImageService();
  bool _isFavorite = false;
  bool _isGenerating = false;
  final Map<String, String> _placeImages = {};

  @override
  void initState() {
    super.initState();
    _checkFavorite();
    _loadPlaceImages();
  }

  Future<void> _checkFavorite() async {
    print('🔍 Checking favorite for ID: ${widget.destination.id}');
    print('🔍 Destination name: ${widget.destination.name}');
    final isFav = await _firebaseService.isFavorite(widget.destination.id);
    print('🔍 isFavorite result: $isFav');
    if (mounted) setState(() => _isFavorite = isFav);
  }

  Future<void> _toggleFavorite() async {
    print('❤️ Toggle favorite tapped!');
    print('❤️ Destination ID: ${widget.destination.id}');
    print('❤️ Current _isFavorite: $_isFavorite');
    print('❤️ Current user: ${_firebaseService.currentUser?.uid}');
    
    try {
      if (_isFavorite) {
        await _firebaseService.removeFromFavorites(widget.destination.id);
      } else {
        await _firebaseService.addToFavorites(widget.destination.id);
      }
      setState(() => _isFavorite = !_isFavorite);
      print('✅ Favorite toggled successfully! Now: ${!_isFavorite ? "removed" : "added"}');
    } catch (e) {
      print('❌ Toggle favorite error: $e');
    }
  }

  Future<void> _loadPlaceImages() async {
    final names = widget.destination.places.map((p) => p.name).toList();
    if (names.isNotEmpty) {
      final images = await _imageService.getImagesForPlaces(names);
      if (mounted) setState(() => _placeImages.addAll(images));
    }
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
              child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 3),
            ),
            const SizedBox(height: 24),
            const Text('Creating your itinerary...', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text('$days days in ${widget.destination.name}', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    final itinerary = await _itineraryService.generateItinerary(
      cityName: widget.destination.name,
      state: widget.destination.state,
      days: days,
      existingAttractions: widget.destination.places.map((p) => p.name).toList(),
      existingActivities: widget.destination.activities,
    );

    if (mounted) Navigator.pop(context);
    setState(() => _isGenerating = false);

    if (itinerary != null && mounted) {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => ItineraryViewScreen(itinerary: itinerary),
      ));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to generate itinerary. Try again.'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dest = widget.destination;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: CustomScrollView(
        slivers: [
          // ═══ HERO IMAGE ═══
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: CircleAvatar(
                backgroundColor: Colors.black38,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: CircleAvatar(
                  backgroundColor: Colors.black38,
                  child: IconButton(
                    icon: Icon(
                      _isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: _isFavorite ? Colors.red : Colors.white, size: 20,
                    ),
                    onPressed: _toggleFavorite,
                  ),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(dest.image, fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)]),
                      ),
                      child: const Icon(Icons.landscape, color: Colors.white54, size: 80),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                      ),
                    ),
                  ),
                  // State badge
                  Positioned(
                    bottom: 16, left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(8)),
                      child: Text(dest.state.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ═══ CONTENT ═══
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name + location
                  Text(dest.name, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                  const SizedBox(height: 4),
                  Row(children: [
                    Icon(Icons.location_on, size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text('${dest.district.isNotEmpty ? '${dest.district}, ' : ''}${dest.state}',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context)),
                    ),
                    const Spacer(),
                    if (dest.rating > 0) ...[
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text(dest.rating.toString(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary(context))),
                    ],
                  ]),

                  const SizedBox(height: 20),

                  // ═══ GENERATE ITINERARY BUTTON ═══
                  SizedBox(
                    width: double.infinity, height: 54,
                    child: ElevatedButton.icon(
                      onPressed: _isGenerating ? null : _onGenerateItinerary,
                      icon: const Icon(Icons.auto_awesome, size: 20),
                      label: const Text('Generate Itinerary', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A2A3A), foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ═══ KEY HIGHLIGHTS ═══
                  Text('Key Highlights', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                  const SizedBox(height: 14),
                  Row(children: [
                    _buildHighlight(Icons.calendar_today, dest.bestTime.isNotEmpty ? dest.bestTime : 'Year round', 'Best Time'),
                    const SizedBox(width: 12),
                    _buildHighlight(Icons.terrain, dest.altitude > 0 ? '${dest.altitude}m' : 'N/A', 'Altitude'),
                    const SizedBox(width: 12),
                    _buildHighlight(Icons.category, dest.category, 'Type'),
                  ]),

                  const SizedBox(height: 28),

                  // ═══ ABOUT ═══
                  if (dest.description.isNotEmpty) ...[
                    Text(dest.description,
                      style: TextStyle(fontSize: 15, color: AppColors.textSecondary(context), height: 1.6),
                    ),
                    const SizedBox(height: 28),
                  ],

                  // ═══ THINGS TO DO ═══
                  if (dest.places.isNotEmpty) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Things to do', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                        Text('See all', style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    ...dest.places.map((p) => _buildPlaceTile(p)),
                    const SizedBox(height: 16),
                  ],

                  // ═══ ACTIVITIES ═══
                  if (dest.activities.isNotEmpty) ...[
                    Text('Activities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: dest.activities.map((a) => Chip(
                        avatar: Icon(_getActivityIcon(a), size: 16, color: AppColors.primary),
                        label: Text(a),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        labelStyle: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 12),
                        side: BorderSide.none,
                      )).toList(),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // ═══ TAGS ═══
                  if (dest.tags.isNotEmpty) ...[
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: dest.tags.map((t) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text('#$t', style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
                      )).toList(),
                    ),
                  ],

                  // ═══ HOW TO REACH ═══
                  if (dest.accessibility.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('How to Reach', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.textPrimary(context))),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border(context)),
                      ),
                      child: Row(children: [
                        Icon(Icons.directions, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(child: Text(dest.accessibility,
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context)),
                        )),
                      ]),
                    ),
                  ],

                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHighlight(IconData icon, String value, String label) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardAlt(context), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Column(children: [
          Icon(icon, color: AppColors.primary, size: 24),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary(context)),
            textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(fontSize: 11, color: AppColors.textHint(context))),
        ]),
      ),
    );
  }

  Widget _buildPlaceTile(Place place) {
    final wikiImage = _placeImages[place.name] ?? '';
    final imageUrl = place.image.isNotEmpty && !place.image.contains('unsplash.com/photo-1626621341517')
        ? place.image
        : wikiImage;

    return GestureDetector(
      onTap: () => PlaceDetailSheet.show(
        context: context,
        place: place,
        destinationName: widget.destination.name,
        imageUrl: imageUrl,
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.card(context), borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56, height: 56,
              child: imageUrl.isNotEmpty
                  ? Image.network(imageUrl, fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => Container(
                        color: AppColors.primary.withOpacity(0.1),
                        child: Icon(Icons.place, color: AppColors.primary, size: 24),
                      ))
                  : Container(
                      color: AppColors.primary.withOpacity(0.1),
                      child: Icon(Icons.place, color: AppColors.primary, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(place.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.textPrimary(context))),
              const SizedBox(height: 2),
              Row(children: [
                Text(place.type, style: TextStyle(fontSize: 13, color: AppColors.textHint(context))),
                if (place.rating > 0) ...[
                  const Text(' • '),
                  Text('${place.rating}', style: TextStyle(fontSize: 13, color: AppColors.textHint(context))),
                  const Icon(Icons.star, size: 12, color: Colors.amber),
                ],
              ]),
              if (place.description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(place.description, style: TextStyle(fontSize: 12, color: AppColors.textHint(context)),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ],
          )),
          Icon(Icons.chevron_right, color: AppColors.textHint(context)),
        ]),
      ),
    );
  }

  IconData _getActivityIcon(String activity) {
    final a = activity.toLowerCase();
    if (a.contains('trek')) return Icons.hiking;
    if (a.contains('raft')) return Icons.kayaking;
    if (a.contains('paraglid')) return Icons.paragliding;
    if (a.contains('ski')) return Icons.downhill_skiing;
    if (a.contains('temple') || a.contains('monastery')) return Icons.temple_hindu;
    if (a.contains('cafe')) return Icons.coffee;
    if (a.contains('yoga') || a.contains('meditation')) return Icons.self_improvement;
    if (a.contains('photo')) return Icons.camera_alt;
    if (a.contains('bike')) return Icons.directions_bike;
    if (a.contains('shop')) return Icons.shopping_bag;
    return Icons.local_activity;
  }
}
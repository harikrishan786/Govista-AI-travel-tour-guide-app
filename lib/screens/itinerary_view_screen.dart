import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:govistaofficial/models/destination_model_fixed.dart';
import 'package:govistaofficial/services/place_image_service.dart';
import 'package:govistaofficial/services/notification_service.dart';
import 'package:govistaofficial/app_theme.dart';

class ItineraryViewScreen extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryViewScreen({super.key, required this.itinerary});

  @override
  State<ItineraryViewScreen> createState() => _ItineraryViewScreenState();
}

class _ItineraryViewScreenState extends State<ItineraryViewScreen> {
  int _selectedDay = 0;
  final PlaceImageService _imageService = PlaceImageService();
  final Map<String, String> _activityImages = {};
  bool _loadingImages = true;
  bool _isSaved = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchImages();
  }

  Future<void> _fetchImages() async {
    final destName = widget.itinerary.title
        .replaceAll(RegExp(r'\d+\s*days?\s*(in|trip|journey|escape|adventure|retreat)?', caseSensitive: false), '')
        .replaceAll(RegExp(r'(trip|journey|escape|adventure|retreat)$', caseSensitive: false), '')
        .trim();

    for (final day in widget.itinerary.dayPlans) {
      for (final activity in day.activities) {
        final title = activity.title;
        if (_activityImages.containsKey(title) && _activityImages[title]!.isNotEmpty) continue;

        // Try Wikipedia with destination context
        String img = await _imageService.getImageUrl('$title $destName');
        
        // If Wikipedia fails, try just the title
        if (img.isEmpty) {
          img = await _imageService.getImageUrl(title);
        }

        // If Wikipedia still fails, try Pixabay
        if (img.isEmpty) {
          img = await _fetchPixabayImage(title, destName);
        }

        if (img.isNotEmpty && mounted) {
          setState(() => _activityImages[title] = img);
        }
      }
    }

    if (mounted) setState(() => _loadingImages = false);
  }

  /// Pixabay fallback for activity images
  Future<String> _fetchPixabayImage(String activityTitle, String destName) async {
    const pixabayKey = '54700874-905e8f80cbdd5195383e59d9c';
    
    // Build smart queries based on activity type
    final lower = activityTitle.toLowerCase();
    final queries = <String>[];

    if (lower.contains('lunch') || lower.contains('dinner') || lower.contains('breakfast') || lower.contains('food') || lower.contains('dhaba') || lower.contains('cafe') || lower.contains('restaurant') || lower.contains('resort') || lower.contains('hotel') || lower.contains('homestay') || lower.contains('meal') || lower.contains('farewell') || lower.contains('thali')) {
      if (lower.contains('resort') || lower.contains('hotel') || lower.contains('homestay')) {
        queries.add('mountain resort hotel himalaya');
        queries.add('hill station resort India');
      } else {
        queries.add('indian thali food');
        queries.add('himalayan cuisine food plate');
      }
    } else if (lower.contains('trek') || lower.contains('hike') || lower.contains('trail')) {
      queries.add('$destName trekking mountain');
      queries.add('himalaya trekking trail');
    } else if (lower.contains('temple') || lower.contains('mandir') || lower.contains('shrine')) {
      queries.add('$activityTitle temple');
      queries.add('$destName temple India');
    } else if (lower.contains('lake') || lower.contains('river')) {
      queries.add('$destName lake');
      queries.add('mountain lake India');
    } else if (lower.contains('market') || lower.contains('shopping') || lower.contains('bazaar') || lower.contains('mall') || lower.contains('souvenir') || lower.contains('handicraft')) {
      queries.add('indian hill station market shopping');
      queries.add('local market handicrafts India');
    } else if (lower.contains('waterfall') || lower.contains('falls')) {
      queries.add('$destName waterfall');
      queries.add('waterfall India');
    } else if (lower.contains('monastery') || lower.contains('gompa')) {
      queries.add('$destName monastery');
      queries.add('buddhist monastery himalaya');
    } else if (lower.contains('sunset') || lower.contains('sunrise') || lower.contains('view') || lower.contains('viewpoint')) {
      queries.add('$destName sunset mountain');
      queries.add('mountain sunset India');
    } else if (lower.contains('camp') || lower.contains('bonfire') || lower.contains('night')) {
      queries.add('mountain camping bonfire');
      queries.add('camping himalaya');
    } else if (lower.contains('yoga') || lower.contains('meditation')) {
      queries.add('yoga mountains India');
    } else if (lower.contains('rafting') || lower.contains('kayak')) {
      queries.add('river rafting India');
    } else if (lower.contains('paragliding') || lower.contains('parachute')) {
      queries.add('paragliding mountains');
    } else if (lower.contains('ski') || lower.contains('snow')) {
      queries.add('skiing snow mountains India');
    } else if (lower.contains('walk') || lower.contains('stroll') || lower.contains('explore') || lower.contains('visit') || lower.contains('sightseeing') || lower.contains('tour')) {
      queries.add('$destName India sightseeing');
      queries.add('$destName landscape');
    } else if (lower.contains('arriv') || lower.contains('check') || lower.contains('depart') || lower.contains('travel') || lower.contains('drive') || lower.contains('journey')) {
      queries.add('mountain road india travel');
      queries.add('himalaya road journey');
    } else {
      queries.add('$destName India landscape');
      queries.add('$destName mountain nature');
    }

    for (final q in queries) {
      try {
        final url = Uri.parse(
          'https://pixabay.com/api/'
          '?key=$pixabayKey'
          '&q=${Uri.encodeComponent(q)}'
          '&image_type=photo'
          '&orientation=horizontal'
          '&per_page=3'
          '&safesearch=true'
          '&order=popular',
        );
        final res = await http.get(url).timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final json = jsonDecode(res.body);
          final hits = json['hits'] as List<dynamic>? ?? [];
          if (hits.isNotEmpty) {
            final imgUrl = hits[0]['webformatURL'] as String? ?? '';
            if (imgUrl.isNotEmpty) return imgUrl;
          }
        }
      } catch (e) {
        print('Pixabay error: $e');
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return '';
  }

  Future<void> _saveToTrips() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in to save trips'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final itinerary = widget.itinerary;
      final data = {
        'title': itinerary.title,
        'destinationId': itinerary.destinationId,
        'days': itinerary.days,
        'description': itinerary.description,
        'budget': itinerary.budget,
        'travelTips': itinerary.travelTips,
        'dayPlans': itinerary.dayPlans.map((d) => {
          'day': d.day,
          'title': d.title,
          'activities': d.activities.map((a) => {
            'time': a.time,
            'title': a.title,
            'description': a.description,
            'icon': a.icon,
          }).toList(),
        }).toList(),
        'savedAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('saved_itineraries')
          .add(data);

      if (mounted) {
        setState(() {
          _isSaved = true;
          _isSaving = false;
        });

        // Send trip saved notification
        NotificationService().sendTripSavedNotification(
          itinerary.title, itinerary.days,
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Itinerary saved to My Trips! ✓'),
            backgroundColor: Color(0xFF108C65),
          ),
        );
      }
    } catch (e) {
      print('Save error: $e');
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;
    final currentDay = _selectedDay < itinerary.dayPlans.length
        ? itinerary.dayPlans[_selectedDay]
        : null;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context), elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(children: [
          Text(itinerary.title,
            style: TextStyle(color: AppColors.textPrimary(context), fontSize: 18, fontWeight: FontWeight.bold)),
          if (itinerary.description.isNotEmpty)
            Text(itinerary.description,
              style: TextStyle(color: AppColors.textHint(context), fontSize: 12),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: AppColors.textPrimary(context)),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(children: [
        // ═══ DAY TABS ═══
        Container(
          height: 72,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: itinerary.dayPlans.length,
            itemBuilder: (context, index) {
              final isSelected = index == _selectedDay;
              return GestureDetector(
                onTap: () => setState(() => _selectedDay = index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 60,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF3B5BDB) : AppColors.card(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? const Color(0xFF3B5BDB) : AppColors.border(context),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('DAY', style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white70 : AppColors.textHint(context), letterSpacing: 0.5,
                      )),
                      Text('${index + 1}'.padLeft(2, '0'), style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : AppColors.textPrimary(context),
                      )),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // ═══ ACTIVITIES ═══
        Expanded(
          child: currentDay == null
              ? const Center(child: Text('No activities'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  itemCount: currentDay.activities.length,
                  itemBuilder: (context, index) {
                    final activity = currentDay.activities[index];
                    final isLast = index == currentDay.activities.length - 1;
                    return _buildActivityCard(activity, isLast);
                  },
                ),
        ),

        // ═══ SAVE BUTTON ═══
        Container(
          padding: EdgeInsets.only(
            left: 20, right: 20, top: 12,
            bottom: MediaQuery.of(context).padding.bottom + 12,
          ),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            boxShadow: [BoxShadow(color: Colors.black.withAlpha(13), blurRadius: 10, offset: const Offset(0, -2))],
          ),
          child: SizedBox(
            width: double.infinity, height: 54,
            child: ElevatedButton.icon(
              onPressed: _isSaved || _isSaving ? null : _saveToTrips,
              icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_outline),
              label: Text(
                _isSaving ? 'Saving...' : _isSaved ? 'Saved to Trips ✓' : 'Save to Trips',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _isSaved ? const Color(0xFF108C65) : const Color(0xFF1A2A3A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildActivityCard(Activity activity, bool isLast) {
    final imageUrl = _activityImages[activity.title] ?? '';

    // Determine time of day from icon field or time
    String timeOfDay;
    IconData timeIcon;
    final Color timeColor = const Color(0xFF3B5BDB);

    switch (activity.icon.toLowerCase()) {
      case 'morning':
        timeOfDay = 'MORNING';
        timeIcon = Icons.wb_sunny_outlined;
        break;
      case 'afternoon':
        timeOfDay = 'AFTERNOON';
        timeIcon = Icons.wb_cloudy_outlined;
        break;
      case 'evening':
        timeOfDay = 'EVENING';
        timeIcon = Icons.restaurant_outlined;
        break;
      default:
        timeOfDay = activity.time.contains('AM') ? 'MORNING' : 'AFTERNOON';
        timeIcon = Icons.schedule;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline
        SizedBox(
          width: 50,
          child: Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(color: timeColor.withAlpha(26), shape: BoxShape.circle),
              child: Icon(timeIcon, color: timeColor, size: 20),
            ),
            if (!isLast) Container(width: 2, height: 180, color: AppColors.border(context)),
          ]),
        ),

        // Content
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Time label
                Row(children: [
                  Text(timeOfDay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: timeColor, letterSpacing: 0.5)),
                  const SizedBox(width: 6),
                  Text('• ${activity.time}', style: TextStyle(fontSize: 12, color: AppColors.textHint(context))),
                ]),
                const SizedBox(height: 6),

                // Title
                Text(activity.title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                const SizedBox(height: 10),

                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl.isNotEmpty
                      ? Image.network(imageUrl, height: 160, width: double.infinity, fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => _buildImagePlaceholder(activity.title))
                      : _buildImagePlaceholder(activity.title),
                ),
                const SizedBox(height: 10),

                // Description
                Text(activity.description,
                  style: TextStyle(fontSize: 14, color: AppColors.textSecondary(context), height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePlaceholder(String title) {
    return Container(
      height: 160, width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF108C65).withAlpha(20), borderRadius: BorderRadius.circular(12),
      ),
      child: Center(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.landscape, size: 40, color: Color(0xFF108C65)),
          const SizedBox(height: 4),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Color(0xFF108C65))),
        ],
      )),
    );
  }
}
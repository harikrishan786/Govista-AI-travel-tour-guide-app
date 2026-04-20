// lib/services/destination_image_service.dart

import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class DestinationImageService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Pixabay API key (free, 100 req/min)
  static const String _pixabayKey = '54700874-905e8f80cbdd5195383e59d9c';

  final Map<String, String> _searchOverrides = {
    'manali': 'Manali Himachal Pradesh',
    'shimla': 'Shimla city',
    'kasol': 'Kasol Parvati Valley',
    'tosh': 'Tosh village Himachal',
    'malana': 'Malana village Himachal',
    'rishikesh': 'Rishikesh Uttarakhand',
    'nainital': 'Nainital lake city',
    'mussoorie': 'Mussoorie hill station',
    'srinagar': 'Dal Lake Srinagar',
    'gulmarg': 'Gulmarg Kashmir',
    'pahalgam': 'Pahalgam Kashmir',
    'leh': 'Leh Ladakh city',
    'pangong': 'Pangong Lake Ladakh',
    'nubra valley': 'Nubra Valley Ladakh',
    'dharamshala': 'McLeod Ganj Dharamshala',
    'dalhousie': 'Dalhousie Himachal Pradesh',
    'bir billing': 'Bir Billing paragliding',
    'chopta': 'Chopta Uttarakhand Tungnath',
    'auli': 'Auli ski resort Uttarakhand',
    'kedarnath': 'Kedarnath Temple',
    'badrinath': 'Badrinath Temple',
    'valley of flowers': 'Valley of Flowers National Park',
    'spiti valley': 'Spiti Valley Himachal',
    'sonamarg': 'Sonamarg Jammu Kashmir',
    'patnitop': 'Patnitop Jammu',
    'kufri': 'Kufri Shimla',
    'lansdowne': 'Lansdowne Uttarakhand',
    'corbett': 'Jim Corbett National Park',
    'tso moriri': 'Tso Moriri Lake Ladakh',
    'zanskar valley': 'Zanskar Valley Ladakh',
    'hemkund': 'Hemkund Sahib',
    'jibhi': 'Jibhi Tirthan Valley',
    'khajjiar': 'Khajjiar mini switzerland',
    'kasauli': 'Kasauli Himachal',
    'chamba': 'Chamba Himachal Pradesh',
    'sangla': 'Sangla Valley Kinnaur',
    'kalpa': 'Kalpa Kinnaur',
    'barot': 'Barot Valley Himachal',
    'turtuk': 'Turtuk village Ladakh',
    'hanle': 'Hanle Observatory Ladakh',
    'lamayuru': 'Lamayuru Monastery',
    'diskit': 'Diskit Monastery Nubra',
    'gurez valley': 'Gurez Valley Kashmir',
    'doodhpathri': 'Doodhpathri Kashmir',
    'aru valley': 'Aru Valley Pahalgam',
    'yusmarg': 'Yusmarg Kashmir',
    'devprayag': 'Devprayag confluence',
    'harsil': 'Harsil Valley Uttarakhand',
    'joshimath': 'Joshimath Uttarakhand',
    'kausani': 'Kausani Uttarakhand',
    'ranikhet': 'Ranikhet Uttarakhand',
    'bhimtal': 'Bhimtal Lake',
    'chaukori': 'Chaukori Uttarakhand',
    'pithoragarh': 'Pithoragarh Uttarakhand',
  };

  // ═══════════════════════════════════════════
  // IMAGE FETCHING — WIKIPEDIA + PIXABAY FALLBACK
  // ═══════════════════════════════════════════

  /// Try Wikipedia first, then Pixabay as fallback
  Future<String> _fetchImage(String searchQuery) async {
    final wikiImg = await _fetchWikiImage(searchQuery);
    if (wikiImg.isNotEmpty) return wikiImg;

    final pixabayImg = await _fetchPixabayImage(searchQuery);
    if (pixabayImg.isNotEmpty) return pixabayImg;

    return '';
  }

  /// Wikipedia API
  Future<String> _fetchWikiImage(String searchQuery) async {
    try {
      final url1 = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query'
        '&titles=${Uri.encodeComponent(searchQuery)}'
        '&prop=pageimages&format=json&pithumbsize=800&redirects=1',
      );
      final res1 = await http.get(url1, headers: {'User-Agent': 'GoVistaApp/1.0'})
          .timeout(const Duration(seconds: 10));
      if (res1.statusCode == 200) {
        final img = _extractWikiImage(jsonDecode(res1.body));
        if (img.isNotEmpty) return img;
      }

      final url2 = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query'
        '&generator=search&gsrsearch=${Uri.encodeComponent(searchQuery)}'
        '&gsrlimit=3&prop=pageimages&format=json&pithumbsize=800',
      );
      final res2 = await http.get(url2, headers: {'User-Agent': 'GoVistaApp/1.0'})
          .timeout(const Duration(seconds: 10));
      if (res2.statusCode == 200) {
        final img = _extractWikiImage(jsonDecode(res2.body));
        if (img.isNotEmpty) return img;
      }
    } catch (e) {
      print('Wiki error: $e');
    }
    return '';
  }

  String _extractWikiImage(Map<String, dynamic> json) {
    final pages = json['query']?['pages'] as Map<String, dynamic>?;
    if (pages == null) return '';
    for (final page in pages.values) {
      final thumb = page['thumbnail']?['source'] as String?;
      if (thumb != null && thumb.isNotEmpty) {
        return thumb.replaceAll('/800px-', '/1200px-');
      }
    }
    return '';
  }

  /// Pixabay API — free, 100 req/min, great travel photos
  Future<String> _fetchPixabayImage(String searchQuery) async {
    try {
      final url = Uri.parse(
        'https://pixabay.com/api/'
        '?key=$_pixabayKey'
        '&q=${Uri.encodeComponent(searchQuery)}'
        '&image_type=photo'
        '&orientation=horizontal'
        '&per_page=3'
        '&safesearch=true'
        '&order=popular',
      );

      final res = await http.get(url).timeout(const Duration(seconds: 10));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        final hits = json['hits'] as List<dynamic>? ?? [];

        if (hits.isNotEmpty) {
          // Use webformatURL (640px) — good quality, fast loading
          final imageUrl = hits[0]['webformatURL'] as String? ?? '';
          if (imageUrl.isNotEmpty) {
            print('  📷 Pixabay found: $searchQuery');
            return imageUrl;
          }
        }
      }
    } catch (e) {
      print('Pixabay error for "$searchQuery": $e');
    }
    return '';
  }

  /// Pixabay with multiple fallback queries
  Future<String> _fetchPixabayWithFallbacks(String placeName, String destName, String placeType, String state) async {
    // Try specific query first
    final queries = <String>[
      '$placeName $destName',
      placeName,
    ];

    // Add type-specific fallback
    final type = placeType.toLowerCase();
    if (type.contains('temple') || type.contains('religious')) {
      queries.add('$destName temple India');
      queries.add('hindu temple himalaya');
    } else if (type.contains('lake')) {
      queries.add('$destName lake');
      queries.add('mountain lake India');
    } else if (type.contains('trek') || type.contains('adventure')) {
      queries.add('$destName trekking');
      queries.add('himalaya trek mountain');
    } else if (type.contains('waterfall')) {
      queries.add('waterfall India');
    } else if (type.contains('monastery')) {
      queries.add('monastery himalaya');
    } else if (type.contains('viewpoint') || type.contains('view')) {
      queries.add('$destName mountain view');
      queries.add('himalaya mountain viewpoint');
    } else if (type.contains('market') || type.contains('shopping')) {
      queries.add('India market bazaar');
    } else if (type.contains('cafe')) {
      queries.add('mountain cafe India');
    } else if (type.contains('village')) {
      queries.add('$destName village');
      queries.add('himalaya village India');
    } else if (type.contains('hidden gem')) {
      queries.add('$destName nature');
      queries.add('$state nature India');
    } else {
      queries.add('$destName India');
      queries.add('$state landscape India');
    }

    for (final q in queries) {
      final img = await _fetchPixabayImage(q);
      if (img.isNotEmpty) return img;
      await Future.delayed(const Duration(milliseconds: 200));
    }

    return '';
  }

  bool _needsImage(String? img) {
    if (img == null || img.isEmpty) return true;
    if (img.contains('unsplash.com/photo-1626621341517')) return true;
    return false;
  }

  // ═══════════════════════════════════════════
  // STEP 1: MAIN CITY IMAGES
  // ═══════════════════════════════════════════
  Future<Map<String, int>> updateMainImagesOnly({
    required Function(String status, int current, int total) onProgress,
  }) async {
    int updated = 0, failed = 0, skipped = 0;

    try {
      final snapshot = await _firestore.collection('destinations').get();
      final total = snapshot.docs.length;
      onProgress('Found $total destinations', 0, total);

      for (int i = 0; i < total; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        final name = data['name'] as String? ?? doc.id;
        final currentImage = data['image'] as String? ?? '';

        if (!_needsImage(currentImage)) {
          skipped++;
          continue;
        }

        onProgress('Fetching $name...', i + 1, total);

        final state = data['state'] as String? ?? '';
        final query = _searchOverrides[name.toLowerCase()] ?? '$name $state';
        final newImage = await _fetchImage(query);

        if (newImage.isNotEmpty) {
          await doc.reference.update({'image': newImage});
          updated++;
        } else {
          failed++;
        }

        await Future.delayed(const Duration(milliseconds: 300));
      }
    } catch (e) {
      print('Main images error: $e');
    }

    return {'updated': updated, 'failed': failed, 'skipped': skipped};
  }

  // ═══════════════════════════════════════════
  // STEP 2: SUB-PLACE IMAGES (Wiki + Pixabay)
  // ═══════════════════════════════════════════
  Future<Map<String, int>> updateSubPlaceImages({
    required Function(String status, int current, int total) onProgress,
  }) async {
    int totalPlacesUpdated = 0, totalPlacesFailed = 0, citiesProcessed = 0;

    try {
      final snapshot = await _firestore.collection('destinations').get();
      final total = snapshot.docs.length;

      for (int i = 0; i < total; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        final destName = data['name'] as String? ?? doc.id;

        final places = data['places'] as List<dynamic>? ?? [];
        if (places.isEmpty) continue;

        onProgress('$destName (${places.length} places)...', i + 1, total);

        bool anyChanged = false;
        final updatedPlaces = <Map<String, dynamic>>[];

        for (final p in places) {
          if (p is! Map<String, dynamic>) {
            updatedPlaces.add({
              'name': p.toString(), 'type': 'Attraction', 'image': '',
              'description': '', 'rating': 4.5, 'timing': '', 'entryFee': 'Free',
            });
            continue;
          }

          final placeName = p['name'] as String? ?? '';
          final currentImg = p['image'] as String? ?? '';

          if (!_needsImage(currentImg) || placeName.isEmpty) {
            updatedPlaces.add(Map<String, dynamic>.from(p));
            continue;
          }

          // Try Wiki first, then Pixabay
          final img = await _fetchImage('$placeName $destName');

          if (img.isNotEmpty) {
            final updated = Map<String, dynamic>.from(p);
            updated['image'] = img;
            updatedPlaces.add(updated);
            anyChanged = true;
            totalPlacesUpdated++;
          } else {
            updatedPlaces.add(Map<String, dynamic>.from(p));
            totalPlacesFailed++;
          }

          await Future.delayed(const Duration(milliseconds: 300));
        }

        if (anyChanged) {
          await doc.reference.update({'places': updatedPlaces});
          citiesProcessed++;
        }
      }
    } catch (e) {
      print('Sub-place images error: $e');
    }

    return {
      'updated': totalPlacesUpdated,
      'failed': totalPlacesFailed,
      'skipped': citiesProcessed,
    };
  }

  // ═══════════════════════════════════════════
  // STEP 3: FILL REMAINING WITH PIXABAY
  // Only targets places that STILL have no image
  // Uses smart type-based fallback queries
  // ═══════════════════════════════════════════
  Future<Map<String, int>> fillRemainingWithPixabay({
    required Function(String status, int current, int total) onProgress,
  }) async {
    int updated = 0, failed = 0, alreadyHasImage = 0;

    try {
      final snapshot = await _firestore.collection('destinations').get();
      final total = snapshot.docs.length;

      for (int i = 0; i < total; i++) {
        final doc = snapshot.docs[i];
        final data = doc.data();
        final destName = data['name'] as String? ?? doc.id;
        final destState = data['state'] as String? ?? '';

        final places = data['places'] as List<dynamic>? ?? [];
        if (places.isEmpty) continue;

        // Count empty images
        int needCount = 0;
        for (final p in places) {
          if (p is Map<String, dynamic>) {
            if (_needsImage(p['image'] as String? ?? '')) needCount++;
          }
        }
        if (needCount == 0) {
          alreadyHasImage++;
          continue;
        }

        onProgress('$destName ($needCount remaining)...', i + 1, total);

        bool anyChanged = false;
        final updatedPlaces = <Map<String, dynamic>>[];

        for (final p in places) {
          if (p is! Map<String, dynamic>) {
            updatedPlaces.add({
              'name': p.toString(), 'type': 'Attraction', 'image': '',
              'description': '', 'rating': 4.5, 'timing': '', 'entryFee': 'Free',
            });
            continue;
          }

          final placeName = p['name'] as String? ?? '';
          final currentImg = p['image'] as String? ?? '';

          if (!_needsImage(currentImg) || placeName.isEmpty) {
            updatedPlaces.add(Map<String, dynamic>.from(p));
            continue;
          }

          final placeType = p['type'] as String? ?? '';

          // Use Pixabay with smart fallback queries
          final img = await _fetchPixabayWithFallbacks(
            placeName, destName, placeType, destState,
          );

          if (img.isNotEmpty) {
            final up = Map<String, dynamic>.from(p);
            up['image'] = img;
            updatedPlaces.add(up);
            anyChanged = true;
            updated++;
            print('  ✅ $placeName → Pixabay image found');
          } else {
            updatedPlaces.add(Map<String, dynamic>.from(p));
            failed++;
            print('  ❌ $placeName → no image anywhere');
          }

          // Respect Pixabay rate limit (100/min)
          await Future.delayed(const Duration(milliseconds: 400));
        }

        if (anyChanged) {
          await doc.reference.update({'places': updatedPlaces});
        }
      }
    } catch (e) {
      print('Fill remaining error: $e');
    }

    return {'updated': updated, 'failed': failed, 'skipped': alreadyHasImage};
  }

  /// Combined: main + sub-places
  Future<Map<String, int>> updateAllDestinationImages({
    required Function(String status, int current, int total) onProgress,
    bool updateSubPlaces = true,
  }) async {
    final mainResult = await updateMainImagesOnly(onProgress: onProgress);
    if (!updateSubPlaces) return mainResult;
    final subResult = await updateSubPlaceImages(onProgress: onProgress);
    return {
      'updated': (mainResult['updated'] ?? 0) + (subResult['updated'] ?? 0),
      'failed': (mainResult['failed'] ?? 0) + (subResult['failed'] ?? 0),
      'skipped': (mainResult['skipped'] ?? 0) + (subResult['skipped'] ?? 0),
    };
  }
}
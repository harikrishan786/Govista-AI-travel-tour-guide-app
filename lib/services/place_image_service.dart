import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceImageService {
  static final PlaceImageService _instance = PlaceImageService._internal();
  factory PlaceImageService() => _instance;
  PlaceImageService._internal();

  // Cache so we don't re-fetch
  final Map<String, String> _cache = {};

  /// Fetches a real image URL for a place name using Wikipedia API
  /// Returns empty string if no image found
  Future<String> getImageUrl(String placeName) async {
    // Check cache first
    if (_cache.containsKey(placeName)) {
      return _cache[placeName]!;
    }

    try {
      // Step 1: Search Wikipedia for the place
      final searchUrl = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&titles=${Uri.encodeComponent(placeName)}&prop=pageimages&format=json&pithumbsize=600&redirects=1',
      );

      final response = await http.get(
        searchUrl,
        headers: {'User-Agent': 'GoVistaApp/1.0'},
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final pages = json['query']?['pages'] as Map<String, dynamic>?;

        if (pages != null) {
          for (final page in pages.values) {
            final thumbnail = page['thumbnail']?['source'] as String?;
            if (thumbnail != null && thumbnail.isNotEmpty) {
              _cache[placeName] = thumbnail;
              return thumbnail;
            }
          }
        }
      }

      // Step 2: If exact title fails, try search API
      final searchUrl2 = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=${Uri.encodeComponent(placeName)}&gsrlimit=1&prop=pageimages&format=json&pithumbsize=600',
      );

      final response2 = await http.get(
        searchUrl2,
        headers: {'User-Agent': 'GoVistaApp/1.0'},
      );

      if (response2.statusCode == 200) {
        final json2 = jsonDecode(response2.body);
        final pages2 = json2['query']?['pages'] as Map<String, dynamic>?;

        if (pages2 != null) {
          for (final page in pages2.values) {
            final thumbnail = page['thumbnail']?['source'] as String?;
            if (thumbnail != null && thumbnail.isNotEmpty) {
              _cache[placeName] = thumbnail;
              return thumbnail;
            }
          }
        }
      }
    } catch (e) {
      print('PlaceImageService error: $e');
    }

    // No image found
    _cache[placeName] = '';
    return '';
  }

  /// Fetches images for multiple places in parallel
  Future<Map<String, String>> getImagesForPlaces(
    List<String> placeNames,
  ) async {
    final futures = <Future<MapEntry<String, String>>>[];

    for (final name in placeNames) {
      futures.add(getImageUrl(name).then((url) => MapEntry(name, url)));
    }

    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
}

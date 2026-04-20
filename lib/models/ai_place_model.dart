class AIPlace {
  final String name;
  final String description;
  final String rating;
  final double latitude;
  final double longitude;
  final String imageUrl;

  AIPlace({
    required this.name,
    required this.description,
    required this.rating,
    required this.latitude,
    required this.longitude,
    this.imageUrl = '',
  });

  factory AIPlace.fromJson(Map<String, dynamic> json) {
    return AIPlace(
      name: json['name']?.toString() ?? 'Unknown Place',
      description: json['description']?.toString() ?? '',
      rating: json['rating']?.toString() ?? '4.0',
      latitude: _parseDouble(json['latitude']),
      longitude: _parseDouble(json['longitude']),
      imageUrl: json['image_url']?.toString() ?? '',
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}

/// Simple location class to avoid depending on google_maps_flutter
class SimpleLocation {
  final double latitude;
  final double longitude;
  const SimpleLocation(this.latitude, this.longitude);
}

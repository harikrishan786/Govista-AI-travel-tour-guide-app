// lib/models/destination_model.dart
// UPDATED MODEL - Handles both old and new data formats from Firebase

import 'package:cloud_firestore/cloud_firestore.dart';

class Destination {
  final String id;
  final String name;
  final String state;
  final String region;
  final String district;
  final String description;
  final String shortDescription;
  final String image;
  final double rating;
  final String bestTime;
  final String category;
  final List<String> categories;
  final List<Place> places;
  final List<String> activities;
  final List<String> tags;
  final int altitude;
  final int popularityScore;
  final String accessibility;

  Destination({
    required this.id,
    required this.name,
    required this.state,
    this.region = '',
    this.district = '',
    required this.description,
    this.shortDescription = '',
    required this.image,
    required this.rating,
    required this.bestTime,
    required this.category,
    this.categories = const [],
    required this.places,
    required this.activities,
    this.tags = const [],
    this.altitude = 0,
    this.popularityScore = 0,
    this.accessibility = '',
  });

  /// Create Destination from Firestore document
  /// Handles multiple data format variations
  factory Destination.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    // ========== HANDLE STATE/REGION ==========
    String getState(Map<String, dynamic> data) {
      // Try 'state' field first
      if (data['state'] != null && data['state'].toString().isNotEmpty) {
        return data['state'].toString();
      }

      // Convert region to full state name
      String region = (data['region'] ?? '').toString().toLowerCase();
      switch (region) {
        case 'himachal':
          return 'Himachal Pradesh';
        case 'uttarakhand':
          return 'Uttarakhand';
        case 'kashmir':
          return 'Jammu & Kashmir';
        case 'ladakh':
          return 'Ladakh';
        default:
          return region.isNotEmpty ? region : 'Unknown';
      }
    }

    // ========== HANDLE CATEGORY ==========
    String getPrimaryCategory(dynamic categoryData) {
      if (categoryData == null) return 'Hill Station';

      if (categoryData is List && categoryData.isNotEmpty) {
        return categoryData[0].toString();
      } else if (categoryData is String && categoryData.isNotEmpty) {
        return categoryData;
      }
      return 'Hill Station';
    }

    List<String> getAllCategories(dynamic categoryData) {
      if (categoryData == null) return [];

      if (categoryData is List) {
        return categoryData.map((c) => c.toString()).toList();
      } else if (categoryData is String && categoryData.isNotEmpty) {
        return [categoryData];
      }
      return [];
    }

    // ========== HANDLE PLACES ==========
    List<Place> parsePlaces(dynamic placesData) {
      if (placesData == null) return [];

      if (placesData is List) {
        List<Place> result = [];
        for (var p in placesData) {
          try {
            if (p is Map<String, dynamic>) {
              result.add(Place.fromMap(p));
            }
          } catch (e) {
            print('⚠️ Failed to parse place: $e');
          }
        }
        return result;
      }
      return [];
    }

    // ========== HANDLE ACTIVITIES ==========
    List<String> parseStringList(dynamic listData) {
      if (listData == null) return [];

      if (listData is List) {
        return listData.map((item) => item.toString()).toList();
      }
      return [];
    }

    // ========== HANDLE IMAGE ==========
    String getImage(Map<String, dynamic> data) {
      // Try multiple field names
      if (data['image'] != null && data['image'].toString().isNotEmpty) {
        return data['image'].toString();
      }
      if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
        return data['imageUrl'].toString();
      }
      if (data['imageURL'] != null && data['imageURL'].toString().isNotEmpty) {
        return data['imageURL'].toString();
      }
      // Default placeholder
      return 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?w=800';
    }

    // ========== HANDLE RATING ==========
    double getRating(dynamic ratingData) {
      if (ratingData == null) return 0.0;
      if (ratingData is double) return ratingData;
      if (ratingData is int) return ratingData.toDouble();
      if (ratingData is String) {
        return double.tryParse(ratingData) ?? 0.0;
      }
      return 0.0;
    }

    // ========== BUILD DESTINATION ==========
    return Destination(
      id: doc.id,
      name: data['name']?.toString() ?? '',
      state: getState(data),
      region: data['region']?.toString() ?? '',
      district: data['district']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      shortDescription: data['shortDescription']?.toString() ?? '',
      image: getImage(data),
      rating: getRating(data['rating']),
      bestTime: data['bestTime']?.toString() ?? '',
      category: getPrimaryCategory(data['category']),
      categories: getAllCategories(data['category']),
      places: parsePlaces(data['places']),
      activities: parseStringList(data['activities']),
      tags: parseStringList(data['tags']),
      altitude: (data['altitude'] is int) ? data['altitude'] : 0,
      popularityScore: (data['popularityScore'] is int)
          ? data['popularityScore']
          : 0,
      accessibility: data['accessibility']?.toString() ?? '',
    );
  }

  /// Convert to Firestore map for uploading
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'state': state,
      'region': region,
      'district': district,
      'description': description,
      'shortDescription': shortDescription,
      'image': image,
      'imageUrl': image, // Store in both fields for compatibility
      'rating': rating,
      'bestTime': bestTime,
      'category': categories.isNotEmpty ? categories : [category],
      'places': places.map((p) => p.toMap()).toList(),
      'activities': activities,
      'tags': tags,
      'altitude': altitude,
      'popularityScore': popularityScore,
      'accessibility': accessibility,
    };
  }

  /// Create a copy with some fields updated
  Destination copyWith({
    String? id,
    String? name,
    String? state,
    String? description,
    String? image,
    double? rating,
    List<Place>? places,
  }) {
    return Destination(
      id: id ?? this.id,
      name: name ?? this.name,
      state: state ?? this.state,
      region: region,
      district: district,
      description: description ?? this.description,
      shortDescription: shortDescription,
      image: image ?? this.image,
      rating: rating ?? this.rating,
      bestTime: bestTime,
      category: category,
      categories: categories,
      places: places ?? this.places,
      activities: activities,
      tags: tags,
      altitude: altitude,
      popularityScore: popularityScore,
      accessibility: accessibility,
    );
  }

  @override
  String toString() {
    return 'Destination(name: $name, state: $state, places: ${places.length})';
  }
}

/// Place model for sub-locations within a destination
class Place {
  final String name;
  final String type;
  final String image;
  final String description;
  final double rating;
  final String timing;
  final String entryFee;

  Place({
    required this.name,
    required this.type,
    required this.image,
    this.description = '',
    this.rating = 0.0,
    this.timing = '',
    this.entryFee = 'Free',
  });

  factory Place.fromMap(Map<String, dynamic> map) {
    // Handle rating
    double getRating(dynamic ratingData) {
      if (ratingData == null) return 0.0;
      if (ratingData is double) return ratingData;
      if (ratingData is int) return ratingData.toDouble();
      if (ratingData is String) return double.tryParse(ratingData) ?? 0.0;
      return 0.0;
    }

    // Handle image
    String getImage(Map<String, dynamic> map) {
      if (map['image'] != null && map['image'].toString().isNotEmpty) {
        return map['image'].toString();
      }
      if (map['imageUrl'] != null && map['imageUrl'].toString().isNotEmpty) {
        return map['imageUrl'].toString();
      }
      return 'https://images.unsplash.com/photo-1626621341517-bbf3d9990a23?w=800';
    }

    return Place(
      name: map['name']?.toString() ?? '',
      type: map['type']?.toString() ?? 'Attraction',
      image: getImage(map),
      description: map['description']?.toString() ?? '',
      rating: getRating(map['rating']),
      timing: map['timing']?.toString() ?? '',
      entryFee: map['entryFee']?.toString() ?? 'Free',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type,
      'image': image,
      'description': description,
      'rating': rating,
      'timing': timing,
      'entryFee': entryFee,
    };
  }

  @override
  String toString() {
    return 'Place(name: $name, type: $type)';
  }
}

/// Itinerary model
class Itinerary {
  final String id;
  final String destinationId;
  final String title;
  final int days;
  final String description;
  final List<DayPlan> dayPlans;
  final String budget;
  final String travelTips;

  Itinerary({
    required this.id,
    required this.destinationId,
    required this.title,
    required this.days,
    required this.description,
    required this.dayPlans,
    required this.budget,
    required this.travelTips,
  });

  factory Itinerary.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

    return Itinerary(
      id: doc.id,
      destinationId: data['destinationId']?.toString() ?? '',
      title: data['title']?.toString() ?? '',
      days: (data['days'] is int) ? data['days'] : 0,
      description: data['description']?.toString() ?? '',
      dayPlans:
          (data['dayPlans'] as List<dynamic>?)
              ?.map((d) => DayPlan.fromMap(d as Map<String, dynamic>))
              .toList() ??
          [],
      budget: data['budget']?.toString() ?? '',
      travelTips: data['travelTips']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'destinationId': destinationId,
      'title': title,
      'days': days,
      'description': description,
      'dayPlans': dayPlans.map((d) => d.toMap()).toList(),
      'budget': budget,
      'travelTips': travelTips,
    };
  }
}

class DayPlan {
  final int day;
  final String title;
  final List<Activity> activities;

  DayPlan({required this.day, required this.title, required this.activities});

  factory DayPlan.fromMap(Map<String, dynamic> map) {
    return DayPlan(
      day: (map['day'] is int) ? map['day'] : 0,
      title: map['title']?.toString() ?? '',
      activities:
          (map['activities'] as List<dynamic>?)
              ?.map((a) => Activity.fromMap(a as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'title': title,
      'activities': activities.map((a) => a.toMap()).toList(),
    };
  }
}

class Activity {
  final String time;
  final String title;
  final String description;
  final String icon;

  Activity({
    required this.time,
    required this.title,
    required this.description,
    this.icon = 'place',
  });

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      time: map['time']?.toString() ?? '',
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      icon: map['icon']?.toString() ?? 'place',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'time': time,
      'title': title,
      'description': description,
      'icon': icon,
    };
  }
}

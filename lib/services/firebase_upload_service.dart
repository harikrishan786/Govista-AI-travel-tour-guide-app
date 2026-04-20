// lib/services/firebase_upload_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/destinations_data.dart';

class FirebaseUploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload all destinations to Firestore
  Future<Map<String, dynamic>> uploadAllDestinations({
    bool force = false,
  }) async {
    int successCount = 0;
    int skipCount = 0;
    int failureCount = 0;
    List<String> failedNames = [];

    print(
      '🚀 Starting upload of ${DestinationData.allDestinations.length} destinations...',
    );

    for (var destination in DestinationData.allDestinations) {
      try {
        final docId = _createDocId(destination['name'] as String);

        if (!force) {
          final docSnapshot = await _firestore
              .collection('destinations')
              .doc(docId)
              .get();
          if (docSnapshot.exists) {
            skipCount++;
            continue;
          }
        }

        final dataToUpload = _prepareDestinationData(destination);
        await _firestore
            .collection('destinations')
            .doc(docId)
            .set(dataToUpload, SetOptions(merge: force));

        successCount++;
        print('✅ Uploaded: ${destination['name']}');
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        failureCount++;
        failedNames.add(destination['name'] as String);
        print('❌ Failed: ${destination['name']} - $e');
      }
    }

    return {
      'success': successCount,
      'skipped': skipCount,
      'failed': failureCount,
      'failedNames': failedNames,
    };
  }

  /// Upload by region
  Future<Map<String, dynamic>> uploadByRegion(
    String region, {
    bool force = false,
  }) async {
    final destinations = DestinationData.getByRegion(region);
    int successCount = 0;

    for (var destination in destinations) {
      try {
        final docId = _createDocId(destination['name'] as String);
        if (!force) {
          final doc = await _firestore
              .collection('destinations')
              .doc(docId)
              .get();
          if (doc.exists) continue;
        }

        await _firestore
            .collection('destinations')
            .doc(docId)
            .set(
              _prepareDestinationData(destination),
              SetOptions(merge: force),
            );
        successCount++;
      } catch (e) {
        print('❌ Failed: ${destination['name']}');
      }
    }

    return {'success': successCount, 'total': destinations.length};
  }

  String _createDocId(String name) {
    return name
        .toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll(RegExp(r"[^a-z0-9_]"), '');
  }

  Map<String, dynamic> _prepareDestinationData(
    Map<String, dynamic> destination,
  ) {
    final categories = destination['category'] as List;
    final places = (destination['places'] as List?) ?? [];

    final formattedPlaces = places
        .map(
          (place) => {
            'name': place['name'] ?? '',
            'type': place['type'] ?? '',
            'image': place['image'] ?? '',
            'description': place['description'] ?? '',
            'rating': (place['rating'] ?? 0).toDouble(),
            'timing': place['timing'] ?? '',
            'entryFee': place['entryFee'] ?? 'Free',
          },
        )
        .toList();

    return {
      'name': destination['name'],
      'region': destination['region'],
      'state':
          destination['state'] ??
          _regionToState(destination['region'] as String),
      'district': destination['district'],
      'category': categories,
      'description': destination['description'],
      'shortDescription': destination['shortDescription'] ?? '',
      'imageUrl': destination['imageUrl'] ?? '',
      'image': destination['imageUrl'] ?? '',
      'altitude': destination['altitude'],
      'bestTime': destination['bestTime'],
      'activities': destination['activities'] ?? [],
      'rating': (destination['rating'] ?? 0).toDouble(),
      'popularityScore': destination['popularityScore'] ?? 0,
      'accessibility': destination['accessibility'] ?? '',
      'tags': destination['tags'] ?? [],
      'places': formattedPlaces,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  String _regionToState(String region) {
    switch (region.toLowerCase()) {
      case 'himachal':
        return 'Himachal Pradesh';
      case 'uttarakhand':
        return 'Uttarakhand';
      case 'kashmir':
        return 'Jammu & Kashmir';
      case 'ladakh':
        return 'Ladakh';
      default:
        return region;
    }
  }

  Future<int> getDestinationCount() async {
    final snapshot = await _firestore.collection('destinations').get();
    return snapshot.docs.length;
  }

  Future<bool> destinationsExist() async {
    final snapshot = await _firestore.collection('destinations').limit(1).get();
    return snapshot.docs.isNotEmpty;
  }

  Future<Map<String, dynamic>> smartSync() async {
    final existingDocs = await _firestore.collection('destinations').get();
    final existingIds = existingDocs.docs.map((doc) => doc.id).toSet();
    int uploadedCount = 0;

    for (var destination in DestinationData.allDestinations) {
      final docId = _createDocId(destination['name'] as String);
      if (!existingIds.contains(docId)) {
        try {
          await _firestore
              .collection('destinations')
              .doc(docId)
              .set(_prepareDestinationData(destination));
          uploadedCount++;
        } catch (e) {
          print('❌ Sync failed: ${destination['name']}');
        }
      }
    }

    return {
      'uploaded': uploadedCount,
      'existing': existingIds.length,
      'totalLocal': DestinationData.allDestinations.length,
    };
  }

  Future<int> deleteAll({bool confirmed = false}) async {
    if (!confirmed) return 0;
    final snapshot = await _firestore.collection('destinations').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    return snapshot.docs.length;
  }
}

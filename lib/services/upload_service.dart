// lib/services/upload_service.dart
// Upload destinations data to Firebase

import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/destinations_data.dart';

class UploadService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Upload ALL destinations to Firestore
  Future<int> uploadAllDestinations({bool force = false}) async {
    int successCount = 0;
    int skipCount = 0;

    print('🚀 Starting upload of ${DestinationData.allDestinations.length} destinations...');

    for (var destination in DestinationData.allDestinations) {
      try {
        final docId = destination['name']
            .toString()
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll("'", '')
            .replaceAll(',', '')
            .replaceAll('.', '');

        if (!force) {
          final docSnapshot = await _firestore.collection('destinations').doc(docId).get();
          if (docSnapshot.exists) {
            skipCount++;
            continue;
          }
        }

        final dataToUpload = Map<String, dynamic>.from(destination);
        dataToUpload['createdAt'] = FieldValue.serverTimestamp();
        dataToUpload['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('destinations').doc(docId).set(dataToUpload, SetOptions(merge: force));

        successCount++;
        print('✅ Uploaded: ${destination['name']} ($successCount)');

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('❌ Failed: ${destination['name']} - $e');
      }
    }

    print('\n📊 Upload Complete! Success: $successCount, Skipped: $skipCount');
    return successCount;
  }

  /// Upload by region
  Future<int> uploadByRegion(String region, {bool force = false}) async {
    final destinations = DestinationData.allDestinations
        .where((d) => d['region'].toString().toLowerCase() == region.toLowerCase())
        .toList();

    int successCount = 0;

    print('🚀 Uploading $region (${destinations.length} destinations)...');

    for (var destination in destinations) {
      try {
        final docId = destination['name']
            .toString()
            .toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll("'", '')
            .replaceAll(',', '');

        final dataToUpload = Map<String, dynamic>.from(destination);
        dataToUpload['createdAt'] = FieldValue.serverTimestamp();
        dataToUpload['updatedAt'] = FieldValue.serverTimestamp();

        await _firestore.collection('destinations').doc(docId).set(dataToUpload, SetOptions(merge: force));

        successCount++;
        print('✅ Uploaded: ${destination['name']}');

        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('❌ Failed: ${destination['name']} - $e');
      }
    }

    print('✅ Uploaded $successCount $region destinations');
    return successCount;
  }

  /// Get count of destinations in Firebase
  Future<int> getFirebaseCount() async {
    final snapshot = await _firestore.collection('destinations').get();
    return snapshot.docs.length;
  }

  /// Delete all destinations (use carefully!)
  Future<void> deleteAllDestinations({bool confirmed = false}) async {
    if (!confirmed) {
      print('⚠️ Call with confirmed=true to delete all destinations');
      return;
    }

    final snapshot = await _firestore.collection('destinations').get();
    for (var doc in snapshot.docs) {
      await doc.reference.delete();
    }
    print('🗑️ Deleted ${snapshot.docs.length} destinations');
  }
}

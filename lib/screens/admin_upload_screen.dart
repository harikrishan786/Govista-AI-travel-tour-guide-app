// lib/screens/admin_upload_screen.dart
// Uploads filtered Kaggle dataset to Firestore in your app's format

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/destination_image_service.dart';

class AdminUploadScreen extends StatefulWidget {
  const AdminUploadScreen({super.key});

  @override
  State<AdminUploadScreen> createState() => _AdminUploadScreenState();
}

class _AdminUploadScreenState extends State<AdminUploadScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DestinationImageService _imageService = DestinationImageService();

  bool _isUploading = false;
  String _status = 'Ready to upload';
  int _uploadedCount = 0;
  int _totalCount = 0;
  final List<String> _logs = [];

  @override
  void initState() {
    super.initState();
    _checkExistingData();
  }

  void _addLog(String message) {
    setState(() => _logs.add(message));
  }

  Future<void> _checkExistingData() async {
    try {
      final snapshot = await _firestore.collection('destinations').get();
      _addLog('📊 Firestore currently has ${snapshot.docs.length} destinations');

      final kaggleSnapshot = await _firestore.collection('destinations_kaggle').get();
      _addLog('📊 Kaggle collection has ${kaggleSnapshot.docs.length} documents');
    } catch (e) {
      _addLog('❌ Error connecting to Firestore: $e');
    }
  }

  String _regionFromState(String state) {
    switch (state) {
      case 'Himachal Pradesh':
        return 'himachal';
      case 'Uttarakhand':
        return 'uttarakhand';
      case 'Jammu and Kashmir':
        return 'kashmir';
      case 'Ladakh':
        return 'ladakh';
      default:
        return state.toLowerCase();
    }
  }

  /// Upload Kaggle dataset → 'destinations' collection (converted to app format)
  /// Also uploads raw data to 'destinations_kaggle' for AI itinerary context
  Future<void> _uploadKaggleData() async {
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _status = 'Loading dataset...';
    });
    _addLog('\n🚀 Loading Kaggle dataset...');

    try {
      // Load the filtered JSON
      final String jsonString =
          await rootBundle.loadString('assets/data/filtered_destinations.json');
      final List<dynamic> kaggleData = jsonDecode(jsonString);

      _totalCount = kaggleData.length;
      _addLog('📦 Found $_totalCount destinations in dataset');

      for (final dest in kaggleData) {
        try {
          final name = dest['destination_name'] ?? 'Unknown';
          final state = dest['state'] ?? '';
          final region = _regionFromState(state);

          // Create document ID
          final docId = name
              .toString()
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9]'), '_')
              .replaceAll(RegExp(r'_+'), '_')
              .replaceAll(RegExp(r'^_|_$'), '');

          // Convert primary_attractions → places (app format)
          final attractions = dest['primary_attractions'] as List<dynamic>? ?? [];
          final hiddenGems = dest['hidden_gems'] as List<dynamic>? ?? [];

          final List<Map<String, dynamic>> places = [];
          for (final attr in attractions) {
            places.add({
              'name': attr.toString(),
              'type': 'Attraction',
              'image': '',
              'description': '',
              'rating': 4.5,
              'timing': '',
              'entryFee': 'Free',
            });
          }
          for (final gem in hiddenGems) {
            places.add({
              'name': gem.toString(),
              'type': 'Hidden Gem',
              'image': '',
              'description': '',
              'rating': 4.3,
              'timing': '',
              'entryFee': 'Free',
            });
          }

          // Activities
          final activities = (dest['activities_available'] as List<dynamic>? ?? [])
              .map((a) => a.toString())
              .toList();

          // Best time
          final bestSeasons = (dest['best_seasons'] as List<dynamic>? ?? [])
              .map((s) => s.toString())
              .toList();
          final bestTime = bestSeasons.isNotEmpty ? bestSeasons.join(', ') : '';

          // Category from trip_types
          final tripTypes = (dest['trip_types'] as List<dynamic>? ?? [])
              .map((t) => t.toString())
              .toList();
          final category = tripTypes.isNotEmpty ? tripTypes : ['Hill Station'];

          // Tags from ideal_for
          final tags = (dest['ideal_for'] as List<dynamic>? ?? [])
              .map((t) => t.toString().replaceAll('_', ' '))
              .toList();

          // Description from local_culture + food_scene
          final localCulture = dest['local_culture']?.toString() ?? '';
          final foodScene = dest['food_scene']?.toString() ?? '';
          final description = localCulture.isNotEmpty
              ? '$localCulture${foodScene.isNotEmpty ? '\n\n$foodScene' : ''}'
              : foodScene;

          // Short description
          final uniqueExp = dest['unique_experiences']?.toString() ?? '';

          // Altitude
          final altitude = dest['altitude_m'] ?? 0;

          // Rating (use safety_rating as base, scale to 5)
          final safetyRating = dest['safety_rating'] ?? 4;
          final rating = (safetyRating is int)
              ? safetyRating.toDouble().clamp(3.0, 5.0)
              : 4.0;

          // Accessibility
          final accessibility = dest['accessibility']?.toString() ?? '';

          // ═══ UPLOAD TO 'destinations' (app format) ═══
          final appData = {
            'name': name,
            'region': region,
            'state': state,
            'district': dest['district']?.toString() ?? '',
            'category': category,
            'description': description,
            'shortDescription': uniqueExp,
            'image': '', // Will use Wikipedia images via PlaceImageService
            'imageUrl': '',
            'altitude': altitude,
            'bestTime': bestTime,
            'activities': activities,
            'rating': rating,
            'popularityScore': dest['popularity_score'] ?? 5,
            'accessibility': accessibility,
            'tags': tags,
            'places': places,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          };

          await _firestore.collection('destinations').doc(docId).set(appData);

          // ═══ UPLOAD TO 'destinations_kaggle' (raw, for AI context) ═══
          await _firestore
              .collection('destinations_kaggle')
              .doc(docId)
              .set(dest);

          setState(() {
            _uploadedCount++;
            _status = 'Uploaded $_uploadedCount / $_totalCount';
          });
          _addLog(
              '✅ $name ($state) — ${places.length} places, ${activities.length} activities');
        } catch (e) {
          _addLog('❌ Failed: ${dest['destination_name']} — $e');
        }
      }

      setState(() {
        _isUploading = false;
        _status = '🎉 Complete! Uploaded $_uploadedCount destinations';
      });
      _addLog(
          '\n🎉 DONE! $_uploadedCount destinations uploaded to Firestore');
      _addLog('📁 Collections updated: destinations + destinations_kaggle');
    } catch (e) {
      setState(() {
        _isUploading = false;
        _status = 'Error: $e';
      });
      _addLog('❌ Fatal error: $e');
    }
  }

  /// Fetch only main city images (fast — ~2 min for 76 cities)
  Future<void> _fetchMainImages() async {
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _status = 'Fetching city images from Wikipedia...';
    });
    _addLog('\n🖼️ STEP 1: Fetching main city images from Wikipedia...');
    _addLog('⏱️ ~2 minutes for 76 cities. Please keep the app open.\n');

    try {
      final result = await _imageService.updateMainImagesOnly(
        onProgress: (status, current, total) {
          setState(() {
            _status = status;
            _uploadedCount = current;
            _totalCount = total;
          });
          if (status.contains('Fetching')) {
            _addLog('🔍 [$current/$total] $status');
          }
        },
      );

      setState(() {
        _isUploading = false;
        _status = 'Done! ✅${result['updated']} updated, ❌${result['failed']} failed, ⏭️${result['skipped']} skipped';
      });
      _addLog('\n🎉 City images complete!');
      _addLog('✅ Updated: ${result['updated']}');
      _addLog('❌ No image found: ${result['failed']}');
      _addLog('⏭️ Already had images: ${result['skipped']}');
      _addLog('\n💡 Now tap "Fetch Sub-Place Images" for temples, lakes, etc.');
    } catch (e) {
      setState(() { _isUploading = false; _status = 'Error: $e'; });
      _addLog('❌ Error: $e');
    }
  }

  /// Fetch sub-place images (temples, lakes, viewpoints etc)
  Future<void> _fetchAllImages() async {
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _status = 'Fetching sub-place images from Wikipedia...';
    });
    _addLog('\n🖼️ STEP 2: Fetching sub-place images (temples, lakes, treks...)');
    _addLog('⏱️ ~10 minutes. Please keep the app open.\n');

    try {
      final result = await _imageService.updateSubPlaceImages(
        onProgress: (status, current, total) {
          setState(() {
            _status = status;
            _uploadedCount = current;
            _totalCount = total;
          });
          _addLog('🔍 [$current/$total] $status');
        },
      );

      setState(() {
        _isUploading = false;
        _status = 'Done! ✅${result['updated']} places updated, ❌${result['failed']} failed';
      });
      _addLog('\n🎉 Sub-place images complete!');
      _addLog('✅ Places updated: ${result['updated']}');
      _addLog('❌ No image found: ${result['failed']}');
      _addLog('🏙️ Cities processed: ${result['skipped']}');
    } catch (e) {
      setState(() { _isUploading = false; _status = 'Error: $e'; });
      _addLog('❌ Error: $e');
    }
  }

  /// Fill remaining 223 places using Pixabay API
  Future<void> _fillRemaining() async {
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
      _status = 'Filling remaining with Pixabay...';
    });
    _addLog('\n🖼️ STEP 3: Filling remaining empty images via Pixabay API...');
    _addLog('📷 Using smart type-based search (temple, lake, trek etc.)');
    _addLog('⏱️ ~5-10 minutes. Please keep app open.\n');

    try {
      final result = await _imageService.fillRemainingWithPixabay(
        onProgress: (status, current, total) {
          setState(() {
            _status = status;
            _uploadedCount = current;
            _totalCount = total;
          });
          _addLog('🔍 [$current/$total] $status');
        },
      );

      setState(() {
        _isUploading = false;
        _status = 'Done! ✅${result['updated']} filled, ❌${result['failed']} still empty';
      });
      _addLog('\n🎉 Pixabay fill complete!');
      _addLog('✅ Filled: ${result['updated']}');
      _addLog('❌ Still no image: ${result['failed']}');
      _addLog('⏭️ Already had images: ${result['skipped']} cities');
    } catch (e) {
      setState(() { _isUploading = false; _status = 'Error: $e'; });
      _addLog('❌ Error: $e');
    }
  }

  Future<void> _deleteAllData() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete All Data?'),
        content:
            const Text('This will delete ALL destinations from Firestore.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isUploading = true;
      _status = 'Deleting...';
    });
    _addLog('\n🗑️ Deleting all data...');

    try {
      // Delete destinations
      final snapshot = await _firestore.collection('destinations').get();
      int count = 0;
      for (var doc in snapshot.docs) {
        await doc.reference.delete();
        count++;
      }
      _addLog('✅ Deleted $count from destinations');

      // Delete kaggle collection
      final kaggleSnapshot =
          await _firestore.collection('destinations_kaggle').get();
      int kCount = 0;
      for (var doc in kaggleSnapshot.docs) {
        await doc.reference.delete();
        kCount++;
      }
      _addLog('✅ Deleted $kCount from destinations_kaggle');
    } catch (e) {
      _addLog('❌ Error: $e');
    }

    setState(() {
      _isUploading = false;
      _status = 'Deleted all data';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Upload Data to Firestore'),
        backgroundColor: const Color(0xFF1B8A6B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Status Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  _isUploading
                      ? Icons.cloud_upload
                      : _uploadedCount > 0
                          ? Icons.check_circle
                          : Icons.cloud_upload_outlined,
                  size: 48,
                  color: const Color(0xFF1B8A6B),
                ),
                const SizedBox(height: 12),
                Text(_status,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Kaggle Dataset → Firestore',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                if (_isUploading) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: _totalCount > 0 ? _uploadedCount / _totalCount : 0,
                    backgroundColor: Colors.grey.shade200,
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF1B8A6B)),
                  ),
                ],
              ],
            ),
          ),

          // Buttons Row 1
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _uploadKaggleData,
                    icon: const Icon(Icons.cloud_upload),
                    label: const Text('Upload Kaggle Data'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B8A6B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _deleteAllData,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade400,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Buttons Row 2 — Image fetching
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _fetchMainImages,
                    icon: const Icon(Icons.image, size: 18),
                    label: const Text('City Photos'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _fetchAllImages,
                    icon: const Icon(Icons.photo_library, size: 18),
                    label: const Text('Sub-Places'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6A1B9A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isUploading ? null : _fillRemaining,
                    icon: const Icon(Icons.auto_fix_high, size: 18),
                    label: const Text('Fill Rest'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE65100),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Logs
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.terminal, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      const Text('Upload Log',
                          style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      const Spacer(),
                      GestureDetector(
                        onTap: () => setState(() => _logs.clear()),
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(color: Colors.grey),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _logs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            _logs[index],
                            style: TextStyle(
                              color: _logs[index].contains('✅')
                                  ? Colors.greenAccent
                                  : _logs[index].contains('❌')
                                      ? Colors.redAccent
                                      : Colors.white70,
                              fontSize: 13,
                              fontFamily: 'monospace',
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
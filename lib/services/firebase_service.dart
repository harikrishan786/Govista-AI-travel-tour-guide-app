// lib/services/firebase_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/destination_model_fixed.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ==================== AUTHENTICATION ====================

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithEmail(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      print('Sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential?> signUpWithEmail(
    String email,
    String password,
    String name,
  ) async {
    try {
      UserCredential credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await credential.user?.updateDisplayName(name);
      return credential;
    } catch (e) {
      print('Sign up error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async => await _auth.signOut();

  Future<void> resetPassword(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // ==================== DESTINATIONS ====================

  /// Get ALL destinations from Firestore
  Future<List<Destination>> getAllDestinations() async {
    try {
      QuerySnapshot snapshot = await _firestore
          .collection('destinations')
          .get();
      print('Fetched ${snapshot.docs.length} destinations');
      return snapshot.docs
          .map((doc) => Destination.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting destinations: $e');
      return [];
    }
  }

  /// Get destinations by REGION (himachal, uttarakhand, kashmir, ladakh)
  Future<List<Destination>> getDestinationsByRegion(String region) async {
    try {
      // First try direct query
      QuerySnapshot snapshot = await _firestore
          .collection('destinations')
          .where('region', isEqualTo: region.toLowerCase())
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs
            .map((doc) => Destination.fromFirestore(doc))
            .toList();
      }

      // Fallback: get all and filter
      List<Destination> all = await getAllDestinations();
      return all.where((d) {
        String r = region.toLowerCase();
        String destRegion = d.region.toLowerCase();
        String destState = d.state.toLowerCase();

        if (r.contains('himachal') || r == 'himachal') {
          return destRegion == 'himachal' || destState.contains('himachal');
        } else if (r.contains('uttarakhand') || r == 'uttarakhand') {
          return destRegion == 'uttarakhand' ||
              destState.contains('uttarakhand');
        } else if (r.contains('kashmir') || r == 'kashmir') {
          return destRegion == 'kashmir' || destState.contains('kashmir');
        } else if (r.contains('ladakh') || r == 'ladakh') {
          return destRegion == 'ladakh' || destState.contains('ladakh');
        }
        return destRegion.contains(r) || destState.contains(r);
      }).toList();
    } catch (e) {
      print('Error getting by region: $e');
      return [];
    }
  }

  /// Get destinations by STATE name
  Future<List<Destination>> getDestinationsByState(String state) async {
    return getDestinationsByRegion(state);
  }

  /// Get destinations by CATEGORY
  Future<List<Destination>> getDestinationsByCategory(String category) async {
    try {
      List<Destination> all = await getAllDestinations();
      return all.where((d) {
        if (d.category.toLowerCase() == category.toLowerCase()) return true;
        if (d.categories.any(
          (c) => c.toLowerCase() == category.toLowerCase(),
        )) {
          return true;
        }
        return false;
      }).toList();
    } catch (e) {
      print('Error getting by category: $e');
      return [];
    }
  }

  /// Search destinations
  Future<List<Destination>> searchDestinations(String query) async {
    try {
      List<Destination> all = await getAllDestinations();
      String q = query.toLowerCase();
      return all.where((d) {
        return d.name.toLowerCase().contains(q) ||
            d.state.toLowerCase().contains(q) ||
            d.district.toLowerCase().contains(q) ||
            d.description.toLowerCase().contains(q);
      }).toList();
    } catch (e) {
      print('Error searching: $e');
      return [];
    }
  }

  /// Get top rated destinations
  Future<List<Destination>> getTopRatedDestinations({int limit = 10}) async {
    try {
      List<Destination> all = await getAllDestinations();
      all.sort((a, b) => b.rating.compareTo(a.rating));
      return all.take(limit).toList();
    } catch (e) {
      print('Error getting top rated: $e');
      return [];
    }
  }

  /// Get popular destinations
  Future<List<Destination>> getPopularDestinations({int limit = 10}) async {
    try {
      List<Destination> all = await getAllDestinations();
      all.sort((a, b) => b.popularityScore.compareTo(a.popularityScore));
      return all.take(limit).toList();
    } catch (e) {
      print('Error getting popular: $e');
      return [];
    }
  }

  /// Get single destination by ID
  Future<Destination?> getDestinationById(String id) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection('destinations')
          .doc(id)
          .get();
      if (doc.exists) return Destination.fromFirestore(doc);
      return null;
    } catch (e) {
      print('Error getting destination: $e');
      return null;
    }
  }

  // ==================== USER FAVORITES ====================

 Future<void> addToFavorites(String destinationId) async {
  if (currentUser == null) {
    print('❌ addToFavorites: No user logged in');
    return;
  }
  try {
    print('💚 Adding $destinationId to favorites for ${currentUser!.uid}');
    final docRef = _firestore.collection('users').doc(currentUser!.uid);
    final doc = await docRef.get();
    if (doc.exists) {
      await docRef.update({
        'favorites': FieldValue.arrayUnion([destinationId]),
      });
    } else {
      await docRef.set({
        'favorites': [destinationId],
      });
    }
    print('✅ Added $destinationId to favorites');
  } catch (e) {
    print('❌ Error adding to favorites: $e');
  }
}

Future<void> removeFromFavorites(String destinationId) async {
  if (currentUser == null) return;
  try {
    print('💔 Removing $destinationId from favorites');
    await _firestore.collection('users').doc(currentUser!.uid).update({
      'favorites': FieldValue.arrayRemove([destinationId]),
    });
    print('✅ Removed $destinationId from favorites');
  } catch (e) {
    print('❌ Error removing from favorites: $e');
  }
}
  Future<List<String>> getUserFavorites() async {
    if (currentUser == null) return [];
    try {
      DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return List<String>.from(data['favorites'] ?? []);
      }
      return [];
    } catch (e) {
      print('Error getting favorites: $e');
      return [];
    }
  }

  // ==================== STATS ====================

  Future<int> getDestinationCount() async {
    QuerySnapshot snapshot = await _firestore.collection('destinations').get();
    return snapshot.docs.length;
  }

  Future<bool> isFavorite(String id) async {
  if (currentUser == null) return false;
  try {
    DocumentSnapshot doc = await _firestore
        .collection('users')
        .doc(currentUser!.uid)
        .get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      List<String> favs = List<String>.from(data['favorites'] ?? []);
      return favs.contains(id);
    }
    return false;
  } catch (e) {
    print('Error checking favorite: $e');
    return false;
  }
}
}

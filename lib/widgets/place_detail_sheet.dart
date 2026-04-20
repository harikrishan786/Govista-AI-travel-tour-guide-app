// lib/widgets/place_detail_sheet.dart
// Shared bottom sheet for displaying place details with Google Maps directions

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/destination_model_fixed.dart';

class PlaceDetailSheet {
  static void show({
    required BuildContext context,
    required Place place,
    required String destinationName,
    String? imageUrl,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayImage = imageUrl ?? place.image;
    final hasValidImage = displayImage.isNotEmpty &&
        !displayImage.contains('unsplash.com/photo-1626621341517');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ IMAGE ═══
                    if (hasValidImage)
                      Image.network(
                        displayImage,
                        height: 250, width: double.infinity, fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _buildImagePlaceholder(place, isDark),
                      )
                    else
                      _buildImagePlaceholder(place, isDark),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══ NAME & RATING ═══
                          Row(
                            children: [
                              Expanded(
                                child: Text(place.name,
                                  style: TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),
                              if (place.rating > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.star, color: Colors.amber, size: 18),
                                      const SizedBox(width: 4),
                                      Text(place.rating.toString(),
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber, fontSize: 16)),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ═══ TYPE BADGE ═══
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getTypeColor(place.type).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(place.type,
                              style: TextStyle(
                                color: _getTypeColor(place.type),
                                fontWeight: FontWeight.w600, fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ═══ DESCRIPTION ═══
                          Text(
                            place.description.isNotEmpty
                                ? place.description
                                : 'A popular ${place.type.toLowerCase()} in $destinationName. '
                                  'This is one of the must-visit spots that attracts travelers '
                                  'from all over. Make sure to include it in your itinerary!',
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white70 : const Color(0xFF555555),
                              height: 1.6,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ═══ INFO CARDS ═══
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  Icons.access_time, 'Timing',
                                  place.timing.isNotEmpty ? place.timing : 'Open all day',
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  Icons.confirmation_number, 'Entry Fee',
                                  place.entryFee.isNotEmpty ? place.entryFee : 'Free',
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildInfoCard(
                                  Icons.category, 'Category',
                                  place.type,
                                  isDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildInfoCard(
                                  Icons.location_on, 'Location',
                                  destinationName,
                                  isDark,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ═══ GET DIRECTIONS BUTTON ═══
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () => _openGoogleMaps(context, place.name, destinationName),
                              icon: const Icon(Icons.directions, color: Colors.white),
                              label: const Text('Get Directions',
                                style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ═══ SEARCH ON GOOGLE BUTTON ═══
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton.icon(
                              onPressed: () => _searchOnGoogle(context, place.name, destinationName),
                              icon: Icon(Icons.travel_explore, color: isDark ? Colors.white70 : Colors.grey[700]),
                              label: Text('Search on Google',
                                style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700], fontSize: 15)),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: isDark ? Colors.white24 : Colors.grey[300]!),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildImagePlaceholder(Place place, bool isDark) {
    return Container(
      height: 200, width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getTypeColor(place.type).withOpacity(0.3),
            _getTypeColor(place.type).withOpacity(0.1),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_getTypeIcon(place.type), size: 50,
            color: _getTypeColor(place.type).withOpacity(0.5)),
          const SizedBox(height: 8),
          Text(place.name, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14,
              color: _getTypeColor(place.type).withOpacity(0.7))),
        ],
      ),
    );
  }

  static Widget _buildInfoCard(IconData icon, String title, String value, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: const Color(0xFF1E88E5), size: 22),
          const SizedBox(height: 8),
          Text(title, style: TextStyle(fontSize: 11,
            color: isDark ? Colors.white54 : const Color(0xFF999999))),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF1A1A1A)),
            maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  static Future<void> _openGoogleMaps(BuildContext context, String placeName, String destination) async {
    final query = Uri.encodeComponent('$placeName, $destination, India');
    final url = 'https://www.google.com/maps/search/?api=1&query=$query';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        // Fallback: try geo intent for Android
        final geoUrl = Uri.parse('geo:0,0?q=$query');
        if (await canLaunchUrl(geoUrl)) {
          await launchUrl(geoUrl);
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open Maps')),
          );
        }
      }
    } catch (e) {
      print('Maps launch error: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening Maps: $e')),
        );
      }
    }
  }

  static Future<void> _searchOnGoogle(BuildContext context, String placeName, String destination) async {
    final query = Uri.encodeComponent('$placeName $destination India travel');
    final url = 'https://www.google.com/search?q=$query';
    
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      print('Google search error: $e');
    }
  }

  static Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'temple': return const Color(0xFFFF9800);
      case 'adventure': return const Color(0xFF4CAF50);
      case 'viewpoint': return const Color(0xFF2196F3);
      case 'lake': return const Color(0xFF00BCD4);
      case 'waterfall': return const Color(0xFF3F51B5);
      case 'trek': return const Color(0xFF8BC34A);
      case 'monastery': return const Color(0xFF9C27B0);
      case 'village': return const Color(0xFF795548);
      case 'shopping': return const Color(0xFFE91E63);
      case 'religious': return const Color(0xFFFF5722);
      case 'historical': return const Color(0xFF607D8B);
      case 'attraction': return const Color(0xFF2196F3);
      case 'hidden gem': return const Color(0xFF009688);
      default: return const Color(0xFF1E88E5);
    }
  }

  static IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'temple': return Icons.temple_hindu;
      case 'adventure': return Icons.hiking;
      case 'viewpoint': return Icons.visibility;
      case 'lake': return Icons.water;
      case 'waterfall': return Icons.waves;
      case 'trek': return Icons.terrain;
      case 'monastery': return Icons.account_balance;
      case 'village': return Icons.home;
      case 'shopping': return Icons.shopping_bag;
      default: return Icons.place;
    }
  }
}
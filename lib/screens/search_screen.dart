import 'package:flutter/material.dart';
import '../app_theme.dart';
import '../services/firebase_service.dart';
import '../models/destination_model_fixed.dart';
import 'destination_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  final String? initialQuery;
  final String?
  filterState; // Optional: filter by state (e.g., "Himachal Pradesh")

  const SearchScreen({super.key, this.initialQuery, this.filterState});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FirebaseService _firebaseService = FirebaseService();
  final FocusNode _focusNode = FocusNode();

  List<Destination> _allDestinations = [];
  List<Destination> _filteredDestinations = [];
  List<Place> _filteredPlaces = [];
  bool _isLoading = true;
  String _selectedFilter = 'All';

  final List<String> _filters = [
    'All',
    'Hill Station',
    'Spiritual',
    'Adventure',
    'Backpacker',
    'Lake',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.initialQuery ?? '';
    _loadDestinations();

    // Auto-focus search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadDestinations() async {
    setState(() => _isLoading = true);

    try {
      List<Destination> destinations;

      if (widget.filterState != null) {
        // Load only destinations from specific state
        destinations = (await _firebaseService.getDestinationsByState(
          widget.filterState!,
        )).cast<Destination>();
      } else {
        // Load all destinations
        destinations = (await _firebaseService.getAllDestinations())
            .cast<Destination>();
      }

      setState(() {
        _allDestinations = destinations;
        _filteredDestinations = destinations;
        _isLoading = false;
      });

      // If there's an initial query, search immediately
      if (widget.initialQuery != null && widget.initialQuery!.isNotEmpty) {
        _performSearch(widget.initialQuery!);
      }
    } catch (e) {
      print('Error loading destinations: $e');
      setState(() => _isLoading = false);
    }
  }

  void _performSearch(String query) {
    if (query.isEmpty) {
      setState(() {
        _filteredDestinations = _selectedFilter == 'All'
            ? _allDestinations
            : _allDestinations
                  .where((d) => d.category == _selectedFilter)
                  .toList();
        _filteredPlaces = [];
      });
      return;
    }

    final queryLower = query.toLowerCase();

    // Search destinations
    List<Destination> matchedDestinations = _allDestinations.where((dest) {
      final matchesQuery =
          dest.name.toLowerCase().contains(queryLower) ||
          dest.state.toLowerCase().contains(queryLower) ||
          dest.category.toLowerCase().contains(queryLower) ||
          dest.description.toLowerCase().contains(queryLower);

      final matchesFilter =
          _selectedFilter == 'All' || dest.category == _selectedFilter;

      return matchesQuery && matchesFilter;
    }).toList();

    // Search places within destinations
    List<Place> matchedPlaces = [];
    for (var dest in _allDestinations) {
      for (var place in dest.places) {
        if (place.name.toLowerCase().contains(queryLower) ||
            place.type.toLowerCase().contains(queryLower)) {
          matchedPlaces.add(place);
        }
      }
    }

    setState(() {
      _filteredDestinations = matchedDestinations;
      _filteredPlaces = matchedPlaces.take(5).toList(); // Show max 5 places
    });
  }

  void _onFilterSelected(String filter) {
    setState(() => _selectedFilter = filter);
    _performSearch(_searchController.text);
  }

  void _onDestinationTapped(Destination destination) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DestinationDetailScreen(destination: destination),
      ),
    );
  }

  void _onPlaceTapped(Place place) {
    // Find which destination this place belongs to
    for (var dest in _allDestinations) {
      if (dest.places.contains(place)) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DestinationDetailScreen(destination: dest),
          ),
        );
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.background(context),
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Icon(Icons.arrow_back, color: AppColors.textPrimary(context)),
        ),
        title: Text(
          widget.filterState != null
              ? 'Search in ${widget.filterState}'
              : 'Search Destinations',
          style: TextStyle(
            color: AppColors.textPrimary(context),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.searchBar(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, color: AppColors.textHint(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      onChanged: _performSearch,
                      style: TextStyle(color: AppColors.textPrimary(context)),
                      decoration: InputDecoration(
                        hintText: 'Search places, destinations...',
                        hintStyle: TextStyle(
                          color: AppColors.textHint(context),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                      child: Icon(
                        Icons.close,
                        color: AppColors.textHint(context),
                        size: 20,
                      ),
                    ),
                ],
              ),
            ),
          ),

          // Filter Chips
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = _selectedFilter == filter;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => _onFilterSelected(filter),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.cardAlt(context),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.border(context),
                        ),
                      ),
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary(context),
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // Results
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  )
                : _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    if (_searchController.text.isEmpty && _selectedFilter == 'All') {
      return _buildAllDestinations();
    }

    if (_filteredDestinations.isEmpty && _filteredPlaces.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off,
              size: 80,
              color: AppColors.textHint(context),
            ),
            const SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try searching with different keywords',
              style: TextStyle(color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Places Results
          if (_filteredPlaces.isNotEmpty) ...[
            Text(
              'Places',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary(context),
              ),
            ),
            const SizedBox(height: 12),
            ..._filteredPlaces.map((place) => _buildPlaceItem(place)),
            const SizedBox(height: 24),
          ],

          // Destinations Results
          if (_filteredDestinations.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Destinations',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                Text(
                  '${_filteredDestinations.length} found',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._filteredDestinations.map((dest) => _buildDestinationItem(dest)),
          ],

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildAllDestinations() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'All Destinations',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary(context),
            ),
          ),
          const SizedBox(height: 12),
          ..._allDestinations.map((dest) => _buildDestinationItem(dest)),
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildDestinationItem(Destination destination) {
    return GestureDetector(
      onTap: () => _onDestinationTapped(destination),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.cardAlt(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            // Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                destination.image,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.landscape, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          destination.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary(context),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E7),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Color(0xFFE8A54B),
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              destination.rating.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFE8A54B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 14,
                        color: AppColors.textHint(context),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        destination.state,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textHint(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          destination.category,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.place, size: 14, color: AppColors.primary),
                      const SizedBox(width: 2),
                      Text(
                        '${destination.places.length} places',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textHint(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceItem(Place place) {
    return GestureDetector(
      onTap: () => _onPlaceTapped(place),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border(context)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.place,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary(context),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    place.type,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppColors.textHint(context),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

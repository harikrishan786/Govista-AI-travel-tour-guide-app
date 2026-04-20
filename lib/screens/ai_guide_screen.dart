import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:govistaofficial/services/groq_service.dart';
import 'package:govistaofficial/services/place_image_service.dart';
import 'package:govistaofficial/models/ai_place_model.dart';
import 'package:govistaofficial/models/ai_response_parser.dart';
import 'package:govistaofficial/screens/map_detail_screen.dart';
import 'package:govistaofficial/screens/home_screen.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final List<AIPlace> places;

  ChatMessage({
    required this.text,
    required this.isUser,
    this.places = const [],
  });

  /// Convert to JSON for saving
  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'places': places
            .map((p) => {
                  'name': p.name,
                  'description': p.description,
                  'rating': p.rating,
                  'latitude': p.latitude,
                  'longitude': p.longitude,
                  'image_url': p.imageUrl,
                })
            .toList(),
      };

  /// Create from saved JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final placesJson = json['places'] as List<dynamic>? ?? [];
    return ChatMessage(
      text: json['text'] ?? '',
      isUser: json['isUser'] ?? false,
      places: placesJson.map((p) => AIPlace.fromJson(p)).toList(),
    );
  }
}

/// Singleton that persists chat history to SharedPreferences (per user)
class ChatHistoryStore {
  static final ChatHistoryStore _instance = ChatHistoryStore._internal();
  factory ChatHistoryStore() => _instance;
  ChatHistoryStore._internal();

  static const String _baseStorageKey = 'govista_chat_history';
  static const String _baseImagesKey = 'govista_place_images';

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? 'guest';
  String get _storageKey => '${_baseStorageKey}_$_uid';
  String get _imagesKey => '${_baseImagesKey}_$_uid';

  final List<ChatMessage> messages = [];
  final Map<String, String> placeImages = {};
  bool _loaded = false;
  String? _loadedForUid;

  bool get isLoaded => _loaded && _loadedForUid == _uid;

  /// Load chat history from disk (call once on screen init)
  Future<void> load() async {
    // Reload if user changed (e.g. logged out and logged in as different user)
    if (_loaded && _loadedForUid == _uid && messages.isNotEmpty) return;

    // If user changed, clear in-memory data first
    if (_loadedForUid != null && _loadedForUid != _uid) {
      messages.clear();
      placeImages.clear();
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      // Load messages
      final messagesJson = prefs.getString(_storageKey);
      if (messagesJson != null && messagesJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(messagesJson);
        messages.clear();
        messages.addAll(decoded.map((m) => ChatMessage.fromJson(m)).toList());
      }

      // Load cached place images
      final imagesJson = prefs.getString(_imagesKey);
      if (imagesJson != null && imagesJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(imagesJson);
        placeImages.clear();
        decoded.forEach((k, v) => placeImages[k] = v.toString());
      }
    } catch (e) {
      debugPrint('ChatHistoryStore load error: $e');
    }

    // Add welcome message if empty
    if (messages.isEmpty) {
      messages.add(ChatMessage(
        text:
            "Hey! I'm GoVista AI — your travel buddy.\n\nAsk me about places to visit, hotels, restaurants, or anything travel-related!",
        isUser: false,
      ));
    }

    _loaded = true;
    _loadedForUid = _uid;
  }

  /// Save current chat to disk
  Future<void> save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messagesJson =
          jsonEncode(messages.map((m) => m.toJson()).toList());
      await prefs.setString(_storageKey, messagesJson);

      final imagesJson = jsonEncode(placeImages);
      await prefs.setString(_imagesKey, imagesJson);
    } catch (e) {
      debugPrint('ChatHistoryStore save error: $e');
    }
  }

  /// Clear chat and remove from disk
  Future<void> clear() async {
    messages.clear();
    placeImages.clear();
    _loaded = false;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      await prefs.remove(_imagesKey);
    } catch (e) {
      debugPrint('ChatHistoryStore clear error: $e');
    }
  }
}

class AIGuideScreen extends StatefulWidget {
  const AIGuideScreen({super.key});

  @override
  State<AIGuideScreen> createState() => _AIGuideScreenState();
}

class _AIGuideScreenState extends State<AIGuideScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GroqService _groqService = GroqService();
  final PlaceImageService _imageService = PlaceImageService();
  final ChatHistoryStore _chatStore = ChatHistoryStore();

  bool _isLoading = false;
  bool _isLoadingHistory = true;
  Position? _userPosition;

  // Voice input
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  // Shortcuts
  List<ChatMessage> get _messages => _chatStore.messages;
  Map<String, String> get _placeImages => _chatStore.placeImages;

  @override
  void initState() {
    super.initState();
    _groqService.initialize();
    _loadHistory();
    _getUserLocation();
  }

  @override
  void dispose() {
    _speech.stop();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startListening() async {
    bool available = await _speech.initialize(
      onError: (e) => setState(() => _isListening = false),
    );
    if (!available) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Speech recognition not available'), backgroundColor: Colors.red));
      return;
    }
    setState(() { _isListening = true; });
    _speech.listen(
      onResult: (result) {
        setState(() {
          _textController.text = result.recognizedWords;
        });
        // When user finishes speaking, auto-send
        if (result.finalResult && _textController.text.trim().isNotEmpty) {
          setState(() => _isListening = false);
          _sendMessage(_textController.text);
        }
      },
      listenFor: const Duration(seconds: 60),
      pauseFor: const Duration(seconds: 2),
      // No localeId — auto-detects Hindi/English/Hinglish
    );
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  // ═══ TEXT TO VOICE ═══
  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: Duration(seconds: 10)),
      );
      if (mounted) setState(() => _userPosition = pos);
    } catch (e) {
      debugPrint('Location error: $e');
    }
  }

  bool _isNearbyQuery(String text) {
    final lower = text.toLowerCase();
    return lower.contains('nearby') || lower.contains('near me') || lower.contains('near by') ||
           lower.contains('around me') || lower.contains('close to me') || lower.contains('my location') ||
           lower.contains('where i am') || lower.contains('mere paas') || lower.contains('aas paas') ||
           lower.contains('current location') || lower.contains('near here');
  }

  Future<void> _loadHistory() async {
    await _chatStore.load();
    if (mounted) {
      setState(() => _isLoadingHistory = false);
      _scrollToBottom();
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty || _isLoading) return;

    final userMessage = text.trim();

    setState(() {
      _messages.add(ChatMessage(text: userMessage, isUser: true));
      _isLoading = true;
    });
    _textController.clear();
    _scrollToBottom();

    // If user asks about nearby places, append their GPS coordinates
    String messageToSend = userMessage;
    if (_isNearbyQuery(userMessage)) {
      if (_userPosition != null) {
        messageToSend = '$userMessage\n\n[USER LOCATION: Latitude ${_userPosition!.latitude.toStringAsFixed(4)}, Longitude ${_userPosition!.longitude.toStringAsFixed(4)}. Please suggest places near these exact coordinates, not based on previous chat context. Use the GPS location to find actually nearby places within 5-15km radius.]';
      } else {
        // Try getting location now
        await _getUserLocation();
        if (_userPosition != null) {
          messageToSend = '$userMessage\n\n[USER LOCATION: Latitude ${_userPosition!.latitude.toStringAsFixed(4)}, Longitude ${_userPosition!.longitude.toStringAsFixed(4)}. Please suggest places near these exact coordinates, not based on previous chat context. Use the GPS location to find actually nearby places within 5-15km radius.]';
        } else {
          messageToSend = '$userMessage\n\n[Could not get user location. Ask the user which city or area they are currently in so you can suggest nearby places.]';
        }
      }
    }

    // Use non-streaming for complete JSON response
    final fullResponse = await _groqService.sendMessage(messageToSend);

    List<AIPlace> places = [];
    String displayText = fullResponse;

    if (AIResponseParser.containsPlaces(fullResponse)) {
      places = AIResponseParser.parsePlaces(fullResponse);
      displayText = AIResponseParser.getIntroText(fullResponse);
      debugPrint('Parsed ${places.length} places');

      // Fetch images from Wikipedia in parallel
      if (places.isNotEmpty) {
        final names = places.map((p) => p.name).toList();
        final images = await _imageService.getImagesForPlaces(names);
        _placeImages.addAll(images);
      }
    }

    setState(() {
      _isLoading = false;
      _messages.add(ChatMessage(
        text: displayText,
        isUser: false,
        places: places,
      ));
    });
    _scrollToBottom();

    // Save chat history to disk
    await _chatStore.save();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        leading: const SizedBox.shrink(),
        leadingWidth: 0,
        title: const Row(
          children: [
            Icon(Icons.assistant, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'GoVista AI',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF108C65),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () async {
              await _chatStore.clear();
              _groqService.clearHistory();
              await _chatStore.load();
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: _isLoadingHistory
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF108C65)),
            )
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length && _isLoading) {
                  return _buildLoadingBubble();
                }
                final message = _messages[index];
                if (message.isUser) {
                  return _buildUserBubble(message.text);
                } else {
                  return _buildAIBubble(message);
                }
              },
            ),
          ),
          if (_messages.length <= 1) _buildSuggestions(),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 40),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2D28) : Colors.white,
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomLeft: const Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(13),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF108C65),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Thinking...',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserBubble(String text) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, left: 60),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF108C65),
          borderRadius: BorderRadius.circular(18).copyWith(
            bottomRight: const Radius.circular(4),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  Widget _buildAIBubble(ChatMessage message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12, right: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Text bubble
            if (message.text.isNotEmpty)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E2D28) : Colors.white,
                  borderRadius: BorderRadius.circular(18).copyWith(
                    bottomLeft: const Radius.circular(4),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(13),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : Colors.grey[800],
                    height: 1.4,
                  ),
                ),
              ),

            // Place cards (horizontal scroll)
            if (message.places.isNotEmpty) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Tap a place to view on map',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: message.places.length,
                  itemBuilder: (context, index) {
                    return _buildPlaceCard(message.places[index]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceCard(AIPlace place) {
    final imageUrl = _placeImages[place.name] ?? '';
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MapDetailScreen(
              placeName: place.name,
              description: place.description,
              rating: place.rating,
              location: SimpleLocation(place.latitude, place.longitude),
              imageUrl: imageUrl.isNotEmpty ? imageUrl : null,
            ),
          ),
        );
      },
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E2D28) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(20),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image or icon header
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: SizedBox(
                height: 90,
                width: double.infinity,
                child: imageUrl.isNotEmpty
                    ? Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF108C65).withAlpha(26),
                            child: Center(
                              child: Icon(
                                _getPlaceIcon(place.name),
                                size: 40,
                                color: const Color(0xFF108C65),
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        color: const Color(0xFF108C65).withAlpha(26),
                        child: Center(
                          child: Icon(
                            _getPlaceIcon(place.name),
                            size: 40,
                            color: const Color(0xFF108C65),
                          ),
                        ),
                      ),
              ),
            ),
            // Info section
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 14),
                        const SizedBox(width: 2),
                        Text(
                          place.rating,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF108C65).withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'View',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF108C65),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSuggestions() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final suggestions = [
      'Places nearby me',
      'Hotels near my location',
      'Best restaurants in Mumbai',
      'Places to visit in Jaipur',
      'Cafes in Bangalore',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: suggestions.map((s) {
          return ActionChip(
            label: Text(s, style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black87)),
            backgroundColor: isDark ? const Color(0xFF1E3A2F) : Colors.white,
            side: BorderSide(color: const Color(0xFF108C65).withAlpha(isDark ? 180 : 77), width: isDark ? 1.5 : 1),
            onPressed: () => _sendMessage(s),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(60) : Colors.black.withAlpha(13),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _textController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: _isListening ? 'Listening...' : 'Type or tap mic to speak...',
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? const Color(0xFF2A3A34) : const Color(0xFFF5F5F5),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: _sendMessage,
              textInputAction: TextInputAction.send,
            ),
          ),
          const SizedBox(width: 8),
          // Mic button
          CircleAvatar(
            backgroundColor: _isListening ? Colors.red : const Color(0xFF108C65).withAlpha(30),
            child: IconButton(
              icon: Icon(_isListening ? Icons.stop : Icons.mic,
                color: _isListening ? Colors.white : const Color(0xFF108C65), size: 20),
              onPressed: _isListening ? _stopListening : _startListening,
            ),
          ),
          const SizedBox(width: 6),
          // Send button
          CircleAvatar(
            backgroundColor: const Color(0xFF108C65),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: () => _sendMessage(_textController.text),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPlaceIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('hotel') || lower.contains('resort') || lower.contains('inn')) {
      return Icons.hotel;
    } else if (lower.contains('restaurant') || lower.contains('cafe') ||
        lower.contains('food') || lower.contains('dhaba')) {
      return Icons.restaurant;
    } else if (lower.contains('temple') || lower.contains('mandir') ||
        lower.contains('mosque') || lower.contains('church') || lower.contains('gurudwara')) {
      return Icons.account_balance;
    } else if (lower.contains('park') || lower.contains('garden')) {
      return Icons.park;
    } else if (lower.contains('museum') || lower.contains('gallery')) {
      return Icons.museum;
    } else if (lower.contains('mall') || lower.contains('market') || lower.contains('bazaar')) {
      return Icons.shopping_bag;
    } else if (lower.contains('beach')) {
      return Icons.beach_access;
    } else if (lower.contains('fort') || lower.contains('palace') || lower.contains('qila')) {
      return Icons.castle;
    } else if (lower.contains('lake') || lower.contains('river')) {
      return Icons.water;
    } else if (lower.contains('gate') || lower.contains('monument') || lower.contains('memorial')) {
      return Icons.location_city;
    }
    return Icons.place;
  }
}
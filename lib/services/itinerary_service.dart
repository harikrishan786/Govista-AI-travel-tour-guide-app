import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:govistaofficial/models/destination_model_fixed.dart';

class ItineraryService {
  static final ItineraryService _instance = ItineraryService._internal();
  factory ItineraryService() => _instance;
  ItineraryService._internal();

  final _firestore = FirebaseFirestore.instance;

  // PUT YOUR GROQ API KEY HERE (same key as groq_service.dart)
  final String _apiKey =
      '';
  final String _model = 'llama-3.3-70b-versatile';
  final String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  Future<Map<String, dynamic>?> _getKaggleData(String cityName) async {
    try {
      final allDocs = await _firestore.collection('destinations_kaggle').get();
      for (final doc in allDocs.docs) {
        final name = (doc.data()['destination_name'] ?? '')
            .toString()
            .toLowerCase();
        if (name.contains(cityName.toLowerCase()) ||
            cityName.toLowerCase().contains(
              name.split(' ').first.toLowerCase(),
            )) {
          return doc.data();
        }
      }
    } catch (e) {
      print('Kaggle data fetch error: $e');
    }
    return null;
  }

  /// For trips longer than 3 days, generate in chunks
  Future<Itinerary?> generateItinerary({
    required String cityName,
    String? state,
    required int days,
    List<String> existingAttractions = const [],
    List<String> existingActivities = const [],
  }) async {
    if (days <= 3) {
      return _generateChunk(
        cityName: cityName,
        state: state,
        totalDays: days,
        startDay: 1,
        endDay: days,
        existingAttractions: existingAttractions,
        existingActivities: existingActivities,
        previousPlaces: [],
      );
    }

    // For 4+ days, generate in chunks of 3 to avoid token limits
    List<DayPlan> allDayPlans = [];
    List<String> usedPlaces = [];
    String title = '$cityName Trip';
    String description = '';
    String budget = '';
    String travelTips = '';

    int remaining = days;
    int currentStart = 1;

    while (remaining > 0) {
      int chunkSize = remaining > 3 ? 3 : remaining;
      int chunkEnd = currentStart + chunkSize - 1;

      final chunk = await _generateChunk(
        cityName: cityName,
        state: state,
        totalDays: days,
        startDay: currentStart,
        endDay: chunkEnd,
        existingAttractions: existingAttractions,
        existingActivities: existingActivities,
        previousPlaces: usedPlaces,
      );

      if (chunk == null) return null;

      if (currentStart == 1) {
        title = chunk.title;
        description = chunk.description;
        budget = chunk.budget;
        travelTips = chunk.travelTips;
      }

      allDayPlans.addAll(chunk.dayPlans);

      // Track used places so next chunk doesn't repeat
      for (final day in chunk.dayPlans) {
        for (final act in day.activities) {
          usedPlaces.add(act.title);
        }
      }

      currentStart = chunkEnd + 1;
      remaining -= chunkSize;
    }

    return Itinerary(
      id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
      destinationId: cityName.toLowerCase().replaceAll(' ', '_'),
      title: title,
      days: days,
      description: description,
      dayPlans: allDayPlans,
      budget: budget,
      travelTips: travelTips,
    );
  }

  Future<Itinerary?> _generateChunk({
    required String cityName,
    String? state,
    required int totalDays,
    required int startDay,
    required int endDay,
    List<String> existingAttractions = const [],
    List<String> existingActivities = const [],
    List<String> previousPlaces = const [],
  }) async {
    final kaggleData = await _getKaggleData(cityName);
    String contextBlock = '';

    if (existingAttractions.isNotEmpty) {
      contextBlock += 'Attractions: ${existingAttractions.join(', ')}\n';
    }
    if (existingActivities.isNotEmpty) {
      contextBlock += 'Activities: ${existingActivities.join(', ')}\n';
    }
    if (kaggleData != null) {
      final kAttr = kaggleData['primary_attractions'] as List<dynamic>? ?? [];
      final kAct = kaggleData['activities_available'] as List<dynamic>? ?? [];
      final kGems = kaggleData['hidden_gems'] as List<dynamic>? ?? [];
      final kSug = kaggleData['suggested_itinerary'] ?? '';
      final kFood =
          kaggleData['local_cuisine_must_try'] as List<dynamic>? ?? [];
      if (kAttr.isNotEmpty) contextBlock += 'Must-visit: ${kAttr.join(', ')}\n';
      if (kAct.isNotEmpty) contextBlock += 'Activities: ${kAct.join(', ')}\n';
      if (kGems.isNotEmpty) {
        contextBlock += 'Hidden gems: ${kGems.join(', ')}\n';
      }
      if (kSug.toString().isNotEmpty) contextBlock += 'Suggested plan: $kSug\n';
      if (kFood.isNotEmpty) contextBlock += 'Food: ${kFood.join(', ')}\n';
    }

    final stateStr = state != null && state.isNotEmpty ? ', $state' : '';
    final int chunkDays = endDay - startDay + 1;

    String avoidBlock = '';
    if (previousPlaces.isNotEmpty) {
      avoidBlock =
          '\nALREADY COVERED (do NOT repeat): ${previousPlaces.join(', ')}\n';
    }

    final prompt =
        """
Create days $startDay to $endDay of a $totalDays-day itinerary for $cityName$stateStr.

${contextBlock.isNotEmpty ? 'LOCAL DATA:\n$contextBlock' : ''}$avoidBlock
IMPORTANT: The local data above is just a starting point. Use YOUR OWN knowledge to include ALL the must-visit spots in $cityName that any experienced traveler would recommend. Don't limit yourself to only the places listed above — include famous viewpoints, forts, lakes, treks, waterfalls, and local experiences that are well-known for this destination.

Each day needs 4 activities filling the FULL day. Think like a real traveler who has ACTUALLY been to $cityName:
- 9 AM: Morning activity (temple, trek start, viewpoint)
- 12 PM: Lunch + nearby spot (name a real restaurant/cafe + what to eat)
- 3 PM: Afternoon activity (adventure sport, market, hidden gem)
- 7 PM: Evening (sunset point, mall road, dinner at specific restaurant)

Be SPECIFIC: use real place names, real cafe/restaurant names, mention dishes by name, travel times between spots, practical tips like "book paragliding a day before" or "carry cash, no ATM nearby".

For $cityName specifically, include the BEST experiences — the spots every traveler talks about AND lesser-known local favorites.

ONLY output this JSON:
```json
{
  "title": "$cityName Trip",
  "description": "One engaging line about the trip",
  "budget": "INR X-Y per day",
  "travel_tips": "2-3 key tips",
  "day_plans": [
    {
      "day": $startDay,
      "title": "Theme of the day",
      "activities": [
        {"time": "09:00 AM", "title": "Specific Place Name", "description": "2-3 vivid sentences with tips.", "icon": "morning"},
        {"time": "12:00 PM", "title": "Lunch at Specific Cafe/Restaurant", "description": "What to order and why it's great.", "icon": "afternoon"},
        {"time": "03:00 PM", "title": "Specific Place/Activity", "description": "2-3 vivid sentences.", "icon": "afternoon"},
        {"time": "07:00 PM", "title": "Evening Spot + Dinner", "description": "Sunset views and dinner details.", "icon": "evening"}
      ]
    }
  ]
}
```
Output ONLY the JSON. Exactly $chunkDays days. 4 activities each. Real places only.
""";

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': _model,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are an expert India travel planner who has personally visited every destination multiple times. You know every famous spot, hidden gem, trek, fort, lake, cafe, and local experience. When creating itineraries, you ALWAYS include the top must-visit places that the destination is famous for — never miss iconic spots. Output ONLY valid JSON. Be specific — real names, real prices, real tips.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'temperature': 0.8,
          'max_tokens': 4096,
        }),
      );
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final content = json['choices'][0]['message']['content'] as String;
        return _parseItinerary(cityName, totalDays, content);
      } else {
        print('Groq error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Itinerary error: $e');
      return null;
    }
  }

  Itinerary? _parseItinerary(String cityName, int days, String content) {
    try {
      String jsonString = content;
      if (content.contains('```json')) {
        final start = content.indexOf('```json') + 7;
        final end = content.indexOf('```', start);
        jsonString = content.substring(start, end != -1 ? end : content.length);
      } else if (content.contains('```')) {
        final start = content.indexOf('```') + 3;
        final end = content.indexOf('```', start);
        jsonString = content.substring(start, end != -1 ? end : content.length);
      }
      jsonString = jsonString.trim();
      jsonString = jsonString.replaceAll(RegExp(r',\s*\]'), ']');
      jsonString = jsonString.replaceAll(RegExp(r',\s*\}'), '}');

      // Try to fix incomplete JSON (truncated by token limit)
      int braceCount = 0;
      int bracketCount = 0;
      for (var ch in jsonString.runes) {
        if (ch == 123) braceCount++; // {
        if (ch == 125) braceCount--; // }
        if (ch == 91) bracketCount++; // [
        if (ch == 93) bracketCount--; // ]
      }
      // Close unclosed brackets/braces
      while (bracketCount > 0) {
        jsonString += ']';
        bracketCount--;
      }
      while (braceCount > 0) {
        jsonString += '}';
        braceCount--;
      }

      final Map<String, dynamic> parsed = jsonDecode(jsonString);
      final dayPlansJson = parsed['day_plans'] as List<dynamic>;
      final dayPlans = dayPlansJson.map((d) {
        final acts = d['activities'] as List<dynamic>? ?? [];
        return DayPlan(
          day: d['day'] ?? 1,
          title: d['title'] ?? 'Day ${d['day'] ?? 1}',
          activities: acts
              .map(
                (a) => Activity(
                  time: a['time'] ?? '',
                  title: a['title'] ?? '',
                  description: a['description'] ?? '',
                  icon: a['icon'] ?? 'place',
                ),
              )
              .toList(),
        );
      }).toList();

      return Itinerary(
        id: 'gen_${DateTime.now().millisecondsSinceEpoch}',
        destinationId: cityName.toLowerCase().replaceAll(' ', '_'),
        title: parsed['title'] ?? '$cityName Trip',
        days: days,
        description: parsed['description'] ?? '',
        dayPlans: dayPlans,
        budget: parsed['budget'] ?? '',
        travelTips: parsed['travel_tips'] ?? '',
      );
    } catch (e) {
      print('Parse error: $e');
      print('Raw: ${content.substring(0, content.length.clamp(0, 500))}');
      return null;
    }
  }
}

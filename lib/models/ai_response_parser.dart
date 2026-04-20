import 'dart:convert';
import 'ai_place_model.dart';

class AIResponseParser {
  /// Check if the response contains place data (JSON array)
  static bool containsPlaces(String response) {
    // Check for various JSON block formats
    if (response.contains('```json')) return true;
    if (response.contains('```JSON')) return true;
    if (response.contains('```')) {
      // Check if there's a JSON array inside any code block
      final blockStart = response.indexOf('```');
      final blockEnd = response.indexOf('```', blockStart + 3);
      if (blockEnd != -1) {
        final blockContent = response.substring(blockStart, blockEnd);
        if (blockContent.contains('"latitude"') &&
            blockContent.contains('"longitude"')) {
          return true;
        }
      }
    }
    // Check for raw JSON array (no code block)
    if (response.contains('"latitude"') &&
        response.contains('"longitude"') &&
        response.contains('[')) {
      return true;
    }
    return false;
  }

  /// Extract the intro text (before the JSON block)
  static String getIntroText(String response) {
    // Try ```json first
    int jsonStart = response.indexOf('```json');
    if (jsonStart == -1) jsonStart = response.indexOf('```JSON');
    if (jsonStart == -1) jsonStart = response.indexOf('```\n[');
    if (jsonStart == -1) jsonStart = response.indexOf('```\r\n[');

    // If still not found, look for raw JSON array
    if (jsonStart == -1) {
      // Find where the JSON array starts
      final arrayStart = response.indexOf('[');
      if (arrayStart != -1 && response.contains('"latitude"')) {
        jsonStart = arrayStart;
      }
    }

    if (jsonStart == -1) return response;

    String intro = response.substring(0, jsonStart).trim();
    // Clean up any trailing markers
    intro = intro.replaceAll('```', '').trim();
    return intro.isEmpty ? 'Here are some places for you!' : intro;
  }

  /// Parse the JSON block and return list of AIPlace
  static List<AIPlace> parsePlaces(String response) {
    try {
      String jsonString = '';

      // Method 1: Extract from ```json ... ``` block
      int jsonStart = response.indexOf('```json');
      if (jsonStart == -1) jsonStart = response.indexOf('```JSON');

      if (jsonStart != -1) {
        // Skip past the ```json tag
        final contentStart = response.indexOf('\n', jsonStart);
        if (contentStart == -1) return [];
        final jsonEnd = response.indexOf('```', contentStart + 1);
        if (jsonEnd == -1) {
          // No closing ```, take everything after ```json
          jsonString = response.substring(contentStart).trim();
        } else {
          jsonString = response.substring(contentStart, jsonEnd).trim();
        }
      }

      // Method 2: Extract from ``` ... ``` block (no language tag)
      if (jsonString.isEmpty) {
        final blockStart = response.indexOf('```');
        if (blockStart != -1) {
          final contentStart = response.indexOf('\n', blockStart);
          if (contentStart != -1) {
            final blockEnd = response.indexOf('```', contentStart + 1);
            if (blockEnd != -1) {
              jsonString = response.substring(contentStart, blockEnd).trim();
            }
          }
        }
      }

      // Method 3: Find raw JSON array
      if (jsonString.isEmpty) {
        final arrayStart = response.indexOf('[');
        final arrayEnd = response.lastIndexOf(']');
        if (arrayStart != -1 && arrayEnd != -1 && arrayEnd > arrayStart) {
          jsonString = response.substring(arrayStart, arrayEnd + 1).trim();
        }
      }

      if (jsonString.isEmpty) {
        print('AIResponseParser: No JSON found in response');
        return [];
      }

      // Clean up common issues
      jsonString = jsonString
          .replaceAll('\r\n', '\n')
          .replaceAll('\r', '\n')
          .trim();

      // Remove any leading non-JSON characters (like language tag on same line)
      if (!jsonString.startsWith('[')) {
        final bracketIndex = jsonString.indexOf('[');
        if (bracketIndex != -1) {
          jsonString = jsonString.substring(bracketIndex);
        }
      }

      // Fix trailing comma before ] (common LLM mistake)
      jsonString = jsonString.replaceAll(RegExp(r',\s*\]'), ']');
      jsonString = jsonString.replaceAll(RegExp(r',\s*\}'), '}');

      print(
        'AIResponseParser: Attempting to parse JSON of length ${jsonString.length}',
      );

      final List<dynamic> jsonList = jsonDecode(jsonString);
      final places = jsonList
          .map((item) => AIPlace.fromJson(item as Map<String, dynamic>))
          .toList();

      print('AIResponseParser: Successfully parsed ${places.length} places');
      return places;
    } catch (e) {
      print('AIResponseParser ERROR: $e');
      return [];
    }
  }
}

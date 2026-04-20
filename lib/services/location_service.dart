import 'package:geolocator/geolocator.dart';

class LocationService {
  Future<String?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // 1. Check if GPS is on
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return "Location services are disabled. Please enable GPS.";
    }

    // 2. Check Permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return "Location permissions are denied.";
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return "Location permissions are permanently denied. Please check settings.";
    }

    // 3. Get Position
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      // Return a string formatted for Gemini
      return "My current coordinates are: ${position.latitude}, ${position.longitude}";
    } catch (e) {
      return "Error getting location: $e";
    }
  }
}

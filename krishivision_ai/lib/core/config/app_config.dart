class AppConfig {
  // Configured FastAPI Backend Base URL
  static const String backendBaseUrl = String.fromEnvironment(
    'BACKEND_URL',
    defaultValue: 'https://krishivision-backend.onrender.com',
  );

  // Configured Google Maps API Key for Android/iOS
  static const String googleMapsApiKey = String.fromEnvironment(
    'MAPS_API_KEY',
    defaultValue: 'YOUR_API_KEY',
  );

  static bool get isGoogleMapsEnabled {
    return googleMapsApiKey.isNotEmpty &&
        googleMapsApiKey != "YOUR_API_KEY" &&
        googleMapsApiKey != "PLACEHOLDER_KEY" &&
        googleMapsApiKey != "YOUR_API_KEY_HERE" &&
        googleMapsApiKey != "YOUR_GOOGLE_MAPS_API_KEY";
  }
}

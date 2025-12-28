/// Uygulama genelinde kullanılan sabit değerler
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'Indoor Navigation';
  static const String appVersion = '1.0.0';

  // Map Settings
  static const double defaultMapScale = 1.0;
  static const double minMapScale = 0.5;
  static const double maxMapScale = 3.0;
  static const double mapPadding = 20.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 600);
  static const Duration locationUpdateAnimation = Duration(milliseconds: 300);

  // User Location Marker
  static const double userMarkerSize = 24.0;
  static const double userMarkerPulseSize = 48.0;
  static const double beaconMarkerSize = 16.0;
  static const double destinationMarkerSize = 28.0;

  // Navigation
  static const double pathStrokeWidth = 4.0;
  static const double arrivalThreshold = 2.0; // meters

  // WebSocket Message Types
  static const String msgTypeLocation = 'LOCATION_UPDATE';
  static const String msgTypeBeacons = 'BEACON_DATA';
  static const String msgTypeNavigation = 'NAVIGATION_PATH';
  static const String msgTypeError = 'ERROR';
  static const String msgTypeConnected = 'CONNECTED';

  // Storage Keys
  static const String keyLastDestination = 'last_destination';
  static const String keyFavoriteLocations = 'favorite_locations';
}

/// WebSocket mesaj tipleri
enum WebSocketMessageType {
  locationUpdate,
  beaconData,
  navigationPath,
  error,
  connected,
}

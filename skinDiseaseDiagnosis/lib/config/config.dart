class Config {
  static bool isInitialized = false;

  // Configuration variables
  static String apiUrl = '';

  // Initialize configuration
  static Future<void> initialize() async {
    try {
      // Set your configuration values here
      apiUrl = 'https://ebranursayar.com/api';

      // Mark as initialized
      isInitialized = true;
      print('Config initialized successfully');
    } catch (e) {
      print('Config initialization error: $e');
      rethrow;
    }
  }
}

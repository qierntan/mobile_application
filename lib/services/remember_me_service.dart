import 'package:shared_preferences/shared_preferences.dart';

class RememberMeService {
  static const String _usernameKey = 'remembered_username';
  static const String _passwordKey = 'remembered_password';
  static const String _rememberMeKey = 'remember_me';
  static const String _savedDateKey = 'saved_date';

  // Duration for which credentials are stored (3 days)
  static const int _storeDurationDays = 3;

  /// Save username and password with current timestamp if remember me is checked
  static Future<void> saveCredentials({
    required String username,
    required String password,
    required bool rememberMe,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    if (rememberMe) {
      await prefs.setString(_usernameKey, username);
      await prefs.setString(_passwordKey, password);
      await prefs.setBool(_rememberMeKey, true);
      await prefs.setString(_savedDateKey, DateTime.now().toIso8601String());
    } else {
      // Clear saved credentials if remember me is not checked
      await clearCredentials();
    }
  }

  /// Get saved credentials if they are still valid (within 3 days)
  static Future<Map<String, dynamic>> getSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();

    // Check if remember me was enabled
    final rememberMe = prefs.getBool(_rememberMeKey) ?? false;
    if (!rememberMe) {
      return {
        'username': '',
        'password': '',
        'rememberMe': false,
        'isValid': false,
      };
    }

    // Check if the saved date exists and is within 3 days
    final savedDateString = prefs.getString(_savedDateKey);
    if (savedDateString == null) {
      await clearCredentials();
      return {
        'username': '',
        'password': '',
        'rememberMe': false,
        'isValid': false,
      };
    }

    final savedDate = DateTime.parse(savedDateString);
    final currentDate = DateTime.now();
    final daysDifference = currentDate.difference(savedDate).inDays;

    // If more than 3 days have passed, clear credentials
    if (daysDifference >= _storeDurationDays) {
      await clearCredentials();
      return {
        'username': '',
        'password': '',
        'rememberMe': false,
        'isValid': false,
      };
    }

    // Return saved credentials if still valid
    final username = prefs.getString(_usernameKey) ?? '';
    final password = prefs.getString(_passwordKey) ?? '';

    return {
      'username': username,
      'password': password,
      'rememberMe': true,
      'isValid': true,
    };
  }

  /// Clear all saved credentials
  static Future<void> clearCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_usernameKey);
    await prefs.remove(_passwordKey);
    await prefs.remove(_rememberMeKey);
    await prefs.remove(_savedDateKey);
  }

  /// Check if credentials are still valid without returning them
  static Future<bool> areCredentialsValid() async {
    final credentials = await getSavedCredentials();
    return credentials['isValid'] as bool;
  }
}

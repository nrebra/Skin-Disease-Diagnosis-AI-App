import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'config_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TokenManager {
  static final TokenManager _instance = TokenManager._internal();
  factory TokenManager() => _instance;
  TokenManager._internal();

  String? _token;
  Timer? _refreshTimer;
  bool _isRefreshing = false;
  final _tokenChangeListeners = <Function(String?)>[];
  final _refreshCompleter = Completer<void>();
  bool _isInitialized = false;

  String? get token => _token;

  void addTokenChangeListener(Function(String?) listener) {
    _tokenChangeListeners.add(listener);
  }

  void removeTokenChangeListener(Function(String?) listener) {
    _tokenChangeListeners.remove(listener);
  }

  void _notifyTokenChange(String? newToken) {
    for (var listener in _tokenChangeListeners) {
      listener(newToken);
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString('token');

      if (_token != null && _token!.isNotEmpty) {
        _notifyTokenChange(_token);
        _startRefreshTimer();
      } else {}

      _isInitialized = true;
      if (!_refreshCompleter.isCompleted) {
        _refreshCompleter.complete();
      }
    } catch (e) {
      if (!_refreshCompleter.isCompleted) {
        _refreshCompleter.completeError(e);
      }
    }
  }

  Future<void> setToken(String token) async {
    try {
      _token = token;
      _notifyTokenChange(token);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);

      _refreshTimer?.cancel();
      _startRefreshTimer();
    } catch (e) {}
  }

  Future<void> saveUserCredentials(String email, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_email', email);
      await prefs.setString('user_password', password);
    } catch (e) {}
  }

  Future<void> clearToken() async {
    try {
      final oldToken = _token;
      _token = null;
      _refreshTimer?.cancel();

      if (oldToken != null) {
        _notifyTokenChange(null);
      }

      await _clearSession();
    } catch (e) {}
  }

  Future<void> _clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user_email');
      await prefs.remove('user_password');
      await prefs.remove('user_id');
      await prefs.remove('user_role');
      await prefs.remove('user_name');
      await prefs.remove('user_surname');
      await prefs.remove('user_tcid');
      await prefs.remove('doctor_id');
      await prefs.remove('doctor_name');
    } catch (e) {}
  }

  Future<bool> refreshToken() async {
    if (_isRefreshing) {
      await Future.delayed(Duration(milliseconds: 100));
      return _token != null;
    }

    _isRefreshing = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('user_email');
      final password = prefs.getString('user_password');

      if (email == null || password == null) {
        await clearToken();
        return false;
      }

      final loginUrl = '${ConfigService.baseUrl}/login';
      final response = await http.post(
        Uri.parse(loginUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newToken = responseData['token'];

        if (newToken != null) {
          await setToken(newToken);
          return true;
        }
      }

      await clearToken();
      return false;
    } catch (e) {
      await clearToken();
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  Future<bool> isTokenValid() async {
    if (_token == null || _token!.isEmpty) {
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastCheckTime = prefs.getInt('token_last_check_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastCheckTime < 30 * 60 * 1000) {
      return true;
    }

    await prefs.setInt('token_last_check_time', now);

    return true;
  }

  Future<String?> getValidToken() async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      if (_token != null) {
        if (await isTokenValid()) {
          return _token;
        } else {
          final refreshed = await refreshToken();
          if (refreshed) {
            return _token;
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(Duration(minutes: 50), (_) async {
      await refreshToken();
    });
  }
}

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class StorageService {
  static final StorageService _instance = StorageService._internal();
  factory StorageService() => _instance;

  late FlutterSecureStorage _secureStorage;
  late Box<UserModel> _userBox;
  late SharedPreferences _prefs;

  StorageService._internal() {
    _secureStorage = const FlutterSecureStorage();
  }

  Future<void> initialize() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserModelAdapter());
    }
    _userBox = await Hive.openBox<UserModel>('userBox');
    _prefs = await SharedPreferences.getInstance();
  }

  Future<void> saveToken(String token) async {
    await _secureStorage.write(key: 'jwt_token', value: token);
  }

  Future<String?> getToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  Future<void> deleteToken() async {
    await _secureStorage.delete(key: 'jwt_token');
  }

  Future<void> saveUser(UserModel user) async {
    await _userBox.put('current_user', user);
  }

  UserModel? getUser() {
    return _userBox.get('current_user');
  }

  Future<void> deleteUser() async {
    await _userBox.delete('current_user');
  }

  Future<void> saveSetting(String key, dynamic value) async {
    if (value is bool) {
      await _prefs.setBool(key, value);
    } else if (value is String) {
      await _prefs.setString(key, value);
    } else if (value is int) {
      await _prefs.setInt(key, value);
    } else if (value is double) {
      await _prefs.setDouble(key, value);
    }
  }

  T? getSetting<T>(String key) {
    return _prefs.get(key) as T?;
  }

  Future<void> deleteSetting(String key) async {
    await _prefs.remove(key);
  }

  Future<void> clearSession() async {
    try {
      await deleteToken();

      await deleteUser();

      await _prefs.remove('user_email');
      await _prefs.remove('user_password');
      await _prefs.remove('user_id');
      await _prefs.remove('user_role');
      await _prefs.remove('user_name');
      await _prefs.remove('user_surname');
      await _prefs.remove('user_tcid');
      await _prefs.remove('doctor_id');
      await _prefs.remove('doctor_name');
    } catch (e) {
      throw Exception('Oturum temizlenemedi: $e');
    }
  }
}

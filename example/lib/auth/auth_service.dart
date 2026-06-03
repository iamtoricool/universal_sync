import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  final Dio _dio;
  AuthService(this._dio);

  Future<
    ({String accessToken, String refreshToken, String userId, String email})
  >
  signup({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/signup',
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;
    return (
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      userId: data['user']['id'] as String,
      email: data['user']['email'] as String,
    );
  }

  Future<
    ({String accessToken, String refreshToken, String userId, String email})
  >
  signin({required String email, required String password}) async {
    final response = await _dio.post(
      '/auth/signin',
      data: {'email': email, 'password': password},
    );
    final data = response.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;
    return (
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      userId: data['user']['id'] as String,
      email: data['user']['email'] as String,
    );
  }

  Future<({String accessToken, String refreshToken})> refresh(
    String refreshToken,
  ) async {
    final response = await _dio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;
    return (
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  Future<void> signout(String refreshToken) async {
    await _dio.post('/auth/signout', data: {'refreshToken': refreshToken});
  }
}

class AuthTokenStorage {
  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';

  static Future<void> saveAccessToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_accessKey, token);
  }

  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<void> saveRefreshToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_refreshKey, token);
  }

  static Future<String?> getRefreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_refreshKey);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }
}

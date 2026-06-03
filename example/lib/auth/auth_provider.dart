import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import '../config.dart';
import 'auth_service.dart';
import 'auth_interceptor.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final String? userId;
  final String? email;
  const AuthState({required this.status, this.userId, this.email});
  const AuthState.unknown()
    : status = AuthStatus.unknown,
      userId = null,
      email = null;
  AuthState copyWith({AuthStatus? status, String? userId, String? email}) =>
      AuthState(
        status: status ?? this.status,
        userId: userId ?? this.userId,
        email: email ?? this.email,
      );
}

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConfig.serverBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ),
  );
  dio.interceptors.add(AuthInterceptor());
  dio.interceptors.add(PrettyDioLogger(requestBody: true, responseBody: true));
  return dio;
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(ref.watch(dioProvider));
});

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthService _authService;
  AuthNotifier(this._authService) : super(const AuthState.unknown());

  Future<void> checkAuth() async {
    final token = await AuthTokenStorage.getAccessToken();
    state = token != null
        ? const AuthState(status: AuthStatus.authenticated)
        : const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<String?> signin({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authService.signin(
        email: email,
        password: password,
      );
      await AuthTokenStorage.saveAccessToken(result.accessToken);
      await AuthTokenStorage.saveRefreshToken(result.refreshToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: result.userId,
        email: result.email,
      );
      return null;
    } on DioException catch (e) {
      final data = e.response?.data as Map<String, dynamic>?;
      return data?['error'] as String? ?? 'Sign in failed';
    }
  }

  Future<String?> signup({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _authService.signup(
        email: email,
        password: password,
      );
      await AuthTokenStorage.saveAccessToken(result.accessToken);
      await AuthTokenStorage.saveRefreshToken(result.refreshToken);
      state = AuthState(
        status: AuthStatus.authenticated,
        userId: result.userId,
        email: result.email,
      );
      return null;
    } on DioException catch (e) {
      final data = e.response?.data as Map<String, dynamic>?;
      return data?['error'] as String? ?? 'Sign up failed';
    }
  }

  Future<void> signout() async {
    final rt = await AuthTokenStorage.getRefreshToken();
    if (rt != null) {
      try {
        await _authService.signout(rt);
      } catch (_) {}
    }
    await AuthTokenStorage.clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  return AuthNotifier(ref.watch(authServiceProvider));
});

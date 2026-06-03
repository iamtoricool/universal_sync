import 'package:dio/dio.dart';
import 'auth_service.dart';

class AuthInterceptor extends Interceptor {
  static Future<({String accessToken, String refreshToken})>? _refreshFuture;
  static final _pendingRequests =
      <({RequestOptions options, ErrorInterceptorHandler handler})>[];

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await AuthTokenStorage.getAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode != 401) {
      handler.next(err);
      return;
    }
    final path = err.requestOptions.path;
    if (path == '/auth/signin' || path == '/auth/signup') {
      handler.next(err);
      return;
    }

    if (_refreshFuture != null) {
      _pendingRequests.add((options: err.requestOptions, handler: handler));
      return;
    }

    final refreshToken = await AuthTokenStorage.getRefreshToken();
    if (refreshToken == null) {
      handler.next(err);
      return;
    }

    _refreshFuture = _doRefresh(refreshToken, err.requestOptions.baseUrl);
    try {
      final tokens = await _refreshFuture!;
      await _retryWithToken(err, handler, tokens.accessToken);
      await _resolvePending(tokens.accessToken);
    } catch (_) {
      await AuthTokenStorage.clear();
      _rejectPending(err);
      handler.next(err);
    } finally {
      _refreshFuture = null;
      _pendingRequests.clear();
    }
  }

  Future<({String accessToken, String refreshToken})> _doRefresh(
    String refreshToken,
    String baseUrl,
  ) async {
    final refreshDio = Dio(BaseOptions(baseUrl: baseUrl));
    final response = await refreshDio.post(
      '/auth/refresh',
      data: {'refreshToken': refreshToken},
    );
    final data = response.data as Map<String, dynamic>;
    final tokens = data['tokens'] as Map<String, dynamic>;
    await AuthTokenStorage.saveAccessToken(tokens['accessToken'] as String);
    await AuthTokenStorage.saveRefreshToken(tokens['refreshToken'] as String);
    return (
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
    );
  }

  Future<void> _retryWithToken(
    DioException err,
    ErrorInterceptorHandler handler,
    String token,
  ) async {
    err.requestOptions.headers['Authorization'] = 'Bearer $token';
    final response = await Dio().fetch(err.requestOptions);
    handler.resolve(response);
  }

  Future<void> _resolvePending(String token) async {
    for (final pending in _pendingRequests) {
      pending.options.headers['Authorization'] = 'Bearer $token';
      try {
        final r = await Dio().fetch(pending.options);
        pending.handler.resolve(r);
      } catch (e) {
        pending.handler.next(
          DioException(requestOptions: pending.options, error: e),
        );
      }
    }
  }

  void _rejectPending(DioException originalError) {
    for (final pending in _pendingRequests) {
      pending.handler.next(
        DioException(
          requestOptions: pending.options,
          response: originalError.response,
          type: originalError.type,
          error: originalError.error,
        ),
      );
    }
  }
}

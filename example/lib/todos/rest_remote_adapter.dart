import 'package:dio/dio.dart';
import 'package:universal_sync/universal_sync.dart';

class RestRemoteAdapter implements RemoteAdapter {
  final Dio dio;
  RestRemoteAdapter({required this.dio});

  @override
  Future<PushResponse> push(PushRequest request) async {
    final response = await dio.post('/sync/push', data: request.toJson());
    return PushResponse.fromJson(response.data as Map<String, dynamic>);
  }

  @override
  Future<PullResponse> pull(PullRequest request) async {
    final response = await dio.get(
      '/sync/pull',
      queryParameters: {
        'entityType': request.entityType,
        'sinceSequence': request.sinceSequence.toString(),
      },
    );
    return PullResponse.fromJson(response.data as Map<String, dynamic>);
  }
}

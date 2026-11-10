import 'package:dio/dio.dart';
import 'package:onset/services/integrity/integrity_token_provider.dart';

enum IntegrityStage { mintTimedOut, mintFailed, sessionChanged, retryRefused }

class IntegrityTrace {
  IntegrityStage? stage;
}

class IntegrityRetryInterceptor extends Interceptor {
  IntegrityRetryInterceptor({required this.dio, required this.tokens});

  final Dio dio;
  final IntegrityTokenProvider tokens;

  static const userActionKey = 'onsetUserAction';
  static const retriedKey = 'onsetIntegrityRetried';
  static const traceKey = 'onsetIntegrityTrace';

  static Map<String, Object?> tracedUserAction(IntegrityTrace trace) => {
    userActionKey: true,
    traceKey: trace,
  };

  static const Map<String, Object?> userAction = {userActionKey: true};

  static const backgroundOperations = {'UpdateUserViewedVideo'};

  static const refusalText = 'failed integrity check';

  static final _mutation = RegExp(r'^\s*mutation\b');

  @override
  Future<void> onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) async {
    final request = response.requestOptions;
    final webToken = userMutationWebToken(request);
    if (webToken == null || !isIntegrityRefusal(response.data)) {
      handler.next(response);
      return;
    }
    final trace = request.extra[traceKey];
    final mint = await tokens.mintFor(webToken);
    final token = mint.token;
    if (token == null) {
      if (trace is IntegrityTrace) trace.stage = _stageOf(mint.failure);
      handler.next(response);
      return;
    }
    try {
      final retried = await dio.fetch<dynamic>(
        request.copyWith(
          headers: {
            ...request.headers,
            'Client-Integrity': token.value,
            'X-Device-Id': token.deviceId,
          },
          extra: {...request.extra, retriedKey: true},
        ),
      );
      if (isIntegrityRefusal(retried.data)) {
        tokens.invalidate();
        if (trace is IntegrityTrace) trace.stage = IntegrityStage.retryRefused;
      }
      handler.resolve(retried);
    } on DioException catch (e) {
      handler.reject(e);
    }
  }

  static IntegrityStage _stageOf(IntegrityMintFailure? failure) =>
      switch (failure) {
        IntegrityMintFailure.timedOut => IntegrityStage.mintTimedOut,
        IntegrityMintFailure.sessionChanged => IntegrityStage.sessionChanged,
        _ => IntegrityStage.mintFailed,
      };

  static bool isIntegrityRefusal(Object? body) {
    if (body is! Map) return false;
    final errors = body['errors'];
    if (errors is! List) return false;
    return errors.any(
      (error) =>
          error is Map &&
          '${error['message']}'.toLowerCase().contains(refusalText),
    );
  }

  static String? userMutationWebToken(RequestOptions request) {
    if (request.extra[userActionKey] != true) return null;
    if (request.extra[retriedKey] == true) return null;
    if (request.method.toUpperCase() != 'POST') return null;
    if (request.uri.host != 'gql.twitch.tv' || request.uri.path != '/gql') {
      return null;
    }
    final body = request.data;
    if (body is! Map) return null;
    final query = body['query'];
    if (query is! String || !_mutation.hasMatch(query)) return null;
    if (backgroundOperations.contains(body['operationName'])) return null;
    final authorization = _header(request, 'authorization');
    if (authorization == null || !authorization.startsWith('OAuth ')) {
      return null;
    }
    final webToken = authorization.substring('OAuth '.length).trim();
    return webToken.isEmpty ? null : webToken;
  }

  static String? _header(RequestOptions request, String name) {
    for (final entry in request.headers.entries) {
      if (entry.key.toLowerCase() == name) {
        final value = entry.value;
        return value is String ? value : null;
      }
    }
    return null;
  }
}

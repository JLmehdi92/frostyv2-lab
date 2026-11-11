import 'package:dio/dio.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/twitch_tv_session.dart';

class TwitchTvTrace {
  var usedTvSession = false;
  var tvSessionRejected = false;
}

class TwitchTvCredentials {
  const TwitchTvCredentials({
    required this.session,
    required this.clientSessionId,
  });

  final TwitchTvSession session;
  final String clientSessionId;
}

class TwitchTvSessionInterceptor extends Interceptor {
  TwitchTvSessionInterceptor({
    required TwitchTvCredentials? Function() credentials,
    required void Function(String rejectedToken) onRejected,
  }) : _credentials = credentials,
       _onRejected = onRejected;

  final TwitchTvCredentials? Function() _credentials;
  final void Function(String rejectedToken) _onRejected;

  static const userActionKey = 'onsetUserAction';
  static const traceKey = 'onsetTvTrace';
  static const _viaTvKey = 'onsetViaTvSession';

  static const Map<String, Object?> userAction = {userActionKey: true};

  static Map<String, Object?> tracedUserAction(TwitchTvTrace trace) => {
    userActionKey: true,
    traceKey: trace,
  };

  static const backgroundOperations = {'UpdateUserViewedVideo'};

  static const refusalText = 'failed integrity check';

  static const _replacedHeaders = {
    'client-id',
    'authorization',
    'x-device-id',
    'client-session-id',
    'client-integrity',
  };

  static final _mutation = RegExp(r'^\s*mutation\b');

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final credentials = isUserMutation(options) ? _credentials() : null;
    if (credentials != null) {
      options.headers
        ..removeWhere(
          (name, _) => _replacedHeaders.contains(name.toLowerCase()),
        )
        ..addAll(headersFor(credentials));
      options.extra[_viaTvKey] = true;
      _traceOf(options)?.usedTvSession = true;
    }
    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (_sentViaTv(response.requestOptions) && response.statusCode == 401) {
      _reject(response.requestOptions);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (_sentViaTv(err.requestOptions) && err.response?.statusCode == 401) {
      _reject(err.requestOptions);
    }
    handler.next(err);
  }

  void _reject(RequestOptions request) {
    _traceOf(request)?.tvSessionRejected = true;
    final authorization = request.headers['Authorization'];
    if (authorization is String && authorization.startsWith('OAuth ')) {
      _onRejected(authorization.substring('OAuth '.length));
    }
  }

  static Map<String, String> headersFor(TwitchTvCredentials credentials) => {
    'Client-Id': kTwitchTvClientId,
    'Authorization': 'OAuth ${credentials.session.accessToken}',
    'X-Device-Id': credentials.session.deviceId,
    'Client-Session-Id': credentials.clientSessionId,
  };

  static bool _sentViaTv(RequestOptions request) =>
      request.extra[_viaTvKey] == true;

  static TwitchTvTrace? _traceOf(RequestOptions request) {
    final trace = request.extra[traceKey];
    return trace is TwitchTvTrace ? trace : null;
  }

  static bool isUserMutation(RequestOptions request) {
    if (request.extra[userActionKey] != true && !_signedIn(request)) {
      return false;
    }
    if (request.method.toUpperCase() != 'POST') return false;
    final uri = request.uri;
    if (uri.scheme != 'https' ||
        uri.host != 'gql.twitch.tv' ||
        uri.path != '/gql') {
      return false;
    }
    final body = request.data;
    if (body is! Map) return false;
    final query = body['query'];
    if (query is! String || !_mutation.hasMatch(query)) return false;
    return !backgroundOperations.contains(body['operationName']);
  }

  static bool _signedIn(RequestOptions request) => request.headers.entries.any(
    (header) =>
        header.key.toLowerCase() == 'authorization' &&
        header.value is String &&
        (header.value as String).startsWith('OAuth '),
  );

  static bool isIntegrityRefusal(Object? body) =>
      _errorMessages(body).any((message) => message.contains(refusalText));

  static Iterable<String> _errorMessages(Object? body) {
    if (body is! Map) return const [];
    final errors = body['errors'];
    if (errors is! List) return const [];
    return [
      for (final error in errors)
        if (error is Map) '${error['message']}'.toLowerCase(),
    ];
  }
}

import 'package:dio/dio.dart';
import 'package:onset/services/telemetry.dart';

/// Common type aliases to reduce repetition
typedef JsonMap = Map<String, dynamic>;
typedef JsonList = List<dynamic>;
typedef QueryParams = Map<String, dynamic>;
typedef ApiHeaders = Map<String, String>;

/// The crash report reason of a failed [request]: its method and service
/// only. Its path can name a channel or carry a user id, its query can name
/// anyone (whisper partners, chatters).
String crashReasonFor(RequestOptions request) =>
    '${request.method} ${request.uri.origin}';

/// What went wrong with a request, for a screen to say in its language
/// (lib/l10n/api_errors.dart words each one): [ApiException.message] is
/// English, for logs only.
enum ApiErrorKind {
  /// No connection.
  network,

  /// Connecting took too long.
  connectionTimeout,

  /// Sending took too long.
  sendTimeout,

  /// The answer took too long.
  receiveTimeout,

  /// The request was cancelled.
  cancelled,

  /// The server's certificate was refused.
  certificate,

  /// Anything else (and errors the app raises itself).
  unknown,

  /// 400.
  badRequest,

  /// 401.
  unauthorized,

  /// 403.
  forbidden,

  /// 404.
  notFound,

  /// 409.
  conflict,

  /// 422.
  invalid,

  /// 429.
  rateLimited,

  /// 500.
  server,

  /// 502.
  unavailable,

  /// 503.
  maintenance,

  /// 504.
  serverTimeout,

  /// Any other HTTP status ([ApiException.statusCode]).
  http,
}

/// Custom API exceptions for better error handling
class ApiException implements Exception {
  /// What went wrong, in English: for logs and crash reports, never shown
  /// (a screen words [kind]).
  final String message;
  final int? statusCode;
  final DioExceptionType? type;

  /// What went wrong, for a screen to say.
  final ApiErrorKind kind;

  /// The server's own explanation from its answer's body (Twitch's words,
  /// shown as they are), when it gave one.
  final String? twitchMessage;

  const ApiException(
    this.message, [
    this.statusCode,
    this.type,
    this.kind = ApiErrorKind.unknown,
    this.twitchMessage,
  ]);

  @override
  String toString() => 'ApiException: $message';
}

class NetworkException extends ApiException {
  const NetworkException(String message)
    : super(
        message,
        null,
        DioExceptionType.connectionError,
        ApiErrorKind.network,
      );
}

class TimeoutException extends ApiException {
  const TimeoutException(
    String message, [
    ApiErrorKind kind = ApiErrorKind.connectionTimeout,
  ]) : super(message, null, DioExceptionType.connectionTimeout, kind);
}

class ServerException extends ApiException {
  const ServerException(
    String message,
    int statusCode, [
    ApiErrorKind kind = ApiErrorKind.server,
    String? twitchMessage,
  ]) : super(
         message,
         statusCode,
         DioExceptionType.badResponse,
         kind,
         twitchMessage,
       );
}

class NotFoundException extends ApiException {
  const NotFoundException(String message, [String? twitchMessage])
    : super(
        message,
        404,
        DioExceptionType.badResponse,
        ApiErrorKind.notFound,
        twitchMessage,
      );
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(String message)
    : super(
        message,
        401,
        DioExceptionType.badResponse,
        ApiErrorKind.unauthorized,
      );
}

/// Base API client to eliminate code duplication across API services
abstract class BaseApiClient {
  final Dio _dio;
  final String baseUrl;

  const BaseApiClient(this._dio, this.baseUrl);

  /// Builds the full URL, handling both relative endpoints and full URLs
  String _buildUrl(String endpoint) {
    // If endpoint is already a full URL (starts with http:// or https://), use it as-is
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      return endpoint;
    }
    // Otherwise, concatenate with base URL
    return '$baseUrl$endpoint';
  }

  /// Generic GET request with common error handling
  ///
  /// [extra] reaches the interceptors (see `UnauthorizedInterceptor.quiet`).
  ///
  /// [followRedirects] false: a redirect fails instead of being followed.
  Future<T> get<T>(
    String endpoint, {
    QueryParams? queryParameters,
    ApiHeaders? headers,
    CancelToken? cancelToken,
    Map<String, Object?>? extra,
    bool? followRedirects,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await _dio.get(
        url,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          extra: extra,
          followRedirects: followRedirects,
        ),
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Generic POST request with common error handling
  ///
  /// [followRedirects] overrides the client's choice (null keeps it).
  Future<T> post<T>(
    String endpoint, {
    dynamic data,
    QueryParams? queryParameters,
    ApiHeaders? headers,
    CancelToken? cancelToken,
    Map<String, Object?>? extra,
    bool? followRedirects,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await _dio.post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(
          headers: headers,
          extra: extra,
          followRedirects: followRedirects,
        ),
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Generic PUT request with common error handling
  Future<T> put<T>(
    String endpoint, {
    dynamic data,
    QueryParams? queryParameters,
    ApiHeaders? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await _dio.put(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Generic PATCH request with common error handling
  Future<T> patch<T>(
    String endpoint, {
    dynamic data,
    QueryParams? queryParameters,
    ApiHeaders? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await _dio.patch(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(headers: headers),
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Generic DELETE request with common error handling
  Future<T> delete<T>(
    String endpoint, {
    QueryParams? queryParameters,
    ApiHeaders? headers,
    CancelToken? cancelToken,
    Map<String, Object?>? extra,
  }) async {
    try {
      final url = _buildUrl(endpoint);
      final response = await _dio.delete(
        url,
        queryParameters: queryParameters,
        options: Options(headers: headers, extra: extra),
        cancelToken: cancelToken,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Check if response indicates success (useful for status-only operations)
  bool isSuccessResponse(Response response) {
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  /// Converts DioException to appropriate ApiException subtype
  ApiException _handleError(DioException error) {
    final exception = switch (error.type) {
      DioExceptionType.connectionTimeout => TimeoutException(
        _getTimeoutMessage(error.type),
      ),
      DioExceptionType.sendTimeout => TimeoutException(
        _getTimeoutMessage(error.type),
        ApiErrorKind.sendTimeout,
      ),
      DioExceptionType.receiveTimeout => TimeoutException(
        _getTimeoutMessage(error.type),
        ApiErrorKind.receiveTimeout,
      ),
      DioExceptionType.connectionError => NetworkException(
        'No internet connection. Please check your network.',
      ),
      DioExceptionType.badResponse => _handleHttpError(error),
      DioExceptionType.cancel => ApiException(
        'Request was cancelled',
        null,
        null,
        ApiErrorKind.cancelled,
      ),
      DioExceptionType.badCertificate => ApiException(
        'Security certificate error',
        null,
        null,
        ApiErrorKind.certificate,
      ),
      DioExceptionType.unknown => ApiException(
        error.message ?? 'An unexpected error occurred',
      ),
    };

    // Record server errors and unexpected failures to Crashlytics.
    // Skip timeouts, network errors (normal offline conditions), 401s, and cancellations.
    if (exception is ServerException ||
        error.type == DioExceptionType.unknown ||
        error.type == DioExceptionType.badCertificate) {
      Telemetry.recordError(
        exception,
        error.stackTrace,
        reason: crashReasonFor(error.requestOptions),
      );
    }

    return exception;
  }

  /// Gets specific timeout message based on timeout type
  String _getTimeoutMessage(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timeout. Please try again.';
      case DioExceptionType.sendTimeout:
        return 'Upload timeout. Please try again.';
      case DioExceptionType.receiveTimeout:
        return 'Server response timeout. Please try again.';
      default:
        return 'Request timeout. Please try again.';
    }
  }

  /// Handles HTTP status code errors with specific exception types
  ApiException _handleHttpError(DioException error) {
    final statusCode = error.response?.statusCode;
    final responseData = error.response?.data;

    // Extract error message from server response
    String? serverMessage;
    if (responseData is JsonMap) {
      serverMessage =
          responseData['message'] as String? ??
          responseData['error'] as String? ??
          responseData['error_description'] as String?;
    }

    switch (statusCode) {
      case 400:
        return ApiException(
          serverMessage ?? 'Invalid request data',
          400,
          DioExceptionType.badResponse,
          ApiErrorKind.badRequest,
          serverMessage,
        );
      case 401:
        return UnauthorizedException('Please log in to continue');
      case 403:
        return ApiException(
          serverMessage ?? 'Access denied. Insufficient permissions',
          403,
          DioExceptionType.badResponse,
          ApiErrorKind.forbidden,
          serverMessage,
        );
      case 404:
        return NotFoundException(
          serverMessage ?? 'Resource not found',
          serverMessage,
        );
      case 409:
        return ApiException(
          serverMessage ?? 'Conflict with current state. Please refresh',
          409,
          DioExceptionType.badResponse,
          ApiErrorKind.conflict,
          serverMessage,
        );
      case 422:
        return ApiException(
          serverMessage ?? 'Invalid data provided',
          422,
          DioExceptionType.badResponse,
          ApiErrorKind.invalid,
          serverMessage,
        );
      case 429:
        return ApiException(
          serverMessage ??
              'Rate limit exceeded. Please wait before trying again',
          429,
          DioExceptionType.badResponse,
          ApiErrorKind.rateLimited,
          serverMessage,
        );
      case 500:
        return ServerException('Server error. Please try again later', 500);
      case 502:
        return ServerException(
          'Service temporarily unavailable',
          502,
          ApiErrorKind.unavailable,
        );
      case 503:
        return ServerException(
          'Service maintenance. Please try again later',
          503,
          ApiErrorKind.maintenance,
        );
      case 504:
        return ServerException(
          'Server timeout. Please try again',
          504,
          ApiErrorKind.serverTimeout,
        );
      default:
        return ServerException(
          serverMessage ?? 'HTTP Error $statusCode occurred',
          statusCode ?? 500,
          ApiErrorKind.http,
          serverMessage,
        );
    }
  }
}

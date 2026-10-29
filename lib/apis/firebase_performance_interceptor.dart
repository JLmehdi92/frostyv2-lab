import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:onset/services/telemetry.dart';

/// Dio interceptor that traces HTTP requests as Firebase Performance metrics
/// (nothing at all when the build has no Firebase, see [Telemetry]).
class FirebasePerformanceInterceptor extends Interceptor {
  static const _metricKey = 'firebase_performance_metric';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final metric = Telemetry.newHttpMetric(
      // No query: it can name people (whisper partners, chatters).
      '${options.uri.origin}${options.uri.path}',
      options.method,
    );
    if (metric != null) {
      metric.start().catchError((Object _) {});
      options.extra[_metricKey] = metric;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _stopMetric(response.requestOptions, response.statusCode);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _stopMetric(err.requestOptions, err.response?.statusCode);
    handler.next(err);
  }

  void _stopMetric(RequestOptions options, int? statusCode) {
    final metric = options.extra.remove(_metricKey) as HttpMetric?;
    if (metric == null) return;
    if (statusCode != null) metric.httpResponseCode = statusCode;
    metric.stop().catchError((Object _) {});
  }
}

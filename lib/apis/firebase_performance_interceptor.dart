import 'package:dio/dio.dart';
import 'package:firebase_performance/firebase_performance.dart';

/// Dio interceptor that traces HTTP requests as Firebase Performance metrics.
class FirebasePerformanceInterceptor extends Interceptor {
  static const _metricKey = 'firebase_performance_metric';

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final metric = FirebasePerformance.instance.newHttpMetric(
      options.uri.toString(),
      _getHttpMethod(options.method),
    );
    metric.start();
    options.extra[_metricKey] = metric;
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
    metric.stop();
  }

  static HttpMethod _getHttpMethod(String method) => switch (method.toUpperCase()) {
    'GET' => HttpMethod.Get,
    'POST' => HttpMethod.Post,
    'PUT' => HttpMethod.Put,
    'DELETE' => HttpMethod.Delete,
    'PATCH' => HttpMethod.Patch,
    _ => HttpMethod.Get,
  };
}

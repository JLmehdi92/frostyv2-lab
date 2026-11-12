import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:onset/apis/base_api_client.dart';
import 'package:onset/apis/twitch_tv_session_interceptor.dart';
import 'package:onset/apis/twitch_viewer_actions_service.dart';
import 'package:onset/constants.dart';
import 'package:onset/models/report.dart';

class TwitchReportService extends BaseApiClient {
  TwitchReportService(Dio dio) : super(dio, '');

  static const maxDescriptionLength = 500;
  static final _numericId = RegExp(r'^[0-9]{1,20}$');
  static final _opaqueId = RegExp(r'^[A-Za-z0-9_:\-]{1,128}$');

  static const _reportDocument =
      'mutation ReportContent(\$input: ReportContentInput!) { '
      'reportContent(input: \$input) { content contentID } }';

  static bool isReportable(ReportTarget target) =>
      _numericId.hasMatch(target.targetUserId) &&
      _opaqueId.hasMatch(target.contentId) &&
      (target.extra.isEmpty || _numericId.hasMatch(target.extra));

  Future<ViewerActionOutcome> report({
    required ReportTarget target,
    required ReportReason reason,
    required String description,
    required String authToken,
  }) async {
    if (authToken.isEmpty) return ViewerActionOutcome.signedOut;
    final text = description.trim();
    if (!isReportable(target) ||
        !target.reasons.contains(reason) ||
        text.length > maxDescriptionLength) {
      return ViewerActionOutcome.failed;
    }
    try {
      final Object? body = await post<dynamic>(
        kTwitchGqlUrl,
        extra: TwitchTvSessionInterceptor.userAction,
        headers: {
          'Client-ID': kTwitchWebClientId,
          'Authorization': 'OAuth $authToken',
        },
        data: {
          'operationName': 'ReportContent',
          'query': _reportDocument,
          'variables': {
            'input': {
              'content': target.contentType,
              'contentID': target.contentId,
              'targetID': target.targetUserId,
              'reason': reason.id,
              'description': text,
              'extra': target.extra,
            },
          },
        },
      );
      return _outcomeOf(body, target);
    } on UnauthorizedException {
      return ViewerActionOutcome.signedOut;
    } catch (e) {
      if (kDebugMode) debugPrint('ReportContent failed: $e');
      return ViewerActionOutcome.failed;
    }
  }

  static ViewerActionOutcome _outcomeOf(Object? body, ReportTarget target) {
    if (body is! Map) return ViewerActionOutcome.failed;
    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      return TwitchTvSessionInterceptor.isIntegrityRefusal(body)
          ? ViewerActionOutcome.integrityRefused
          : ViewerActionOutcome.refused;
    }
    final data = body['data'];
    final payload = data is Map ? data['reportContent'] : null;
    if (payload is! Map) return ViewerActionOutcome.failed;
    return payload['contentID'] == target.contentId
        ? ViewerActionOutcome.done
        : ViewerActionOutcome.failed;
  }
}

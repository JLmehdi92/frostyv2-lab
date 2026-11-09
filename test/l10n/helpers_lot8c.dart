import 'package:onset/models/recommended_channel.dart';

import '../fixtures/social_payloads.dart';

List<RecommendedChannel> lot8cChannels() {
  final data = personalSectionsResponse()['data']! as Map;
  final items = (data['personalSections'] as List).first['items'] as List;
  return [for (final item in items) RecommendedChannel.fromItem(item)!];
}

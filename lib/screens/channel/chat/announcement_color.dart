import 'package:flutter/painting.dart';

/// The accent of an announcement's `msg-param-color` (Twitch's blue,
/// green, orange and purple); null for PRIMARY or anything else, which
/// keeps the channel's default notice colour.
Color? announcementColor(String? param) => switch (param?.toUpperCase()) {
  'BLUE' => const Color(0xFF00D6D6),
  'GREEN' => const Color(0xFF00DB84),
  'ORANGE' => const Color(0xFFFFB31A),
  'PURPLE' => const Color(0xFF9146FF),
  _ => null,
};

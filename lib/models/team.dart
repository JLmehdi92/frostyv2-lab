import 'package:flutter/foundation.dart';

final _numericId = RegExp(r'^[0-9]{1,20}$');
final _login = RegExp(r'^[a-zA-Z0-9_]{1,25}$');
final _teamName = RegExp(r'^[a-zA-Z0-9_-]{1,64}$');

String? _string(Object? value, {int max = 300}) {
  if (value is! String) return null;
  final text = value.trim();
  if (text.isEmpty) return null;
  return text.length > max ? text.substring(0, max) : text;
}

String? _https(Object? value) {
  final text = _string(value, max: 500);
  final uri = text == null ? null : Uri.tryParse(text);
  return uri != null && uri.scheme == 'https' ? text : null;
}

@immutable
class TeamMember {
  const TeamMember({
    required this.id,
    required this.login,
    required this.displayName,
  });

  final String id;
  final String login;
  final String displayName;

  static TeamMember? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['user_id'];
    final login = json['user_login'];
    if (id is! String ||
        !_numericId.hasMatch(id) ||
        login is! String ||
        !_login.hasMatch(login)) {
      return null;
    }
    return TeamMember(
      id: id,
      login: login.toLowerCase(),
      displayName: _string(json['user_name'], max: 64) ?? login,
    );
  }
}

@immutable
class Team {
  const Team({
    required this.id,
    required this.name,
    required this.displayName,
    this.info = '',
    this.thumbnailUrl,
    this.bannerUrl,
    this.members = const [],
  });

  final String id;
  final String name;
  final String displayName;
  final String info;
  final String? thumbnailUrl;
  final String? bannerUrl;
  final List<TeamMember> members;

  static const maxMembers = 500;

  static final _tags = RegExp(r'<[^>]*>');

  static Team? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['team_name'];
    if (id is! String ||
        !_numericId.hasMatch(id) ||
        name is! String ||
        !_teamName.hasMatch(name)) {
      return null;
    }
    final users = json['users'];
    return Team(
      id: id,
      name: name.toLowerCase(),
      displayName: _string(json['team_display_name'], max: 100) ?? name,
      info: (_string(json['info'], max: 2000) ?? '')
          .replaceAll(_tags, ' ')
          .replaceAll('&nbsp;', ' ')
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&quot;', '"')
          .replaceAll('&#39;', "'")
          .replaceAll('&amp;', '&')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim(),
      thumbnailUrl: _https(json['thumbnail_url']),
      bannerUrl: _https(json['banner']),
      members: [
        if (users is List)
          for (final user in users.take(maxMembers)) ?TeamMember.fromJson(user),
      ],
    );
  }
}

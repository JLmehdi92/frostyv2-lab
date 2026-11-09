enum AccountEditOutcome { done, refused, integrityRefused, signedOut, failed }

class AccountEditResult<T> {
  const AccountEditResult(this.outcome, {this.code, this.value});

  const AccountEditResult.failed() : this(AccountEditOutcome.failed);

  const AccountEditResult.signedOut() : this(AccountEditOutcome.signedOut);

  final AccountEditOutcome outcome;
  final String? code;
  final T? value;

  bool get succeeded => outcome == AccountEditOutcome.done;
}

class EditableProfile {
  const EditableProfile({
    required this.id,
    required this.login,
    required this.displayName,
    required this.description,
    this.profileImageUrl,
    this.bannerImageUrl,
  });

  static EditableProfile? tryParse(Object? user) {
    if (user is! Map) return null;
    final id = user['id'];
    final login = user['login'];
    if (id is! String || id.isEmpty || login is! String || login.isEmpty) {
      return null;
    }
    final displayName = user['displayName'];
    final description = user['description'];
    final image = user['profileImageURL'];
    final banner = user['bannerImageURL'];
    return EditableProfile(
      id: id,
      login: login,
      displayName: displayName is String && displayName.isNotEmpty
          ? displayName
          : login,
      description: description is String ? description : '',
      profileImageUrl: image is String && image.startsWith('https://')
          ? image
          : null,
      bannerImageUrl: banner is String && banner.startsWith('https://')
          ? banner
          : null,
    );
  }

  final String id;
  final String login;
  final String displayName;
  final String description;
  final String? profileImageUrl;
  final String? bannerImageUrl;

  static const maxDescriptionLength = 300;
  static const maxSocialLinks = 5;
}

class LoginRenameStatus {
  const LoginRenameStatus({required this.eligible, this.eligibleAt});

  static LoginRenameStatus? tryParse(Object? data) {
    final user = data is Map ? data['currentUser'] : null;
    final status = user is Map ? user['loginRenameStatus'] : null;
    if (status is! Map || status['isEligible'] is! bool) return null;
    return LoginRenameStatus(
      eligible: status['isEligible'] == true,
      eligibleAt: DateTime.tryParse('${status['eligibleAt']}'),
    );
  }

  final bool eligible;
  final DateTime? eligibleAt;
}

enum UsernameAvailability { available, taken, unknown }

class SocialLink {
  const SocialLink({required this.id, required this.title, required this.url});

  static List<SocialLink>? listFrom(Object? channel) {
    if (channel is! Map || channel['socialMedias'] is! List) return null;
    return [
      for (final item in channel['socialMedias'] as List)
        if (item is Map &&
            item['id'] is String &&
            item['url'] is String &&
            isValidUrl(item['url'] as String))
          SocialLink(
            id: item['id'] as String,
            title:
                item['title'] is String && (item['title'] as String).isNotEmpty
                ? item['title'] as String
                : Uri.parse(item['url'] as String).host,
            url: item['url'] as String,
          ),
    ];
  }

  static bool isValidUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    return uri != null &&
        (uri.scheme == 'https' || uri.scheme == 'http') &&
        uri.host.contains('.') &&
        uri.userInfo.isEmpty;
  }

  static const maxTitleLength = 25;

  final String id;
  final String title;
  final String url;
}

/// An ONSET build published as a GitHub release by the update workflow.
///
/// Its tag is `build-<N>`, where N is the Android build number of the APK it
/// carries, and it holds two assets: the arm64 APK and its SHA-256.
class OnsetRelease {
  /// The APK asset the workflow publishes.
  static const apkAssetName = 'onset-arm64.apk';

  /// The asset holding the APK's SHA-256, in hex.
  static const shaAssetName = 'onset-arm64.apk.sha256';

  /// At most nine digits, so the number always fits an Android versionCode.
  static final _tagPattern = RegExp(r'^build-([1-9]\d{0,8})$');

  final int build;
  final String tag;
  final String notes;
  final int apkAssetId;
  final int shaAssetId;
  final int apkSize;

  const OnsetRelease({
    required this.build,
    required this.tag,
    required this.notes,
    required this.apkAssetId,
    required this.shaAssetId,
    required this.apkSize,
  });

  /// Reads a release from the GitHub API, or null when it is not a complete
  /// ONSET build: another tag, or a missing APK or hash (an update that cannot
  /// be verified is never offered).
  static OnsetRelease? tryParse(Object? json) {
    if (json is! Map) return null;
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final match = _tagPattern.firstMatch(tag);
    if (match == null) return null;
    final assets = json['assets'];
    if (assets is! List) return null;

    Map? asset(String name) {
      for (final asset in assets) {
        if (asset is Map && asset['name'] == name) return asset;
      }
      return null;
    }

    int? positive(Object? value) => value is int && value > 0 ? value : null;

    final apk = asset(apkAssetName);
    final sha = asset(shaAssetName);
    if (apk == null || sha == null) return null;
    final apkId = positive(apk['id']);
    final shaId = positive(sha['id']);
    final size = apk['size'];
    if (apkId == null || shaId == null || size is! int || size < 0) {
      return null;
    }
    final body = json['body'];

    return OnsetRelease(
      build: int.parse(match.group(1)!),
      tag: tag,
      notes: body is String ? body : '',
      apkAssetId: apkId,
      shaAssetId: shaId,
      apkSize: size,
    );
  }
}

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import '../../../domain/use_cases/app_version.dart';
import '../../../domain/models/update_check_result.dart';

/// Checks a GitHub repo's latest release against the running app version.
/// Windows looks for a `-win-x64.zip` asset, Linux for a `-linux-x64.deb`
/// asset; if neither is attached to the release, falls back to linking
/// the release page itself. Functional spec section 8 — Linux
/// deliberately never auto-downloads/installs, only surfaces a link.
class UpdateService {
  UpdateService({required this.repoOwner, required this.repoName, http.Client? client})
    : _client = client ?? http.Client();

  final String repoOwner;
  final String repoName;
  final http.Client _client;

  Uri get _latestReleaseApiUri => Uri.https('api.github.com', '/repos/$repoOwner/$repoName/releases/latest');

  String get releasePageUrl => 'https://github.com/$repoOwner/$repoName/releases/latest';

  Future<UpdateCheckResult> checkForUpdate(Version currentVersion) async {
    final response = await _client.get(
      _latestReleaseApiUri,
      headers: const {'User-Agent': 'ScreenTime-UpdateChecker'},
    );
    if (response.statusCode != 200) {
      throw HttpException('GitHub release check failed with status ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tagName = json['tag_name'] as String;
    final latestVersion = parseReleaseTag(tagName);
    if (latestVersion == null) {
      throw FormatException('Could not parse a version from release tag "$tagName".');
    }

    final releasePage = json['html_url'] as String? ?? releasePageUrl;
    final downloadUrl = _findAssetDownloadUrl(json) ?? releasePage;

    return UpdateCheckResult(
      currentVersion: currentVersion,
      latest: ReleaseInfo(version: latestVersion, tagName: tagName, releasePageUrl: releasePage, downloadUrl: downloadUrl),
      hasUpdate: latestVersion > currentVersion,
    );
  }

  /// Retries [checkForUpdate] with the given backoff delays (functional
  /// spec: "失敗時可重試數次"), returning the first successful result or
  /// null if every attempt fails.
  Future<UpdateCheckResult?> checkWithRetry(
    Version currentVersion, {
    List<Duration> retryDelays = const [Duration(seconds: 5), Duration(seconds: 15)],
  }) async {
    for (var attempt = 0; ; attempt++) {
      try {
        return await checkForUpdate(currentVersion);
      } on Object {
        if (attempt >= retryDelays.length) return null;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  String? _findAssetDownloadUrl(Map<String, dynamic> release) {
    final suffix = Platform.isWindows ? '-win-x64.zip' : '-linux-x64.deb';
    final assets = (release['assets'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
    for (final asset in assets) {
      final name = (asset['name'] as String?)?.toLowerCase() ?? '';
      if (name.endsWith(suffix)) return asset['browser_download_url'] as String?;
    }
    return null;
  }

  void dispose() => _client.close();
}

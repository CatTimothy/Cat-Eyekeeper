import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:cat_eyekeeper/data/services/app/update_service.dart';

http.Response _releaseResponse({
  required String tag,
  List<Map<String, String>> assets = const [],
  String htmlUrl = 'https://github.com/owner/repo/releases/tag/v1.0.0',
}) {
  return http.Response(
    jsonEncode({
      'tag_name': tag,
      'html_url': htmlUrl,
      'assets': assets.map((a) => {'name': a['name'], 'browser_download_url': a['url']}).toList(),
    }),
    200,
  );
}

void main() {
  test('reports hasUpdate=true when the release tag is newer', () async {
    final client = MockClient((request) async => _releaseResponse(tag: 'v2.0.0'));
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    final result = await service.checkForUpdate(Version(1, 0, 0));

    expect(result.hasUpdate, isTrue);
    expect(result.latest.version, Version(2, 0, 0));
  });

  test('reports hasUpdate=false when already on the latest version', () async {
    final client = MockClient((request) async => _releaseResponse(tag: 'v1.0.0'));
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    final result = await service.checkForUpdate(Version(1, 0, 0));

    expect(result.hasUpdate, isFalse);
  });

  test('picks the Windows asset by suffix on Windows', () async {
    final client = MockClient(
      (request) async => _releaseResponse(
        tag: 'v2.0.0',
        assets: [
          {'name': 'ScreenTime-v2.0.0-win-x64.zip', 'url': 'https://example.com/win.zip'},
          {'name': 'ScreenTime-v2.0.0-linux-x64.deb', 'url': 'https://example.com/linux.deb'},
        ],
      ),
    );
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    final result = await service.checkForUpdate(Version(1, 0, 0));

    expect(result.latest.downloadUrl, Platform.isWindows ? 'https://example.com/win.zip' : 'https://example.com/linux.deb');
  });

  test('falls back to the release page when no matching asset is attached', () async {
    final client = MockClient(
      (request) async => _releaseResponse(tag: 'v2.0.0', htmlUrl: 'https://github.com/owner/repo/releases/tag/v2.0.0'),
    );
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    final result = await service.checkForUpdate(Version(1, 0, 0));

    expect(result.latest.downloadUrl, 'https://github.com/owner/repo/releases/tag/v2.0.0');
  });

  test('throws on a non-200 response', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    expect(() => service.checkForUpdate(Version(1, 0, 0)), throwsException);
  });

  test('checkWithRetry retries on failure and eventually returns null', () async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      return http.Response('', 500);
    });
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    final result = await service.checkWithRetry(
      Version(1, 0, 0),
      retryDelays: const [Duration(milliseconds: 1), Duration(milliseconds: 1)],
    );

    expect(result, isNull);
    expect(attempts, 3); // initial attempt + 2 retries
  });

  test('checkWithRetry succeeds once a retry gets a good response', () async {
    var attempts = 0;
    final client = MockClient((request) async {
      attempts++;
      if (attempts < 2) return http.Response('', 500);
      return _releaseResponse(tag: 'v2.0.0');
    });
    final service = UpdateService(repoOwner: 'owner', repoName: 'repo', client: client);

    final result = await service.checkWithRetry(
      Version(1, 0, 0),
      retryDelays: const [Duration(milliseconds: 1), Duration(milliseconds: 1)],
    );

    expect(result, isNotNull);
    expect(result!.hasUpdate, isTrue);
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:pub_semver/pub_semver.dart';
import 'package:cat_eyekeeper/domain/use_cases/app_version.dart';

void main() {
  test('parses a plain semantic version', () {
    expect(parseReleaseTag('1.2.3'), Version(1, 2, 3));
  });

  test('strips a leading v/V prefix', () {
    expect(parseReleaseTag('v1.2.3'), Version(1, 2, 3));
    expect(parseReleaseTag('V1.2.3'), Version(1, 2, 3));
  });

  test('handles pre-release and build metadata per semver ordering', () {
    final prerelease = parseReleaseTag('v1.2.3-beta.1');
    final release = parseReleaseTag('v1.2.3');
    expect(prerelease, isNotNull);
    expect(release, isNotNull);
    expect(prerelease! < release!, isTrue); // pre-releases sort before the release
  });

  test('returns null for garbage input', () {
    expect(parseReleaseTag('not-a-version'), isNull);
  });
}

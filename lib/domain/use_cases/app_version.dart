import 'package:pub_semver/pub_semver.dart';

/// Parses a release tag like `v1.2.3` or `1.2.3-beta.1` into a [Version],
/// or null if it doesn't look like a semantic version.
Version? parseReleaseTag(String tag) {
  final normalized = tag.trim().replaceFirst(RegExp('^[vV]'), '');
  try {
    return Version.parse(normalized);
  } on FormatException {
    return null;
  }
}

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:pub_semver/pub_semver.dart';

part 'update_check_result.freezed.dart';

/// A GitHub release, resolved to the platform-appropriate download asset
/// (or the release page if no matching asset was found).
@freezed
abstract class ReleaseInfo with _$ReleaseInfo {
  const factory ReleaseInfo({
    required Version version,
    required String tagName,
    required String releasePageUrl,
    required String downloadUrl,
  }) = _ReleaseInfo;
}

/// Outcome of an update check (functional spec section 8).
@freezed
abstract class UpdateCheckResult with _$UpdateCheckResult {
  const factory UpdateCheckResult({required Version currentVersion, required ReleaseInfo latest, required bool hasUpdate}) =
      _UpdateCheckResult;
}

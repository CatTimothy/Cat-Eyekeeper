import 'dart:convert';
import 'dart:io';

import '../../domain/models/settings.dart';
import 'app_paths.dart';
import 'atomic_writer.dart';
import 'json_codec.dart';

/// Loads/saves the single [Settings] file. A missing file gets defaults
/// written to it; a corrupt file is backed up to `settings.json.corrupt`
/// before falling back to defaults, so a bad write never wedges the app.
class SettingsRepository {
  SettingsRepository({required this.paths, AtomicWriter? writer}) : _writer = writer ?? const AtomicWriter();

  final AppPaths paths;
  final AtomicWriter _writer;

  Future<Settings> load() async {
    await paths.ensureCreated();
    final file = File(paths.settingsFile);
    if (!await file.exists()) {
      final defaults = Settings.defaults();
      await save(defaults);
      return defaults;
    }
    try {
      final raw = await file.readAsString();
      return Settings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } on FormatException {
      // Invalid JSON syntax.
      return _resetToDefaults(file);
    } on TypeError {
      // Valid JSON but the wrong shape (missing/mistyped fields) — e.g. a
      // settings file from an unrelated/older app that happens to share
      // this directory name.
      return _resetToDefaults(file);
    }
  }

  Future<Settings> _resetToDefaults(File file) async {
    await backupCorruptFile(file);
    final defaults = Settings.defaults();
    await save(defaults);
    return defaults;
  }

  Future<void> save(Settings settings) async {
    await paths.ensureCreated();
    await _writer.writeString(paths.settingsFile, encodePretty(settings.toJson()));
  }
}

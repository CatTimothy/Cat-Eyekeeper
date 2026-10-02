import 'dart:convert';
import 'dart:io';

/// Shared pretty-printing so every file this app writes is human-diffable.
const JsonEncoder prettyJsonEncoder = JsonEncoder.withIndent('  ');

String encodePretty(Object? value) => prettyJsonEncoder.convert(value);

/// Preserves a corrupt/unreadable file as `<path>.corrupt` before a
/// repository resets it to defaults, so the bad data isn't silently lost.
Future<void> backupCorruptFile(File file) => file.copy('${file.path}.corrupt');

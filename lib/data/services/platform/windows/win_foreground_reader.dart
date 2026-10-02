import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:win32/win32.dart';

import '../../../../domain/models/foreground_app.dart';
import '../foreground_reader.dart';
import '../fullscreen_checker.dart';
import 'win_fullscreen_checker.dart';

/// Reads an executable's `FileDescription` version resource — the same
/// friendly name (e.g. "Visual Studio Code") Task Manager shows — or null
/// if the file has no version info (or isn't readable at all). Top-level
/// and independently testable against real system executables, since it
/// touches no window/process state.
String? readFileDescription(String executablePath) {
  final pathPtr = executablePath.toNativeUtf16();
  final handlePtr = calloc<Uint32>();
  try {
    final size = GetFileVersionInfoSize(pathPtr, handlePtr);
    if (size == 0) return null;

    final infoBuffer = calloc<Uint8>(size);
    try {
      final ok = GetFileVersionInfo(pathPtr, 0, size, infoBuffer.cast());
      if (ok == 0) return null;
      return _readFileDescriptionFromBlock(infoBuffer.cast());
    } finally {
      calloc.free(infoBuffer);
    }
  } on Object {
    return null;
  } finally {
    calloc.free(pathPtr);
    calloc.free(handlePtr);
  }
}

/// The translation table tells us which language/codepage the string
/// resources are stored under; we read the first entry and look up
/// FileDescription under it — the standard technique for this API.
String? _readFileDescriptionFromBlock(Pointer infoBlock) {
  final translationPtr = calloc<Pointer>();
  final translationLenPtr = calloc<Uint32>();
  try {
    final translationKeyPtr = r'\VarFileInfo\Translation'.toNativeUtf16();
    try {
      final found = VerQueryValue(infoBlock, translationKeyPtr, translationPtr, translationLenPtr);
      if (found == 0 || translationLenPtr.value < 4) return null;
    } finally {
      calloc.free(translationKeyPtr);
    }

    final translation = translationPtr.value.cast<Uint16>();
    final language = translation[0].toRadixString(16).padLeft(4, '0');
    final codepage = translation[1].toRadixString(16).padLeft(4, '0');

    final descriptionKeyPtr = '\\StringFileInfo\\$language$codepage\\FileDescription'.toNativeUtf16();
    final valuePtr = calloc<Pointer>();
    final valueLenPtr = calloc<Uint32>();
    try {
      final found = VerQueryValue(infoBlock, descriptionKeyPtr, valuePtr, valueLenPtr);
      if (found == 0 || valueLenPtr.value == 0) return null;
      final description = valuePtr.value.cast<Utf16>().toDartString().trim();
      return description.isEmpty ? null : description;
    } finally {
      calloc.free(descriptionKeyPtr);
      calloc.free(valuePtr);
      calloc.free(valueLenPtr);
    }
  } finally {
    calloc.free(translationPtr);
    calloc.free(translationLenPtr);
  }
}

/// Reads the focused window via `GetForegroundWindow` and resolves its
/// owning process's executable path and title.
class WinForegroundReader implements ForegroundReader {
  WinForegroundReader({FullscreenChecker? fullscreenChecker})
    : _fullscreenChecker = fullscreenChecker ?? WinFullscreenChecker();

  final FullscreenChecker _fullscreenChecker;

  // Reading FileDescription from an exe's version resource touches disk;
  // cache per executable path since the foreground app rarely changes
  // tick-to-tick and a given exe's friendly name never changes.
  final Map<String, String> _friendlyNameCache = {};

  @override
  ForegroundApp? current() {
    final hwnd = GetForegroundWindow();
    if (hwnd == 0) return null;

    final pid = _queryProcessId(hwnd);
    if (pid == 0) return null;

    final executablePath = _queryExecutablePath(pid);
    final processName = executablePath.isNotEmpty ? p.basenameWithoutExtension(executablePath) : 'unknown';
    final windowTitle = _queryWindowTitle(hwnd);
    final name = _friendlyName(executablePath, processName);

    return ForegroundApp(
      processId: pid,
      name: name,
      processName: processName,
      executablePath: executablePath,
      windowTitle: windowTitle,
      isFullScreen: _fullscreenChecker.isFullScreen(hwnd),
    );
  }

  /// The application's display name (e.g. "Visual Studio Code"), read from
  /// the executable's `FileDescription` version resource — the same field
  /// Task Manager shows — falling back to the bare executable name when
  /// unavailable (elevated/protected processes, or exes with no version
  /// info). Deliberately never the window title: that changes per
  /// document/tab/site, which would fragment usage tracking by title
  /// instead of by app and feed page/document names into the category
  /// rules' name matching (functional spec's nameKeywords vs
  /// windowTitleKeywords split already assumes `name` is the stable app
  /// identity, kept separately from `windowTitle`).
  String _friendlyName(String executablePath, String processName) {
    if (executablePath.isEmpty) return processName;
    return _friendlyNameCache.putIfAbsent(
      executablePath,
      () => readFileDescription(executablePath) ?? processName,
    );
  }

  int _queryProcessId(int hwnd) {
    final pidPtr = calloc<Uint32>();
    try {
      GetWindowThreadProcessId(hwnd, pidPtr);
      return pidPtr.value;
    } finally {
      calloc.free(pidPtr);
    }
  }

  String _queryExecutablePath(int pid) {
    // Fails (returns 0) for elevated/protected processes we don't have
    // access to query — that's fine, the caller falls back to "unknown".
    final hProcess = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid);
    if (hProcess == 0) return '';
    try {
      const maxPath = 260;
      final buffer = wsalloc(maxPath);
      final sizePtr = calloc<Uint32>();
      try {
        sizePtr.value = maxPath;
        final ok = QueryFullProcessImageName(hProcess, 0, buffer, sizePtr);
        return ok == 0 ? '' : buffer.toDartString();
      } finally {
        calloc.free(buffer);
        calloc.free(sizePtr);
      }
    } finally {
      CloseHandle(hProcess);
    }
  }

  String _queryWindowTitle(int hwnd) {
    final length = GetWindowTextLength(hwnd);
    if (length <= 0) return '';
    final buffer = wsalloc(length + 1);
    try {
      GetWindowText(hwnd, buffer, length + 1);
      return buffer.toDartString();
    } finally {
      calloc.free(buffer);
    }
  }
}

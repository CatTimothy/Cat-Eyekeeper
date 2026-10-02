import 'dart:ffi';

import 'package:ffi/ffi.dart';

// Hand-written FFI bindings for the small slice of Xlib (libX11) and the
// XScreenSaver extension (libXss) this app needs: reading the EWMH
// _NET_ACTIVE_WINDOW property for foreground-window tracking, window
// geometry for fullscreen detection, and XScreenSaverQueryInfo for idle
// time. These are long-stable, unchanged-for-decades parts of the X11 ABI.
//
// NOTE: this only runs on an X11 (or XWayland) session — see
// wayland_support.dart. It has not been build/run-verified on an actual
// Linux machine (this project was authored on Windows); double-check
// against a real X server before shipping.

const int _xAnyPropertyType = 0;
const int xaAtom = 4;
const int xaCardinal = 6;
const int xaWindow = 33;

typedef _XOpenDisplayNative = Pointer<Void> Function(Pointer<Utf8>);
typedef _XCloseDisplayNative = Int32 Function(Pointer<Void>);
typedef _XCloseDisplayDart = int Function(Pointer<Void>);
typedef _XDefaultRootWindowNative = UnsignedLong Function(Pointer<Void>);
typedef _XDefaultRootWindowDart = int Function(Pointer<Void>);
typedef _XInternAtomNative = UnsignedLong Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef _XInternAtomDart = int Function(Pointer<Void>, Pointer<Utf8>, int);
typedef _XFreeNative = Int32 Function(Pointer<Void>);
typedef _XFreeDart = int Function(Pointer<Void>);

typedef _XGetWindowPropertyNative =
    Int32 Function(
      Pointer<Void> display,
      UnsignedLong window,
      UnsignedLong property,
      Long longOffset,
      Long longLength,
      Int32 delete,
      UnsignedLong reqType,
      Pointer<UnsignedLong> actualTypeReturn,
      Pointer<Int32> actualFormatReturn,
      Pointer<UnsignedLong> nItemsReturn,
      Pointer<UnsignedLong> bytesAfterReturn,
      Pointer<Pointer<Uint8>> propReturn,
    );
typedef _XGetWindowPropertyDart =
    int Function(
      Pointer<Void> display,
      int window,
      int property,
      int longOffset,
      int longLength,
      int delete,
      int reqType,
      Pointer<UnsignedLong> actualTypeReturn,
      Pointer<Int32> actualFormatReturn,
      Pointer<UnsignedLong> nItemsReturn,
      Pointer<UnsignedLong> bytesAfterReturn,
      Pointer<Pointer<Uint8>> propReturn,
    );

typedef _XGetGeometryNative =
    Int32 Function(
      Pointer<Void> display,
      UnsignedLong drawable,
      Pointer<UnsignedLong> rootReturn,
      Pointer<Int32> xReturn,
      Pointer<Int32> yReturn,
      Pointer<Uint32> widthReturn,
      Pointer<Uint32> heightReturn,
      Pointer<Uint32> borderWidthReturn,
      Pointer<Uint32> depthReturn,
    );
typedef _XGetGeometryDart =
    int Function(
      Pointer<Void> display,
      int drawable,
      Pointer<UnsignedLong> rootReturn,
      Pointer<Int32> xReturn,
      Pointer<Int32> yReturn,
      Pointer<Uint32> widthReturn,
      Pointer<Uint32> heightReturn,
      Pointer<Uint32> borderWidthReturn,
      Pointer<Uint32> depthReturn,
    );

/// Mirrors `XScreenSaverInfo` from `X11/extensions/scrnsaver.h`.
final class XScreenSaverInfo extends Struct {
  @UnsignedLong()
  external int window;
  @Int32()
  external int state;
  @Int32()
  external int kind;
  @UnsignedLong()
  external int tilOrSince;
  @UnsignedLong()
  external int idle;
  @UnsignedLong()
  external int eventMask;
}

typedef _XScreenSaverQueryInfoNative =
    Int32 Function(Pointer<Void> display, UnsignedLong drawable, Pointer<XScreenSaverInfo> info);
typedef _XScreenSaverQueryInfoDart = int Function(Pointer<Void> display, int drawable, Pointer<XScreenSaverInfo> info);

typedef _XScreenSaverQueryExtensionNative =
    Int32 Function(Pointer<Void> display, Pointer<Int32> eventBaseReturn, Pointer<Int32> errorBaseReturn);
typedef _XScreenSaverQueryExtensionDart =
    int Function(Pointer<Void> display, Pointer<Int32> eventBaseReturn, Pointer<Int32> errorBaseReturn);

/// Thin wrapper around a single, lazily-opened `Display*` connection,
/// shared by every X11 reader so they don't each open their own
/// connection to the X server.
class X11 {
  X11._();

  static final X11 instance = X11._();

  late final DynamicLibrary _libX11 = DynamicLibrary.open('libX11.so.6');
  late final DynamicLibrary _libXss = DynamicLibrary.open('libXss.so.1');

  late final _xOpenDisplay = _libX11.lookupFunction<_XOpenDisplayNative, _XOpenDisplayNative>('XOpenDisplay');
  late final _xCloseDisplay = _libX11.lookupFunction<_XCloseDisplayNative, _XCloseDisplayDart>('XCloseDisplay');
  late final _xDefaultRootWindow = _libX11
      .lookupFunction<_XDefaultRootWindowNative, _XDefaultRootWindowDart>('XDefaultRootWindow');
  late final _xInternAtom = _libX11.lookupFunction<_XInternAtomNative, _XInternAtomDart>('XInternAtom');
  late final _xFree = _libX11.lookupFunction<_XFreeNative, _XFreeDart>('XFree');
  late final _xGetWindowProperty = _libX11
      .lookupFunction<_XGetWindowPropertyNative, _XGetWindowPropertyDart>('XGetWindowProperty');
  late final _xGetGeometry = _libX11.lookupFunction<_XGetGeometryNative, _XGetGeometryDart>('XGetGeometry');
  late final _xScreenSaverQueryInfo = _libXss
      .lookupFunction<_XScreenSaverQueryInfoNative, _XScreenSaverQueryInfoDart>('XScreenSaverQueryInfo');
  late final _xScreenSaverQueryExtension = _libXss
      .lookupFunction<_XScreenSaverQueryExtensionNative, _XScreenSaverQueryExtensionDart>('XScreenSaverQueryExtension');

  Pointer<Void>? _display;
  bool? _screenSaverExtensionAvailable;

  /// Opens (once) and returns the shared display connection, or null if
  /// the X server can't be reached (e.g. no X11 session — see
  /// wayland_support.dart).
  Pointer<Void>? get display {
    final existing = _display;
    if (existing != null) return existing;
    final opened = _xOpenDisplay(nullptr);
    if (opened == nullptr) return null;
    _display = opened;
    return opened;
  }

  int? rootWindow() {
    final d = display;
    if (d == null) return null;
    return _xDefaultRootWindow(d);
  }

  /// Resolves an atom name to its server-assigned id (varies per X
  /// server for non-predefined atoms like `_NET_ACTIVE_WINDOW`).
  int? internAtom(String name) {
    final d = display;
    if (d == null) return null;
    final namePtr = name.toNativeUtf8();
    try {
      final atom = _xInternAtom(d, namePtr, 0);
      return atom == 0 ? null : atom;
    } finally {
      calloc.free(namePtr);
    }
  }

  /// Reads a window property expected to hold a single unsigned-long
  /// value (e.g. `_NET_ACTIVE_WINDOW` on the root window, whose value is
  /// itself a Window id).
  int? getPropertyAsWindow(int window, int property) {
    final bytes = _getPropertyBytes(window, property, xaWindow, expectedFormat: 32);
    if (bytes == null || bytes.length < 8) return null;
    return _readUnsignedLong(bytes);
  }

  /// Reads a window property expected to hold a single CARDINAL (32-bit
  /// unsigned int) value, e.g. `_NET_WM_PID`.
  int? getPropertyAsCardinal(int window, int property) {
    final bytes = _getPropertyBytes(window, property, xaCardinal, expectedFormat: 32);
    if (bytes == null || bytes.length < 4) return null;
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  /// Reads a window property expected to hold a UTF8_STRING, e.g.
  /// `_NET_WM_NAME`. [utf8StringAtom] must be resolved via [internAtom]
  /// first since it isn't a predefined atom.
  String? getPropertyAsUtf8String(int window, int property, int utf8StringAtom) {
    final bytes = _getPropertyBytes(window, property, utf8StringAtom, expectedFormat: 8);
    if (bytes == null) return null;
    try {
      return String.fromCharCodes(bytes);
    } on Object {
      return null;
    }
  }

  List<int>? _getPropertyBytes(int window, int property, int reqType, {required int expectedFormat}) {
    final d = display;
    if (d == null) return null;

    final actualType = calloc<UnsignedLong>();
    final actualFormat = calloc<Int32>();
    final nItems = calloc<UnsignedLong>();
    final bytesAfter = calloc<UnsignedLong>();
    final propReturn = calloc<Pointer<Uint8>>();
    try {
      final status = _xGetWindowProperty(
        d,
        window,
        property,
        0,
        1024,
        0,
        reqType == _xAnyPropertyType ? _xAnyPropertyType : reqType,
        actualType,
        actualFormat,
        nItems,
        bytesAfter,
        propReturn,
      );
      if (status != 0) return null;
      final data = propReturn.value;
      if (data == nullptr) return null;
      if (actualFormat.value != expectedFormat) {
        _xFree(data.cast());
        return null;
      }

      final itemBytes = expectedFormat ~/ 8;
      final length = nItems.value * itemBytes;
      final result = List<int>.generate(length, (i) => data[i]);
      _xFree(data.cast());
      return result;
    } finally {
      calloc.free(actualType);
      calloc.free(actualFormat);
      calloc.free(nItems);
      calloc.free(bytesAfter);
      calloc.free(propReturn);
    }
  }

  int _readUnsignedLong(List<int> bytes) {
    var value = 0;
    for (var i = bytes.length - 1; i >= 0; i--) {
      value = (value << 8) | bytes[i];
    }
    return value;
  }

  /// Returns (width, height) of [drawable] — a window or the root window.
  ({int width, int height})? getGeometry(int drawable) {
    final d = display;
    if (d == null) return null;

    final rootReturn = calloc<UnsignedLong>();
    final xReturn = calloc<Int32>();
    final yReturn = calloc<Int32>();
    final widthReturn = calloc<Uint32>();
    final heightReturn = calloc<Uint32>();
    final borderWidthReturn = calloc<Uint32>();
    final depthReturn = calloc<Uint32>();
    try {
      final status = _xGetGeometry(
        d,
        drawable,
        rootReturn,
        xReturn,
        yReturn,
        widthReturn,
        heightReturn,
        borderWidthReturn,
        depthReturn,
      );
      if (status == 0) return null;
      return (width: widthReturn.value, height: heightReturn.value);
    } finally {
      calloc.free(rootReturn);
      calloc.free(xReturn);
      calloc.free(yReturn);
      calloc.free(widthReturn);
      calloc.free(heightReturn);
      calloc.free(borderWidthReturn);
      calloc.free(depthReturn);
    }
  }

  /// Milliseconds since the last keyboard/mouse input, via the
  /// XScreenSaver extension. Returns null if the extension isn't
  /// available or the query fails.
  int? screenSaverIdleMilliseconds() {
    final d = display;
    if (d == null) return null;
    if (!_hasScreenSaverExtension(d)) return null;
    final root = rootWindow();
    if (root == null) return null;

    final info = calloc<XScreenSaverInfo>();
    try {
      final ok = _xScreenSaverQueryInfo(d, root, info);
      if (ok == 0) return null;
      return info.ref.idle;
    } finally {
      calloc.free(info);
    }
  }

  /// Caches whether the server has the MIT-SCREEN-SAVER extension at all,
  /// checked via XScreenSaverQueryExtension. Without this cache,
  /// XScreenSaverQueryInfo would be called every tracking tick on a
  /// server that lacks the extension, and Xlib logs a warning to stderr
  /// on every such failed call rather than just the first.
  bool _hasScreenSaverExtension(Pointer<Void> d) {
    final cached = _screenSaverExtensionAvailable;
    if (cached != null) return cached;

    final eventBase = calloc<Int32>();
    final errorBase = calloc<Int32>();
    try {
      final available = _xScreenSaverQueryExtension(d, eventBase, errorBase) != 0;
      _screenSaverExtensionAvailable = available;
      return available;
    } finally {
      calloc.free(eventBase);
      calloc.free(errorBase);
    }
  }

  void close() {
    final d = _display;
    if (d != null) {
      _xCloseDisplay(d);
      _display = null;
      _screenSaverExtensionAvailable = null;
    }
  }
}

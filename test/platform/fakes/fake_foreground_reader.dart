import 'package:cat_eyekeeper/domain/models/foreground_app.dart';
import 'package:cat_eyekeeper/data/services/platform/foreground_reader.dart';

/// A settable foreground-app signal for tests.
class FakeForegroundReader implements ForegroundReader {
  FakeForegroundReader({this.app});

  ForegroundApp? app;

  @override
  ForegroundApp? current() => app;
}

import 'package:flutter_test/flutter_test.dart';
import 'package:cat_eyekeeper/domain/use_cases/category_classifier.dart';
import 'package:cat_eyekeeper/domain/models/app_category.dart';
import 'package:cat_eyekeeper/domain/models/category_rule.dart';
import 'package:cat_eyekeeper/domain/models/foreground_app.dart';

ForegroundApp _app({String processName = '', String name = '', String windowTitle = '', String executablePath = ''}) =>
    ForegroundApp(
      processId: 1,
      name: name,
      processName: processName,
      executablePath: executablePath,
      windowTitle: windowTitle,
      isFullScreen: false,
    );

void main() {
  final rules = CategoryRules(
    version: 1,
    rules: const [
      CategoryRule(category: AppCategory.work, processNames: ['code']),
      CategoryRule(category: AppCategory.entertainment, nameKeywords: ['Steam']),
      CategoryRule(category: AppCategory.social, windowTitleKeywords: ['Zoom Meeting']),
    ],
  );
  final classifier = CategoryClassifier(rules);

  test('an exact process name match classifies correctly', () {
    expect(classifier.classify(_app(processName: 'code')), AppCategory.work);
  });

  test('an unmatched app falls back to other', () {
    expect(classifier.classify(_app(processName: 'randomthing')), AppCategory.other);
  });

  test('a display-name keyword match classifies correctly', () {
    expect(classifier.classify(_app(name: 'Steam Client')), AppCategory.entertainment);
  });

  test('a window-title keyword match classifies correctly', () {
    expect(classifier.classify(_app(windowTitle: 'Zoom Meeting - Standup')), AppCategory.social);
  });

  test('an exact process name match (+100) outweighs a window-title match (+45) on another rule', () {
    final app = _app(processName: 'code', windowTitle: 'Zoom Meeting');
    expect(classifier.classify(app), AppCategory.work);
  });
}

#!/usr/bin/env bash
# Enforces the one-way dependency direction from the project plan:
#   domain/models -> data/{repositories,services} -> domain/use_cases -> di -> ui
# (services/platform and services/app are visible to domain/use_cases/ and
# ui/, wired up via data/services/platform/platform_factory.dart.)
#
# Rule 1: domain/, data/repositories/, and data/services/platform/ must
#         stay pure Dart -- no package:flutter import, so they can run
#         under `dart test` without a widget test harness.
#         data/services/app/ (old services/ -- TrayService, WindowShell,
#         ThemeService, ...) is deliberately exempt, same as before the
#         restructure: those were never required to be pure Dart.
# Rule 2: within lib/ui/, `*/view_models/*.dart` files (ViewModels -- e.g.
#         lib/ui/core/view_models/, lib/ui/<feature>/view_models/) may
#         never import package:flutter/material.dart, widgets.dart, or
#         cupertino.dart -- ViewModels stay widget-free and unit-testable
#         under plain `flutter test`, with no widget harness. Everything
#         else in ui/ (views, shared ui/core/ widgets) is free to resolve
#         get_it singletons directly (getIt<WindowShell>(), etc.) for
#         one-off/stateless actions -- get_it removes the provider-graph
#         indirection that used to force those through a bridge, so a View
#         reaching into data/ or domain/use_cases/ for a simple action call
#         is expected, not a violation. Reactive/derived state still
#         belongs in a ViewModel; this rule only guards the ViewModel ->
#         Flutter direction, not the View -> data direction.
set -euo pipefail
cd "$(dirname "$0")/.."

fail=0

echo "Checking domain/, data/repositories/, data/services/platform/ for package:flutter imports..."
if grep -rn --include='*.dart' "import 'package:flutter" lib/domain lib/data/repositories lib/data/services/platform 2>/dev/null; then
  echo "FAIL: the above file(s) import package:flutter but must stay pure Dart."
  fail=1
fi

echo "Checking */view_models/* for package:flutter/{material,widgets,cupertino}.dart imports..."
if grep -rnE --include='*.dart' "import 'package:flutter/(material|widgets|cupertino)\.dart'" lib/ui/*/view_models lib/ui/*/*/view_models 2>/dev/null; then
  echo "FAIL: the above ViewModel file(s) import a Flutter UI package; ViewModels must stay widget-free."
  fail=1
fi

if [ "$fail" -eq 0 ]; then
  echo "OK: dependency direction holds."
fi

exit $fail

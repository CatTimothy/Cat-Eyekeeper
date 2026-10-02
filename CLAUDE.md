# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Cat Eyekeeper (package name `cat_eyekeeper`) is a Flutter desktop app — **Windows and Linux only** (no android/, ios/, or macos/ platform dirs). It tracks foreground-app usage time, classifies it into categories, and shows periodic break reminders with animated overlays. It lives in the system tray and can start at login.

## Commands

```bash
flutter pub get                        # install deps / regenerate lib/l10n/app_localizations.dart
flutter analyze                        # static analysis (analysis_options.yaml extends flutter_lints)
flutter test                           # run all tests
flutter test test/core/tracking_engine_reset_test.dart   # single test file
flutter test --plain-name "some test name"                # single test by name
flutter run -d windows                 # or -d linux
tool/check_layering.sh                 # enforce the architecture rule below (bash; run via Git Bash/WSL on Windows)
```

Packaging (produces artifacts under `build/` and `dist/`; see header comments in each script for one-time toolchain setup):

```powershell
pwsh tool/package_windows.ps1          # portable .zip + WiX .msi + .msix
```
```bash
tool/package_linux.sh                  # .deb via fastforge (not build-tested on real Linux — see script header)
```

There is no separate lint-fix command; fix `flutter analyze` warnings by hand. `flutter test` is the only test runner (plain `package:flutter_test`, no golden files, no integration_test suite).

## Architecture

MVVM with `get_it` for DI and `freezed` for immutable domain models — no Riverpod, no `InheritedWidget`-based state management anywhere in the app.

### Layering (enforced by `tool/check_layering.sh`, run it after moving files across layers)

```
domain/models -> data/{repositories,services} -> domain/use_cases -> di -> ui/{core,<feature>}/{view_models,views}
```

- `domain/`, `data/repositories/`, and `data/services/platform/` **must stay pure Dart** — no `package:flutter` import — so they run under plain `dart test`/`flutter test` without a widget harness. `data/services/app/` (`TrayService`, `WindowShell`, `ThemeService`, ...) is exempt from this — those legitimately touch Flutter/native-plugin APIs.
- `data/services/platform/platform_factory.dart`'s `PlatformServices.forCurrentPlatform()` picks the concrete Windows (`data/services/platform/windows/`) or Linux/X11 (`data/services/platform/linux/`) implementation of each reader interface at startup. It hands back raw readers rather than an assembled `IdleDetector` — that composition happens in `di/injection.dart`.
- Every `*/view_models/*.dart` file (ViewModels) must stay widget-free: no `package:flutter/material.dart`, `widgets.dart`, or `cupertino.dart` import, so they're unit-testable under plain `flutter test` with no widget harness (see `test/ui/*/view_models/`). Views are otherwise free to resolve `get_it` singletons directly (`getIt<WindowShell>()`, `getIt<TrackingEngine>()`, etc.) for one-off/stateless actions — there's no provider-graph indirection to route through, so a View calling straight into `data/` or `domain/use_cases/` for a simple action is expected, not a layering violation. Reactive/derived state still belongs in a ViewModel.
- `lib/ui/shell/app_shell.dart` is a deliberate, documented exception living at the same tier as `main.dart`/`app.dart` (composition roots) despite physically sitting inside `lib/ui/` — it's the one View that must also be a real widget `State` implementing `WindowListener` (window_manager's `addListener` needs a live State, not a ViewModel), and whose `devicePixelRatio` read must stay directly adjacent to the `window_manager.setBounds()` call it feeds, with zero indirection (see its own comments for the multi-monitor bug that any extra hop — even a same-frame callback into a separate ViewModel — previously caused).

### Dependency injection (`lib/di/injection.dart`, `lib/ui/core/view_models/view_model_injection.dart`)

`configureDependencies()` constructs every repository/service/engine exactly once, before the widget tree exists — concurrently loading settings/today's-usage/category-rules, building `PlatformServices`, then `TrackingEngine` (seeded with that already-loaded usage) and every other service — and registers each as a `getIt` singleton. It also wires `trackingEngine.snapshots.listen(reminderScheduler.observe)`, the only place tracking gets connected to reminders. `AppLifecycle` (itself a `getIt` singleton) replaces the old `AppBootstrap.start()`/`.dispose()` with the same ordering.

`configureViewModels()` is a separate function, called from `main.dart` right after `configureDependencies()` — kept separate because `di/injection.dart` must never import from `ui/` (DI sits below UI in the dependency direction), while `main.dart`, as the composition root, is free to import both.

Rule of thumb for new ViewModels: **`registerSingleton`** for shared/cross-feature/long-lived state (e.g. `SettingsViewModel`, `UpdateCheckViewModel` — shown on both About and Settings, so one instance keeps them in sync); **`registerFactory`** for screen-scoped ViewModels (e.g. `DashboardViewModel`, `SettingsScreenViewModel`, `ReminderViewModel` — a fresh instance every time the owning screen is (re)shown, which is also what makes `DashboardViewModel` reload cleanly from disk after Settings' "clear data" action with no separate invalidation step).

### ViewModels (`lib/ui/core/base_view_model.dart`)

Every ViewModel extends `BaseViewModel extends ChangeNotifier`, which adds `addSubscription(StreamSubscription)` (tracked and cancelled in `dispose()`) and `safeNotifyListeners()` (safe to call from a callback that may fire post-disposal). Stream-driven ViewModels (dashboard live updates, reminder countdown, tray coordinator) subscribe via this instead of relying on any framework-provided teardown. Views wire up with `ListenableBuilder`/`Listenable.merge`, not `Consumer`/`ref.watch`.

### Core domain (`lib/domain/use_cases/`)

`TrackingEngine` is the app's single source of truth: a 1-second `Timer.periodic` ticker that reads idle time + the current foreground app, accumulates active seconds per app and per category-per-hour, and publishes a `UsageSnapshot` on a broadcast stream every tick. Everything else (dashboard, reminders, tray) subscribes independently — the engine doesn't know who's listening. On an active→idle transition it "rewinds" the trailing seconds that were counted active before the idle threshold tripped (`_rewindIdleTail`), since idle detection only fires once the threshold has fully elapsed. It also autosaves on 5-minute wall-clock boundaries and on date rollover.

`ReminderScheduler` is purely reactive (`observe(UsageSnapshot)`, no timer of its own) — it fires a `ReminderRequest` once continuous active time crosses the configured threshold, unless already open, reminders are disabled, tracking is paused, or `ReminderGuard.suppressReminder` vetoes it (e.g. fullscreen apps). It also caches the most recent request as `lastRequest`, since there's no framework-level "last value" caching to lean on outside a real stream subscription.

### Data layer (`lib/data/repositories/`)

One JSON file per calendar day under an app-data `usage/` directory (`UsageRepository`), plus single-file JSON for settings and category rules. All writes go through `AtomicWriter`: write to a `.tmp` file, then rename over the target, retrying the rename a few times (Windows can transiently lock a file, e.g. AV scanning). A corrupt/unparseable file is backed up (`.corrupt`) and replaced with an empty record rather than crashing.

### Domain models (`lib/domain/models/`)

All 13 models are `@freezed` (immutability, generated `copyWith`/`==`, and `fromJson`/`toJson` via `json_serializable` for the persisted ones). `build.yaml` sets `json_serializable: explicit_to_json: true` — required for nested freezed types to actually call their own `toJson()` rather than being serialized shallowly. Generated `*.freezed.dart`/`*.g.dart` files are gitignored; run `flutter pub get` or `dart run build_runner build` after editing a model. A few models still carry hand-written pieces alongside the generated mixin, which freezed permits as long as they don't declare extra fields: `Settings`/`CustomThemeColors` use `@JsonKey(fromJson:, defaultValue:)` field converters for enum-fallback-to-default parsing; `CategoryRules.mergedWith` is a plain instance method; `Settings.defaults()`/`CategoryRules.defaults()` are ordinary `static` factories.

### UI (`lib/ui/`)

Each feature lives under `ui/<feature>/` with a `view_models/` and (implicitly, at the top level of that folder plus a `widgets/` subfolder) views split — e.g. `ui/dashboard/view_models/dashboard_view_model.dart` + `ui/dashboard/dashboard_screen.dart` + `ui/dashboard/widgets/`. Shared cross-feature ViewModels and widget-free helpers live under `ui/core/` (`base_view_model.dart`, `format.dart`, `responsive.dart`, `view_models/`).

### Localization

ARB sources live in `lib/l10n/` (`app_en.arb` is the template); `flutter pub get` / any build regenerates `lib/l10n/app_localizations.dart` via `generate: true` in `pubspec.yaml` + `l10n.yaml` — don't hand-edit the generated file. Untranslated strings get reported to `l10n_untranslated.json`.

### Platform notes

- Windows readers (`data/services/platform/windows/`) use `win32`/FFI. Linux readers (`data/services/platform/linux/`) use X11 (`data/services/platform/linux/x11_bindings.dart`) for foreground/idle/fullscreen detection, `dbus` for MPRIS media keys, and have no icon/desktop-capture support (`Null*` no-op implementations).
- `video_player` is backed by `fvp`'s mdk engine (registered once in `main.dart`) instead of the stock platform implementation, specifically so reminder animation videos can carry an alpha channel over the blurred desktop backdrop.

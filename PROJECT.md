# VoiceLab — project guide

Record a voice, clone it, and speak Nepali, Sanskrit or English.

One guide for humans and agents alike. `CLAUDE.md` and `AGENTS.md` point here.

## 1. Stack

| Concern | Choice |
|---|---|
| Material | `package:material_ui` — **not** `package:flutter/material.dart` |
| State | Riverpod 3, no code generation |
| Routing | `go_router` with a `StatefulShellRoute` |
| Localization | `flutter gen-l10n` from `lib/l10n/*.arb` (en, ne) |
| Icons | `picons` (`PiconsRegular.*`) |
| Backend | none — fully offline |
| Local storage | `shared_preferences` only |
| Platforms | Android desktop |

## 2. The one rule that will bite you

**Never import `package:flutter/material.dart`.** Import
`package:material_ui/material_ui.dart` instead.

Both libraries define `ThemeData`, `TextTheme`, `Icon` and friends. They are
different types with the same names, so mixing them produces errors like *"the
argument type 'ThemeData' can't be assigned to the parameter type
'ThemeData'"*. `test/no_frozen_material_test.dart` fails the build if any file
under `lib/` breaks this rule.

Third-party packages that still use frozen Material (`google_fonts`,
`go_router`, `picons`) are fine — `MaterialUiCompatibilityBridge`, wired into
`MaterialApp.builder` in `core/app.dart`, bridges them.

Two consequences worth knowing:

- Use `googleFontsTextTheme(base, GoogleFonts.inter)` from
  `core/theme/google_fonts_text_theme.dart`, never `GoogleFonts.interTextTheme()` —
  the latter returns a frozen `TextTheme` that `material_ui`'s `ThemeData`
  rejects.
- Localization delegates come from `GlobalMaterialLocalizations.delegates`
  (exported by `material_ui`), covering Flutter, Material and Cupertino. This
  app neither declares nor imports `flutter_localizations`.

  That package has **not** been decoupled from the SDK — only the Material and
  Cupertino localizations moved out, into `material_ui` and `cupertino_ui`.
  `GlobalWidgetsLocalizations` stayed behind because the widgets layer did, so
  `material_ui` still depends on `flutter_localizations` itself. It is in your
  dependency graph either way; you just never name it.

## 3. Layout

```
lib/
  main.dart                  entry: bootstrap, then runApp
  core/
    app.dart                 root MaterialApp — theme, locale, bridge
    bootstrap.dart           ordered async init  ← REGISTRY
    config/app_config.dart   compile-time config and --dart-define overrides
    router/
      routes.dart            every path constant  ← REGISTRY
      navigation.dart        context.goTo / pushTo / back
      router.dart            the router itself
    settings/                AppSettings model + persisted controller
    theme/                   tokens, accent palette, ThemeData, font bridge
    ui/                      shared widgets: views, async_view, feedback
    util/                    responsive, launcher
  l10n/                      app_en.arb, app_ne.arb, generated output
  features/
    <feature>/               one folder per feature
    settings/
      tiles.dart             settings rows  ← REGISTRY
```

### The three registries

Extending the app means adding an entry to one of these, not editing shared
code. That is what lets two features be added without touching the same lines.

| Registry | Add to it when |
|---|---|
| `core/bootstrap.dart` | you need async work before the first frame, or a resource handed to a provider |
| `core/router/routes.dart` + `router.dart` | you add a screen |
| `features/settings/tiles.dart` | you add a settings row |

## 4. Conventions

- **No hardcoded values.** Spacing, radii, durations and border widths come
  from `core/theme/tokens.dart`. Colours come from `Theme.of(context).colorScheme`.
- **No hardcoded strings.** Everything user-visible goes through
  `AppLocalizations.of(context)`, with entries in **both** `app_en.arb` and
  `app_ne.arb`.
- **One widget per file** unless a widget is private to its parent and used
  nowhere else.
- **Immutable models** with `copyWith`. Use an explicit `clearX` flag to set a
  nullable field back to null.
- **Provider naming:** `xRepositoryProvider`, `xControllerProvider` (async
  actions), `xProvider.family` (keyed lookup), `xNotifierProvider` (mutable
  state).
- Prefer `ref.watch(p.select((s) => s.field))` over watching a whole object
  when a widget needs one field.

## 5. Common tasks

### Add a screen

1. `lib/features/<name>/<name>_screen.dart`
2. Add its path to `core/router/routes.dart`
3. Register it in `core/router/router.dart`
4. Add its strings to both `.arb` files

### Add a string

Add the key to `lib/l10n/app_en.arb` **and** `lib/l10n/app_ne.arb`, then rebuild.
`generate: true` in `pubspec.yaml` regenerates `AppLocalizations` on the next
`flutter run`/`build`; `flutter gen-l10n` does it on demand.

### Run

```sh
flutter run
flutter test
flutter analyze
```

### Store screenshots

```sh
flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d <device>
```

Output lands in `build/screenshots/`. Edit the nav steps in
`integration_test/screenshot_test.dart` as the app grows; the helper fails the
run if it captures nothing, because a green run with an empty store listing is
indistinguishable from a working one.

## 7. Anti-patterns

- `import 'package:flutter/material.dart'` — see §2.
- `GoogleFonts.xTextTheme()` — see §2.
- Raw `Color(0xFF…)` in a widget — use the colour scheme.
- Literal strings in the UI — use the ARB files.
- `withOpacity` — deprecated; use `withValues(alpha: x)`.
- Editing `lib/l10n/app_localizations*.dart` — it is generated.

# VoiceLab

Record a voice, clone it, and speak Nepali, Sanskrit or English.

Generated with [beej](https://github.com/lohanidamodar/beej).

## Getting started

```sh
flutter pub get
flutter run
```

On Windows, run `flutter` from PowerShell rather than WSL.

## What's in the box

- **Material** via `package:material_ui` (decoupled from the Flutter SDK)
- **Riverpod 3** for state, no code generation
- **go_router** for routing
- **Localization** in `lib/l10n/` — en, ne
- **Theming** with a user-selectable accent, theme mode and text size

See [PROJECT.md](PROJECT.md) for the full tour.

## Licence

MIT — see [LICENSE](LICENSE).

The speech models are not MIT, and one recogniser is not open source at all.
None are bundled: VoiceLab downloads the model you choose from its publisher and
shows the licence first. See
[THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md).

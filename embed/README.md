# FishFeed app

Flutter app for the FishFeed automatic fish feeder. See the
[main README](../README.md) for features, screenshots and setup.

```bash
flutter pub get
flutter run                                         # demo mode, no Firebase needed
flutter run --dart-define-from-file=firebase.json   # real device through Firebase
flutter test
```

- `lib/data/` – `FirebaseBackend` (real device) and `DemoBackend` (simulation)
- `lib/logic/` – sensor status, warnings, schedule and statistics, no Flutter code
- `lib/ui/` – pages, theme and widgets
- `tool/generate_icons.py` – regenerates the launcher icons

name: Build APK

on:
  workflow_dispatch:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Find and fix main.dart
        run: |
          echo "=== Repo files ==="
          find . -path ./.git -prune -o -type f -print
          mkdir -p lib
          if [ ! -f lib/main.dart ]; then
            F=$(find . -path ./.git -prune -o -type f -iname 'main.dart*' -print | head -n 1)
            echo "Found: $F"
            if [ -n "$F" ]; then cp "$F" lib/main.dart; fi
          fi
          test -f lib/main.dart || (echo "MAIN.DART REPO ME NAHI HAI" && exit 1)

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: '17'

      - uses: subosito/flutter-action@v2
        with:
          channel: stable

      - name: Create Android project files
        run: |
          flutter create --platforms=android --project-name call_guard tmp_app
          cp -r tmp_app/android android
          sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application#' android/app/src/main/AndroidManifest.xml

      - run: flutter pub get

      - run: flutter build apk --release

      - uses: actions/upload-artifact@v4
        with:
          name: call-guard-apk
          path: build/app/outputs/flutter-apk/app-release.apk

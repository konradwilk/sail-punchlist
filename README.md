# Sail Punchlist

Two independent native apps for Pre-Sail and Post-Sail checklists:

- **iOS:** Objective-C, UIKit, and Foundation. iOS 16 or later.
- **Android:** Kotlin and Android platform widgets. Android 8 or later.

No React Native, Expo, JavaScript runtime, Node, CocoaPods, backend, or account.
The apps use only platform APIs and language standard libraries. `checklists.json` is static
content packaged by each platform's build.

## Use

Review every item with green Done or red Issue controls. Issues can have an optional note and do not
block completion. Drag directly on the 0–100% fuel dial and enter engine hours, then complete the
checklist to save a record and switch phases. Each phase has its own saved draft.
Fuel starts at 50% on first launch. After completion, the next checklist defaults
to one percentage point below the saved reading, with a minimum of 0%. Reopening
an unfinished checklist keeps its current fuel reading.
Engine hours accept decimals and cannot go below the last completed reading.
Each new checklist starts at the last completed reading + 1 hour. Reopening an
unfinished checklist keeps any engine reading you have entered.

History shows completion time, fuel, engine hours, and issue notes. Export JSON or CSV
from History to save a copy. CSV export contains one row per completed checklist
item, including its status and note, together with the completion time, phase,
fuel percentage, and engine hours. Drafts and records live in a local JSON file using
atomic writes. An unreadable file stops editing instead of silently resetting it.
Uninstalling the app can delete its local records.

This is a fresh implementation with a new local file format. There is no import
or migration from the previous application.

## iOS

Open `ios/SailPunchlist.xcodeproj` in Xcode. Select the SailPunchlist scheme,
choose your device or simulator, and run. For a physical device, select your
signing team under Signing & Capabilities. Both Debug and Release are standalone.

Command-line simulator build:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project ios/SailPunchlist.xcodeproj -scheme SailPunchlist \
  -sdk iphonesimulator -derivedDataPath .build/ios CODE_SIGNING_ALLOWED=NO build
```

## Android

Open `android/` in Android Studio and run the app on a device or emulator.
Install SDK Platform 36 and use JDK 17. The Gradle wrapper downloads the build
tools on its first run. Set your SDK path in Android Studio, `ANDROID_HOME`, or
`android/local.properties` (`sdk.dir=/your/sdk/path`).

```sh
cd android
./gradlew :app:assembleDebug
```

APK: `android/app/build/outputs/apk/debug/app-debug.apk`.
Release distribution needs your own signing configuration.

## Clean build files

Run `./scripts/clean-build.sh` to remove generated iOS and Android build outputs,
test results, and project-local Gradle caches. Source files, signing settings,
and saved data on devices and simulators are left untouched. The next build
recreates the generated files.

## Verification

On macOS, run `./tests/run-ios.sh` to exercise the actual Objective-C store:
completion validation, draft persistence, issue history, decimal readings,
failed-write rollback, and unreadable-file protection.

In Xcode, choose Product → Test to run the fuel-dial regression tests against
the real UIKit control, including dragging from 0% to 75% and across the dial.

See `tests/README.md` for build checks and device checks.

## License

Application code: BSD-3-Clause (`LICENSE`). Gradle wrapper: Apache-2.0;
its license is embedded in `android/gradle/wrapper/gradle-wrapper.jar`.

# Sail Punchlist

An Expo / React Native iOS and Android app for the supplied Pre-Sail and
Post-Sail checklists. Uses the approved grouped layout with all groups open.
Each item offers ✓ Done or ✕ Issue; selecting Issue reveals an optional note.
Issues do not block completion. Every item must be reviewed and fuel and engine
hours entered before saving. Saving switches to the other phase; the phase tabs
also allow manual changes while retaining each draft.

History includes the completion date/time, fuel percentage, engine hours,
account email, and every issue/comment. History is shared locally across accounts
on the same installation. Signing out does not delete records or drafts.

## Run

Requires Node 20.19+ and pnpm.

```sh
pnpm install
pnpm start
pnpm web
```

Web is a layout preview: it uses browser local storage and JSON downloads.
Native builds use a real JSON file in the application's Documents directory.
Native account sign-in is required to save a completed checklist. Drafts can be
edited and saved before sign-in. Web does not simulate an authenticated account.

```sh
pnpm typecheck
pnpm test
pnpm exec expo export --platform all
```

## iOS / Apple sign-in

Use Xcode and CocoaPods for a local native build. If the selected developer
directory points to command-line tools, use:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer pnpm build:ios
```

The app config enables Sign in with Apple and includes its config plugin.
For device distribution, use your own bundle identifier, Apple Developer team,
and provisioning profile with the Sign in with Apple capability. EAS development
builds are also supported by eas.json; connect your Expo project before using EAS.
No developer credentials are included in the repository.

Apple may provide a private relay address. Its initial email is cached in Secure
Store because Apple usually only supplies it on first authorization. After a
reinstall, if Apple provides no email and the cache is missing, revoke this app's
Apple authorization in Settings and authorize again. No fabricated email is used.

## Android / Google sign-in

Use an Android SDK/emulator or a physical device and a native development build;
the Google sign-in native module is not available in Expo Go.

1. Set your final Android package in app.json (currently com.sailpunchlist.app).
2. Configure a Google Cloud OAuth consent screen and test users as needed.
3. Create an Android OAuth client for that package and each signing certificate's
   SHA-1 (development, release, and Play App Signing as applicable).
4. Create a Web application OAuth client in the same Google project. Copy
   .env.example to .env and set EXPO_PUBLIC_GOOGLE_WEB_CLIENT_ID to that client ID.
   This is a public client identifier, not a client secret.
5. Run pnpm build:android with Android SDK tools installed. For EAS, set the same
   environment variable in the build environment and rebuild after config changes.

Sign-in associates the native provider's email with local records; there is no
backend or cloud sync, and no access/refresh tokens are written to the JSON file.

## Storage and backup

Native file: Documents/sail-punchlist.json. Writes are serialized and retain
sail-punchlist.backup.json. An unreadable main file is preserved and the backup
is loaded when valid; if neither is readable, editing stays disabled to avoid
silently replacing records. Export JSON from History or Account for backup.
iOS Files sharing is enabled. Uninstalling may remove local records.

Engine hours allow decimals and default to the last completed reading + 1 for
the next checklist. In-progress edited readings are preserved between launches.
The last recorded reading is the minimum accepted completion value.

## Licenses

Application code: BSD-3-Clause (LICENSE). Original gauge artwork:
CC0-1.0 (licenses/CC0-1.0.txt). See 3RDPARTYLICENSE.txt for its picture and source
references. Third-party packages retain their own licenses. The lockfile pins
the installed dependency versions.

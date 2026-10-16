# Verification

`pnpm test` checks the completion cycle, optional issue comments, immutable
record values, validation, fractional engine readings, JSON round trips, and
independent phase drafts. Storage tests also cover concurrent writes, disk-write
failures, backup recovery, and preserving corrupt files. `pnpm typecheck` checks all application screens.

Browser smoke check (web preview): select an Issue, enter a note, fuel, and
engine hours; reload and verify all four remain. Native sign-in must be tested
on devices with the developer account configuration described in README.md.

Verified during implementation:
- TypeScript: passed.
- Eleven model/storage tests: passed.
- Expo production bundles: iOS, Android, and web passed.
- Expo native project generation: iOS and Android passed.
- Browser preview: issue note, fuel, and engine reading preserved after reload.

The storage tests exercise the real storage module with an in-memory adapter
for the native filesystem APIs, including simulated disk errors and interrupted
writes. They do not replace a physical-device test of filesystem behavior.
- Native iOS Release simulator build: BUILD SUCCEEDED with Xcode 26.6.
- Installed and launched com.sailpunchlist.app on the iPhone 17 Pro simulator.
- Native visual inspection was blocked by missing Computer Use permission.
- Real Apple/Google authorization and Android native compilation remain untested;
  developer OAuth/provisioning configuration and an Android SDK/device are needed.

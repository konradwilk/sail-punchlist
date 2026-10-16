# Verification

`./tests/run-ios.sh` compiles and runs the actual Objective-C store on macOS.
It covers required answers, optional issue notes, CSV headers and escaping of commas, quotes, and newlines, fuel bounds, invalid engine
readings, decimal readings, monotonic engine readings, draft persistence,
automatic suggested hours, history snapshots, failed-save rollback, and refusing
to overwrite unreadable data. It creates and removes its own temporary data.

In Xcode, Product → Test runs `SailPunchlistTests`. These tests invoke the
UIKit touch-tracking callbacks on the real fuel control, check that dragging
0% → 75% → 100% emits updated values, check dragging across and back, verify
that the gauge renders a changed reading, and check that page scrolling does
not cancel tracking. They do not simulate a physical finger on a device.

Verified during native implementation:

- Objective-C store tests passed.
- Four UIKit fuel-dial regression tests passed on the iPhone 17 Pro simulator after fixing the tracking callback names.
- iOS Debug and Release simulator builds succeeded with Xcode 26.6.
- App installed and launched on the iPhone 17 Pro / iOS 26.5 simulator.
- Simulator screenshot inspected for initial layout.
- Android debug APK built successfully with JDK 17 and SDK Platform 36.
- Green/red checklist controls and the 0–100% fuel dial compile on both platforms; interactive visual verification of this update was blocked by Simulator control permission.
- Android lint completed with zero errors; English text and build-tool update warnings remain.

The Android app has not been run on a device or emulator. Signing and physical
device distribution are not configured.

Before shipping, check on each platform:

1. Mark an Issue, enter a note and readings, then restart. The draft should remain.
2. Try completing an unreviewed checklist and invalid readings; completion should be refused.
3. Complete a checklist with an issue. Verify the opposite phase opens and History includes the issue and readings.
4. Export JSON and CSV and open both files. Check that CSV contains completed records, including notes with commas, quotes, and line breaks.
5. Drag the fuel dial to 0%, 50%, and 100%; check the dial and saved reading after restart. Check that dragging the dial does not scroll the page, that scrolling outside it works, and that screen reader adjustment works. Check green Done and red Issue states, including switching between them. Check that the active Pre-Sail/Post-Sail tab is green.
6. Check keyboard access to the bottom fields, rotation, large text, and screen reader labels.

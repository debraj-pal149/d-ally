# Run d·ally

See **[README.md](README.md)** for product overview, notifications, and deep links.

## Quick start

1. Open `DAlly.xcodeproj` (Xcode 16+, iOS 18+).
2. Select the **DAlly** scheme and a device (preferred) or simulator.
3. Set **Signing Team** if prompted → Run (⌘R).

## First launch

1. Welcome → **Start**.
2. Day → **+** to add a reminder (specific time or finish-by window).
3. Allow alerts when asked.

## Smoke checks

- Mark kept / skip on **today** and on a **previous** day (each day is independent).
- Calendar shows **all** kept dots for a day (multi-line if needed).
- Sunday: in-app **Review your week** banner → Calendar.
- Settings → Alerts blurb about daily rhythm.

## Optional Simulator seed

```bash
xcrun simctl spawn booted defaults write com.dally.app hasCompletedOnboarding -bool true
xcrun simctl spawn booted defaults write com.dally.app seedPreviewData -bool true
xcrun simctl launch booted com.dally.app
```

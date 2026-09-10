# d·ally

Local-first iPhone app for **time-of-day daily habits** — not calendar-date todos.

Set a clock time (or a finish-by window). Mark it **kept** each day. The calendar shows your consistency as color.

**Tagline:** Daily consistency.

## Requirements

- Xcode 16+ (Xcode 26 recommended)
- iOS 18.0+
- Apple Developer team for device runs / notifications

## Open & run

1. Open `DAlly.xcodeproj`.
2. Select the **DAlly** scheme and a simulator or iPhone.
3. Set **Signing Team** on the DAlly target if prompted.
4. Run (⌘R).

Device is better than Simulator for real local notifications.

## First launch

1. Welcome → **Start**.
2. Day tab → **+** (or empty-state CTA) to add a reminder.
3. Choose **Specific time** or **Anytime before**.
4. Allow alerts when prompted so on-time / follow-up / Sunday week-review pings can fire.

## What’s in the app

| Area | Behavior |
|---|---|
| **Day** | Today’s rhythm: kept, past due, next, later. Swipe or chevrons for other days. Past days can still be marked kept/skipped. |
| **Calendar** | Kept = color dots (all of them, multi-line). Skipped-only day = hollow ring. |
| **Settings** | Theme, alerts master switch, quiet hours, default “if still open” mode. |
| **Sunday** | In-app **Review your week** banner + 12:00 local notification → opens Calendar. |

## Notifications

| Kind | Body |
|---|---|
| On-time (fixed) | `It's time to do {name}.` |
| On-time (flexible) | `Due by {time}.` |
| Follow-up / overdue | `This one's still open for today.` |
| Sunday week review | Title: `Your week at d·ally` · Body: `Consistency is a pattern. Glance at the calendar.` |

Master **Alerts** toggle and iOS permission both required. Quiet hours defer overdue follow-ups (on-time still fires).

## Deep links

Scheme: `dally`

- `dally://day?date=yyyy-MM-dd&taskId=<UUID>&prompt=1` — day + optional completion sheet  
- `dally://calendar` — Calendar tab (current month)  
- `dally://settings` — Settings  
- `dally://editor` — new reminder editor  

## Project layout

```
DAlly/                 App sources (SwiftUI + SwiftData)
DAlly.xcodeproj/       Xcode project
DAllyTests/            Unit tests
icons/                 Logo / icon explorations
screenshots/           Capture references
D-ALLY_BUILD_PLAN.md   Original build spec
RUN.md                 Short run checklist
```

Bundle ID: `com.dally.app` · Display name: **d·ally**

## Data

- SwiftData on-device only (no account / iCloud in v1).
- Day logs are **per day**: keeping a task yesterday does not keep it today.

## Tests

```bash
xcodebuild -project DAlly.xcodeproj -scheme DAlly \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

## Optional Simulator seed

```bash
xcrun simctl spawn booted defaults write com.dally.app hasCompletedOnboarding -bool true
xcrun simctl spawn booted defaults write com.dally.app seedPreviewData -bool true
xcrun simctl launch booted com.dally.app
```

## License

Private / unpublished unless you add a license.

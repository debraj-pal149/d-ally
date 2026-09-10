# d-ally — Complete Build Plan (Execution Spec)

> **Purpose of this document:** A second agent must be able to build the entire iOS app from this file alone — no improvisation required for product decisions, copy, colors, file names, data models, notification logic, UI layouts, edge cases, or Xcode project setup.
>
> **Do not write speculative features.** Implement only what is specified here.
>
> **Do not leave TODOs** for product decisions. If something is listed here, ship it.

---

## 0. One-Sentence Product Definition

**d-ally** (Daily Ally) is a local-first iPhone app for **time-of-day daily reminders** — not calendar-date todos. You create a repeating daily task with a compulsory clock time (exact time **or** a flexible “anytime before” window); the app shows today’s rhythm (kept / skipped / past due / next hour / later), lets you **skip** a day without counting it as kept, nags once (or hourly) if still open — respecting global **Quiet hours** on the device clock — and paints a month calendar with each task’s vibrant color so you can see which days you kept the promise.

---

## 1. Research Summary (Locked Decisions)

### 1.1 Stack (locked)

| Decision | Choice | Why |
|---|---|---|
| UI | SwiftUI | Native, fast to ship, Xcode 26 ready |
| Persistence | SwiftData | Local-first, `@Query`, iOS 17+, zero backend |
| Notifications | `UserNotifications` + `UNUserNotificationCenterDelegate` | Local only; no push server |
| Min deployment | **iOS 18.0** | Broad enough; aligns with modern SwiftUI; user’s machine has Xcode 26.5 |
| Preferred target | iOS 26 APIs where available (`glassEffect`) with Material fallback | User wants glass/sleek; Xcode 26 available |
| Architecture | MV + Services (light MVVM only where needed) | Keep simple; views + `@Query` + service objects |
| Sync / accounts | **None** | Local only for v1 |
| Widgets / Watch / Live Activities | **None** in v1 | Out of scope |
| CloudKit / HealthKit | **None** in v1 | Avoid permission complexity |
| Location / geofencing | **None** — ever for Quiet hours | Quiet hours use **device local clock only** (see §5A.2). No Core Location. |

### 1.2 Critical iOS constraints (must implement around these)

1. **64 pending local notification limit** — Never schedule unbounded future notifications. Use a **rolling 7-day window** of *non-repeating* `UNCalendarNotificationTrigger` requests. Reschedule on: app launch, scene become active, task create/edit/delete/complete/**skip**/end-date change, notification setting change, Quiet hours change.
2. **Do not use `repeats: true` daily triggers for overdue/hourly nags** — Too hard to cancel per-day after completion. Primary reminder *may* use repeating calendar trigger **OR** also be part of the 7-day window — **prefer everything in the 7-day window** for consistency and easy cancel-on-complete.
3. **Notification permission must be contextual** — Never request on cold launch. Request after Welcome → when user enables reminders OR when they save their first task (with a priming sheet first). App must work fully without notifications (manual check-off still works).
4. **Deep link from notification tap** — Put `url` in `userInfo`, open via custom URL scheme `dally://`, handle with `.onOpenURL`, land on Day View for that day + present completion prompt for that task.
5. **Foreground notifications** — Delegate must return `[.banner, .sound, .list]` so alerts show while app is open.
6. **Midnight / day boundary** — Day View must refresh when calendar day changes while app is open (`TimelineView` or scene-phase + timer at midnight).
7. **Time zone** — Store time-of-day as **hour + minute in local timezone components** (not absolute UTC timestamp for the schedule). Completions keyed by **local calendar date** (`yyyy-MM-dd`). Reminder fires at local wall-clock time.
8. **DST** — Local `DateComponents` hour/minute naturally follow DST; document this; no special DST UI.

### 1.3 What this app is / is not (copy must reinforce)

| Is | Is not |
|---|---|
| Daily, same-time-every-day reminders | A calendar events app |
| Accountability for habits/meds/gym/runs | A project task manager |
| One day-status per task per local day (kept / skipped / open) | Multi-occurrence per day (v1) |
| Exact-time **or** flexible “anytime before” windows | All-day undated todos |
| Color-coded month history (kept ≠ skipped) | Analytics dashboard |

---

## 2. Brand, Naming, Personality

### 2.1 Names

| Item | Value |
|---|---|
| Display name | **d-ally** |
| Full spoken name | Daily Ally |
| Bundle ID | `com.dally.app` (agent may use `com.<developer>.dally` if signing requires; keep `dally` segment) |
| Xcode project / scheme | `DAlly` |
| URL scheme | `dally` |
| Tagline | **Your daily ally.** |
| Short description | Daily reminders at a time of day — done, next, later. |
| Personality | Warm, clear, accountable, slightly firm — like a reliable friend who notices when you skip, not a corporate productivity coach. Short sentences. No emoji spam. No “crush your goals” hustle speak. |

### 2.2 Voice rules for all UI copy

- Prefer “today”, “this hour”, “still open”, “kept”, “skipped”, “missed”.
- Avoid: “tasks inbox”, “productivity”, “streaks” (streaks are not a v1 feature — do not invent).
- Completion language: **“Mark done”** / **“Done”** / **“Kept”**.
- Skip language: **“Skip today”** / **“Skipped”** — intentional off day; **never** shown as kept on the calendar.
- Missed language: **“Still open”** or **“Past due”** (after the effective due instant until kept or skipped).
- Flexible window language: **“Anytime before {time}”** / **“Due by {time}”**.
- Notification titles: task name. Bodies: human, specific (see §12).

---

## 3. Design System

### 3.1 Theme modes

App supports three appearance modes stored in `AppSettings.appearanceMode`:

| Mode | Behavior |
|---|---|
| `system` (default) | Follows `UITraitCollection` / SwiftUI `@Environment(\.colorScheme)` |
| `dark` | Force dark |
| `light` | Force light |

Apply via `.preferredColorScheme(...)` on root view based on setting.

### 3.2 Neutral surfaces (locked hex)

**Dark mode**

| Token | Hex | Use |
|---|---|---|
| `bgPrimary` | `#121214` | App background |
| `bgElevated` | `#1C1C1E` | Sheets, cards (subtle elevation — prefer glass over solid cards) |
| `bgGrouped` | `#2C2C2E` | Grouped rows when solid needed |
| `separator` | `#3A3A3C` | Hairlines |
| `textPrimary` | `#F2F2F7` | Primary text |
| `textSecondary` | `#A1A1A6` | Secondary |
| `textTertiary` | `#6C6C70` | Tertiary / placeholders |
| `danger` | `#FF453A` | Destructive actions |
| `success` | `#30D158` | Generic success (prefer task color when marking done) |

**Light mode**

| Token | Hex | Use |
|---|---|---|
| `bgPrimary` | `#F2F2F7` | App background |
| `bgElevated` | `#FFFFFF` | Sheets |
| `bgGrouped` | `#FFFFFF` | Rows |
| `separator` | `#C6C6C8` | Hairlines |
| `textPrimary` | `#1C1C1E` | Primary text |
| `textSecondary` | `#6C6C70` | Secondary |
| `textTertiary` | `#8E8E93` | Tertiary |
| `danger` | `#FF3B30` | Destructive |
| `success` | `#34C759` | Success |

Implement tokens in `Theme/AppColors.swift` as static helpers that take `ColorScheme`.

### 3.3 Glass / material rules

**Goal:** Classy, iPhone-native glass — not “purple neon blur everywhere.”

1. **Background:** Soft radial gradient over `bgPrimary` — dark: charcoal → slightly lifted gray near top; light: cool gray → white. Optional very subtle noise (skip if complex; gradient alone is fine).
2. **Floating chrome** (tab bar replacement, day header, FAB, sheets):  
   - If `#available(iOS 26, *)`: `.glassEffect(.regular, in: RoundedRectangle(...))` inside `GlassEffectContainer` for grouped controls.  
   - Else: `.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))`.
3. **Task rows are NOT full glass cards stacked on glass.** Use:
   - Left **4pt color bar** or **12pt color disc**
   - Semi-transparent fill: dark `Color.white.opacity(0.06)`, light `Color.black.opacity(0.04)`
   - Continuous corner radius **16**
   - Opacity of *entire row content* varies by section (see §8.4)
4. **Never glass-on-glass** for nested content. Glass = navigation / floating layer only.
5. Respect Reduce Transparency: fall back to solid `bgElevated`.

### 3.4 Typography

Use SF Pro (system) with deliberate hierarchy — expressive *weight*, not custom fonts (custom fonts complicate shipping; personality comes from copy + color + motion).

| Role | Style |
|---|---|
| Brand mark | `.largeTitle.weight(.bold)` or custom large rounded |
| Screen title | `.title2.weight(.semibold)` |
| Section header | `.subheadline.weight(.semibold)`, `textSecondary`, uppercase tracking optional (`kerning: 0.6`) |
| Task name | `.body.weight(.semibold)` |
| Time | `.subheadline.weight(.medium).monospacedDigit()` |
| Notes preview | `.footnote`, `textSecondary`, 1–2 lines |
| Empty state | `.title3.weight(.semibold)` + `.subheadline` secondary |

### 3.5 Motion (ship 3 intentional motions)

1. **Day swipe:** Horizontal paging between days with spring (`response: 0.35, dampingFraction: 0.86`).
2. **Mark done:** Color disc → checkmark morph + brief haptic `.success` + row animates into Completed section.
3. **Add task sheet:** Present as `.sheet` with detents `[.large]`; cancel/save; glass toolbar.

Optional polish: subtle fade of Upcoming → Next Hour as time passes (`TimelineView(.periodic(every: 60))`).

### 3.6 Haptics

| Event | Haptic |
|---|---|
| Mark done | `UINotificationFeedbackGenerator().notificationOccurred(.success)` |
| Skip today | `.soft` impact (not success — quieter than kept) |
| Undo done / undo skip | `.light` impact |
| Delete task | `.warning` notification |
| Day change via button | `.soft` impact |

### 3.7 Task color palette (locked — 12 vibrant, distinct)

Auto-assign the first unused color when creating a task. User can change color in editor via horizontal swatches. If all 12 used, allow reuse starting from index 0 (still prefer unused first).

| Index | Name | Hex | Example use |
|---|---|---|---|
| 0 | Ember | `#FF6B4A` | Don’t smoke |
| 1 | Amber | `#FFB020` | Vitamins |
| 2 | Citron | `#D4E157` | Stretch |
| 3 | Mint | `#2EE6A6` | Hydration |
| 4 | Aqua | `#2CD4FF` | Run |
| 5 | Sky | `#4C8DFF` | Meds AM |
| 6 | Indigo | `#7B61FF` | Journal |
| 7 | Orchid | `#E85DFF` | Meditation |
| 8 | Rose | `#FF4D6D` | Meds PM |
| 9 | Coral | `#FF7A59` | Gym |
| 10 | Teal | `#00C2A8` | Walk |
| 11 | Lime | `#A3E635` | Reading |

**Rules:**

- Store as hex string on `DailyTask.colorHex`.
- Calendar dots use exact task color at **full** saturation for completed days.
- Incomplete past days: no dot for that task (absence = didn’t keep).
- Today incomplete: no fill yet (or hollow ring — see calendar §9).
- Text on colored chips: use white or near-black via luminance check helper `Color.contrastingForeground()`.

Implement `Theme/TaskColorPalette.swift`.

---

## 4. Xcode Project Setup (exact)

### 4.1 Create project

1. Open Xcode → New Project → **App**
2. Product Name: `DAlly`
3. Team: user’s team
4. Organization Identifier: as needed
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Storage: **None** in wizard (we add SwiftData manually) OR SwiftData if checkbox exists — either fine
8. Include Tests: Yes (unit tests for occurrence/notification ID helpers at minimum)
9. Save into repo root `/Users/debrajpal/Documents/Github/d-ally` (or create `DAlly/` subfolder — **prefer all sources under `DAlly/`** with project at repo root)

### 4.2 Target settings

| Setting | Value |
|---|---|
| Display Name | d-ally |
| Bundle Identifier | `com.dally.app` (adjust if needed) |
| Version | `1.0.0` |
| Build | `1` |
| Deployment | iOS 18.0 |
| Device | iPhone only (iPad optional as iPhone-scaled OK) |
| Orientations | Portrait only |
| App Icon | Generate placeholder asset: dark gray bg + “D” monogram in mint/aqua — agent must add `Assets.xcassets/AppIcon` (can use single color + SF Symbol export if needed; document that user should replace) |

### 4.3 Capabilities / Info

1. **URL Types:** Scheme `dally`, role Editor, identifier `com.dally.app.url`
2. **Background Modes:** Do **not** enable remote notifications. Optionally enable **Background App Refresh** only if implementing `BGAppRefreshTask` for reschedule (recommended — see §11.7).
3. **Privacy:** No camera/mic/contacts/health. No usage strings needed for local notifications.
4. `Info.plist` / target Info:
   - `CFBundleDisplayName` = `d-ally`
   - `UILaunchScreen` empty/default (SwiftUI)
   - `BGTaskSchedulerPermittedIdentifiers` = `com.dally.app.refresh` if BG refresh used

### 4.4 Folder structure (exact file names)

```
DAlly/
  DAllyApp.swift
  AppDelegate.swift
  ContentRootView.swift
  Info.plist                    (if not auto-generated — keep minimal)
  Assets.xcassets/
    AppIcon.appiconset/
    AccentColor.colorset/       (set to #2CD4FF Aqua)
  Models/
    DailyTask.swift
    TaskDayLog.swift              // replaces old TaskCompletion naming — see §5.5
    PriorityLevel.swift
    OverdueReminderMode.swift
    AppearanceMode.swift
    ScheduleKind.swift            // fixedTime | flexibleUntil
    DayLogStatus.swift            // kept | skipped
    QuietHours.swift              // helper struct (not SwiftData)
  Services/
    TaskOccurrenceService.swift
    DayLogService.swift
    NotificationSchedulingService.swift
    NotificationPermissionService.swift
    QuietHoursService.swift
    DeepLinkRouter.swift
    ColorAssignmentService.swift
    DayBoundaryObserver.swift
    DaySectioningService.swift
  Theme/
    AppColors.swift
    TaskColorPalette.swift
    GlassModifier.swift
    Typography.swift
  Navigation/
    AppTab.swift
    MainTabView.swift
  Features/
    Onboarding/
      WelcomeView.swift
      NotificationPrimingView.swift
    Day/
      DayView.swift
      DayPagerView.swift
      DayHeaderView.swift
      DaySectionHeader.swift
      TaskRowView.swift
      EmptyDayView.swift
      CompletionPromptSheet.swift
    Calendar/
      MonthCalendarView.swift
      MonthGridView.swift
      DayCellView.swift
      DayDetailSheet.swift
    TaskEditor/
      TaskEditorView.swift
      TimeOfDayPicker.swift
      ScheduleKindPicker.swift
      FlexibleWindowFields.swift
      PriorityPicker.swift
      ColorSwatchPicker.swift
      DurationPicker.swift
      OverdueReminderPicker.swift
      NotesEditorField.swift
    Settings/
      SettingsView.swift
      QuietHoursSettingsView.swift
    Shared/
      ConfirmDoneButton.swift
      PriorityBadge.swift
      TaskColorDot.swift
      SectionOpacity.swift
      DayStatusChip.swift
  Utilities/
    Date+LocalDay.swift
    DateComponents+TimeOfDay.swift
    String+HexColor.swift
    Haptics.swift
    Constants.swift
  Preview/
    PreviewSampleData.swift
```

Agent may merge tiny helpers but **must not invent alternate product architecture**.

---

## 5. Data Model (SwiftData) — exact schemas

### 5.1 `PriorityLevel` (`Models/PriorityLevel.swift`)

```swift
enum PriorityLevel: String, Codable, CaseIterable, Identifiable {
  case low, normal, high
  var id: String { rawValue }
  var displayName: String {
    switch self {
    case .low: "Low"
    case .normal: "Normal"
    case .high: "High"
    }
  }
  var sortRank: Int {
    switch self {
    case .high: 0
    case .normal: 1
    case .low: 2
    }
  }
}
```

### 5.2 `OverdueReminderMode` (`Models/OverdueReminderMode.swift`)

```swift
enum OverdueReminderMode: String, Codable, CaseIterable, Identifiable {
  case onceAfter10Minutes   // DEFAULT
  case everyHourUntilDone
  case off
}
```

Display names in UI:

| Case | Label | Helper text |
|---|---|---|
| `onceAfter10Minutes` | Once, 10 minutes after | If still open after the due moment, remind once. Quiet hours may delay this (see §5A.2). |
| `everyHourUntilDone` | Every hour until done | Keep nudging hourly until kept or skipped. Quiet hours suppress these overnight. |
| `off` | No follow-up | Only the reminder at the scheduled nudge/time. |

### 5.2b `ScheduleKind` (`Models/ScheduleKind.swift`)

```swift
enum ScheduleKind: String, Codable, CaseIterable, Identifiable {
  case fixedTime      // DEFAULT — remind / due at exact hour:minute
  case flexibleUntil  // open all day until a deadline clock time
}
```

| Case | Label in editor | Helper |
|---|---|---|
| `fixedTime` | At a specific time | Reminds at that time. Past due after that minute if still open. |
| `flexibleUntil` | Anytime before | Mark done any time before this clock time. Better for gym, runs, “sometime today.” |

### 5.2c `DayLogStatus` (`Models/DayLogStatus.swift`)

```swift
enum DayLogStatus: String, Codable, CaseIterable, Identifiable {
  case kept
  case skipped
}
```

- **kept** — user completed / honored the reminder that day (calendar gets vibrant color dot).
- **skipped** — intentional off day (calendar does **not** get a kept color dot; optional hollow mark — §9).
- **No row** — still open (or missed if past due instant). Missed is **derived**, never stored.

### 5.3 `AppearanceMode`

```swift
enum AppearanceMode: String, Codable, CaseIterable {
  case system, light, dark
}
```

### 5.4 `DailyTask` (`Models/DailyTask.swift`)

`@Model` class with fields:

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | Default `UUID()` |
| `name` | `String` | Required, trim whitespace; min 1 char |
| `notes` | `String` | Default `""` |
| `scheduleKind` | `String` | rawValue of `ScheduleKind`; default `fixedTime` |
| `hour` | `Int` | 0…23. For `fixedTime`: due/remind time. For `flexibleUntil`: **first reminder / nudge** time |
| `minute` | `Int` | 0…59. Paired with `hour` |
| `windowEndHour` | `Int` | 0…23. Used only when `flexibleUntil`; **complete-by** deadline hour. Ignored for `fixedTime` (store 0). |
| `windowEndMinute` | `Int` | 0…59. Used only when `flexibleUntil`. Ignored for `fixedTime` (store 0). |
| `priority` | `String` | Store rawValue of `PriorityLevel` |
| `colorHex` | `String` | e.g. `"#FF6B4A"` |
| `startDate` | `Date` | Start of local day when task becomes active; default = today start |
| `endDate` | `Date?` | `nil` = until stopped; if set, inclusive last local day |
| `isStopped` | `Bool` | User stopped early; default `false` |
| `overdueReminderMode` | `String` | rawValue of `OverdueReminderMode`; default `onceAfter10Minutes` |
| `createdAt` | `Date` | |
| `updatedAt` | `Date` | |
| `sortOrder` | `Int` | Default 0; primarily sort by effective due/nudge time then priority |
| `notificationsEnabled` | `Bool` | Per-task mute; default `true` |

**Computed helpers** (extension, not stored):

- `schedule: ScheduleKind`
- `priorityLevel: PriorityLevel`
- `overdueMode: OverdueReminderMode`
- `nudgeDate(on day:) -> Date` — day + `hour`:`minute` (when the primary reminder fires)
- `dueDate(on day:) -> Date` — for `fixedTime` = nudgeDate; for `flexibleUntil` = day + `windowEndHour`:`windowEndMinute`
- `isActive(on day: Date) -> Bool` — not stopped, day >= start, day <= end (if set)
- `displayTimeLabel` — `fixedTime`: `h:mm a`; `flexibleUntil`: `Anytime before h:mm a`

**Validation (TaskEditor):**

- Name non-empty after trim
- Time always set — no all-day / date-only
- If `flexibleUntil`: both nudge time and window-end required; **nudge must be ≤ window end** on the same day; if equal, treat as fixed-time equivalent (allowed)
- Default create `fixedTime` at **09:00**
- Default create when user switches to `flexibleUntil`: window end **22:00**, nudge **18:00** (or `windowEnd - 2 hours`, clamped ≥ 05:00)
- If end date set, must be >= start date

### 5.5 `TaskDayLog` (`Models/TaskDayLog.swift`) — replaces “TaskCompletion”

One row per task per local day **only when** the user has resolved that day as kept or skipped.

| Property | Type | Notes |
|---|---|---|
| `id` | `UUID` | |
| `taskId` | `UUID` | FK to `DailyTask.id` |
| `dayKey` | `String` | Local day `yyyy-MM-dd` |
| `status` | `String` | rawValue of `DayLogStatus`: `kept` or `skipped` |
| `resolvedAt` | `Date` | Wall clock when marked kept/skipped |

**Uniqueness:** At most one log per (`taskId`, `dayKey`). Upsert on status change; delete row = back to open.

**Semantics:**

| Status | Means | Calendar | Notifications that day |
|---|---|---|---|
| (no row) | Open | No kept dot | Scheduled normally |
| `kept` | Honored | **Filled color dot** | Cancel all for that day |
| `skipped` | Intentional off | **No filled kept dot**; optional hollow ring (§9) | Cancel all for that day |

### 5.6 App settings (`@AppStorage` in `Constants.swift`)

| Key | Type | Default |
|---|---|---|
| `hasCompletedOnboarding` | Bool | false |
| `appearanceMode` | String | `system` |
| `notificationsMasterEnabled` | Bool | true |
| `hasRequestedNotificationPermission` | Bool | false |
| `defaultOverdueMode` | String | `onceAfter10Minutes` |
| `quietHoursEnabled` | Bool | **true** |
| `quietHoursStartHour` | Int | **22** |
| `quietHoursStartMinute` | Int | **0** |
| `quietHoursEndHour` | Int | **7** |
| `quietHoursEndMinute` | Int | **0** |

SwiftData models: only `DailyTask` + `TaskDayLog`.

### 5.7 ModelContainer bootstrap (`DAllyApp.swift`)

```swift
.modelContainer(for: [DailyTask.self, TaskDayLog.self])
```

Preview: in-memory container with `PreviewSampleData`.

---

## 5A. Feature addendum — Skip / Quiet hours / Flexible window (normative)

> These three features are **in scope for v1**. Full behavior is here and referenced from Day View, Editor, Calendar, Notifications, Settings.

### 5A.1 Skip today

**Why:** Real life has off days. Skipping must not look like success on the calendar.

**User actions that set `skipped`:**

1. Swipe leading on row (after Stop, or instead): **Skip today**
2. Checkbox long-press menu / context menu: **Skip today** | **Mark done**
3. Completion prompt sheet tertiary: **Skip today**
4. Notification category action `dally.action.skip` title **Skip today**

**Rules:**

- Allowed for **today** and **past** days only (same as kept). Not for future days.
- Skip and kept are mutually exclusive; setting one overwrites the other.
- Undo: swipe / checkbox menu **Clear** → delete `TaskDayLog` → open again; reschedule notifs if still relevant.
- Past day incomplete after due → shown as **Missed** (derived). User can still convert Missed → Kept or Skipped.
- Skipped rows live in section **Skipped** (opacity 0.85), with chip label `Skipped`, muted checkstyle icon `forward.fill` or `moon.zzz` — use **`arrow.forward.circle`** labeled Skipped (not a green check).

**Copy:**

- Confirm not required for skip (low friction); optional subtle toast isn’t needed — section move is enough.
- Accessibility: `Skip {name} today`

### 5A.2 Quiet hours (device clock only — no location)

**Why:** Hourly nags at 3am are hostile. Night is defined by the user’s configured window on the **phone’s local clock**.

**Do NOT use location, sunrise APIs, or WeatherKit.** If the user travels, the phone clock/timezone already moves with them — that is enough.

**Defaults:** 22:00 → 07:00, enabled on.

**Cross-midnight:** If start > end (e.g. 22:00–07:00), quiet spans midnight. If start < end (e.g. 01:00–05:00), quiet is that same-night slice. If start == end, treat as **disabled** (invalid) and force toggle off or require 15+ minute span.

**`QuietHoursService.isInQuietHours(at date: Date) -> Bool`** using `@AppStorage` values + `Calendar.current`.

**What Quiet hours suppress:**

| Notification kind | During quiet hours |
|---|---|
| Primary / on-time / flexible nudge (`ontime`) | **Still fires** — user chose that time (including a 22:30 med). |
| Overdue once (`overdueOnce`) | **Defer** fire to quiet-hours **end** (same local day if end is later tonight; if quiet ends next morning, fire at end next morning — still tied to original task/dayKey). If deferred time is past the point where task is kept/skipped, cancel. |
| Hourly overdue (`overdueHourly`) | **Do not schedule** any hourly fire whose timestamp falls inside quiet hours. Resume hourlies after quiet ends until end of that task’s local day or resolution. |

**Settings UI (`QuietHoursSettingsView` / section in Settings):**

- Toggle: **Quiet hours**
- Start time picker
- End time picker
- Helper: `Uses your iPhone’s clock — no location needed. Follow-up nags wait until morning; timed reminders still sound at the time you set.`
- Footer example: `Default 10:00 PM – 7:00 AM.`

**Reschedule** whenever quiet hours settings change.

### 5A.3 Flexible window (“anytime before”)

**Why:** Gym / run / “don’t smoke by end of day” shouldn’t fail because you weren’t free at 18:00 exactly.

**Editor UX (`ScheduleKindPicker` + `FlexibleWindowFields`):**

1. Segmented: **Specific time** | **Anytime before**
2. If Specific: one time picker **Remind me at** (existing).
3. If Anytime before:
   - **Complete by** → binds `windowEndHour/Minute` ( compulsory )
   - **First remind me at** → binds `hour/minute` (compulsory, ≤ complete by)
   - Helper: `Open all day until this time. Mark done whenever you finish. Past due only after the complete-by time.`

**Effective due instant** for past-due / missed / overdue follow-ups = `dueDate(on: day)` (§5.4).

**Primary notification** fires at `nudgeDate` (first remind), not at window end.

**Overdue +10m / hourly** anchor from `dueDate` (window end), not from nudge — so a gym “anytime before 22:00” with nudge at 18:00 gets overdue follow-ups only after 22:00 if still open.

**Day View labeling:**

- Time trailing label: `by 10:00 PM` (flexible) vs `6:00 PM` (fixed)
- Status before due: `Open · anytime before …` in footnote if space

**Sectioning impact:** see §6.4 (updated).
---

## 6. Domain Logic (exact algorithms)

### 6.1 Local day key

`Date+LocalDay.swift`:

- `startOfLocalDay`
- `localDayKey` → `yyyy-MM-dd` using `Calendar.current`
- `date(fromDayKey:)`
- `isSameLocalDay(_:_:)`

### 6.2 Occurrence on a given day

`TaskOccurrenceService.tasks(for day: Date, allTasks: [DailyTask]) -> [DailyTask]`:

1. Filter `task.isActive(on: day)`
2. Sort by `(hour, minute)` ascending
3. Tie-break: `priorityLevel.sortRank`, then `name`

### 6.3 Day log state (`CompletionService.swift` — rename file OK to `DayLogService.swift`)

**Prefer filename `DayLogService.swift`.** Keep folder list conceptually as CompletionService → agent should use `DayLogService.swift`.

- `log(for taskId:day:) -> TaskDayLog?`
- `status(taskId:day:) -> DayLogStatus?` // nil = open
- `markKept(taskId:day:at:)` — upsert status `kept`; cancel notifs that day; reschedule
- `markSkipped(taskId:day:at:)` — upsert status `skipped`; cancel notifs; reschedule
- `clearLog(taskId:day:)` — delete row; reschedule if needed
- `keptLogs(for day:)` / `skippedLogs(for day:)`
- `keptLogsGroupedByDay(in month:)` for calendar dots

### 6.4 Day View sectioning (critical UX)

For selected `day` and `now = Date()`:

**Effective due** = `task.dueDate(on: day)`  
**Nudge** = `task.nudgeDate(on: day)`

**Today** — partition into sections (omit empty):

| Section ID | Title | Inclusion | Row opacity |
|---|---|---|---|
| `kept` | Kept today | status == kept | **1.0** |
| `skipped` | Skipped | status == skipped | **0.85** |
| `pastDue` | Past due | open && `dueDate < now` | **0.95** + “Past due” label |
| `nextHour` | Next hour | open && due >= now && (due within 1h **OR** (fixed/flexible nudge within next 1h and due still ahead)) | **0.72** |
| `later` | Later today | open && not in nextHour && due >= now | **0.42** |

**Next-hour rule detail:**

- Include if `dueDate` is in `(now, now+1h]`
- Also include if `nudgeDate` is in `(now, now+1h]` and task still open and not yet past due (so flexible tasks light up when their first reminder approaches, even if complete-by is late evening)

**Ordering:**

- `kept` / `skipped`: by dueDate ascending
- `pastDue`: dueDate ascending (oldest first)
- `nextHour` / `later`: by dueDate ascending; tie-break nudgeDate, then name

**Visual contrast:** Kept brightest with strong color; Skipped readable but not celebratory (no green check); Next hour medium; Later dimmest; Past due full attention + warning tint on status label only.

### 6.5 Past & future day sectioning

**Past day:**

| Section | Title | Rule |
|---|---|---|
| Kept | Kept | status == kept |
| Skipped | Skipped | status == skipped |
| Missed | Missed | open (no log) — entire past day incomplete |

Opacity: Kept 1.0, Skipped 0.85, Missed 0.55.

**Future day:**

| Section | Title | Rule |
|---|---|---|
| Scheduled | Scheduled | all active tasks |

Opacity 0.55. **Cannot** mark kept or skipped on future days. Disabled affordance: “You can resolve this on that day.”

### 6.6 Stopping / end date

- **Stop task:** set `isStopped = true`, `updatedAt = now`, cancel all pending notifications for task, keep historical day logs.
- **End date:** inclusive; after that day, task disappears going forward.
- **Delete task:** delete model + all `TaskDayLog`s + cancel notifications. Confirm destructive alert.

---

## 7. App Navigation & Screen Map

### 7.1 Root flow

```
DAllyApp
 └─ ContentRootView
      ├─ if !hasCompletedOnboarding → WelcomeView (full screen)
      └─ else → MainTabView
           ├─ Tab Day → DayPagerView
           ├─ Tab Calendar → MonthCalendarView
           └─ Tab Settings → SettingsView
```

Use custom tab bar with glass styling OR `TabView` with SF Symbols:

| Tab | Title | Symbol |
|---|---|---|
| Day | Today | `sun.max` / when viewing other day still label **Day** with `checklist` |
| Calendar | Calendar | `calendar` |
| Settings | Settings | `gearshape` |

**Default tab:** Day.

### 7.2 Global overlays

- Sheets: TaskEditor, CompletionPrompt, DayDetail, NotificationPriming
- Deep link handling on `ContentRootView`

---

## 8. Screen-by-Screen Spec (UI + copy + behavior)

### 8.1 Welcome / Onboarding (`WelcomeView.swift`)

**Shown once** until Continue.

**Layout (one composition, brand-first):**

1. Background: dark charcoal gradient (ignore system during onboarding — always dark branded welcome for personality; after exit, follow settings).
2. Brand: **d-ally** large, near top-center.
3. Tagline under brand: **Your daily ally.**
4. One short supporting paragraph (not a feature grid):

> d-ally is for the things you do every day at a time of day — medicine, gym, a run, not smoking. Set a time or a window. Mark it kept — or skip a day without faking a win. See your month in color.

5. Three quiet lines (not cards — simple text rows with color dots):

- **A time, every day** — Exact clock time, or anytime before a deadline. Not a calendar event.
- **Done, next, later** — Today shows kept, skipped, what’s soon, and what’s ahead.
- **Your month in color** — Vibrant colors mark days you kept. Skips don’t paint the calendar.

6. Primary CTA button (glass/capsule, aqua tint): **Begin**
7. Secondary text button: **I already know — enter** (same as Begin)

**On Begin:**

- Set `hasCompletedOnboarding = true`
- Navigate to Day view (empty state)
- Do **not** request notifications yet

**Accessibility:** Dynamic Type; VoiceOver reads brand then paragraph.

### 8.2 Empty Day View (`EmptyDayView.swift`)

When today has zero active tasks:

**Headline:** Nothing on your day yet.  
**Body:** Add a daily reminder for a specific time — like taking a pill at 9:00, or logging a run at 18:30.  
**CTA:** **Add daily reminder** → opens TaskEditor create mode.

Floating **+** button always available on Day tab (trailing bottom, glass circle, aqua).

### 8.3 Day Header (`DayHeaderView.swift`)

| Element | Spec |
|---|---|
| Title | If today: **Today**; else: `EEEE, MMM d` (e.g. Wednesday, Sep 3) |
| Subtitle | `MMMM yyyy` smaller, secondary |
| Leading chevron | Previous day |
| Trailing chevron | Next day |
| Tap title | Jump-to-today button appears if not today: pill **Jump to today** |

Also support **horizontal swipe** on content (`DayPagerView`) to change days.

Range: allow browsing from `startDate` earliest task to +2 years ahead freely; no hard block.

### 8.4 Task Row (`TaskRowView.swift`)

Structure:

```
[Color disc 12pt] [Name + optional priority]     [Time / by-time]
                  [Notes 1 line if any]
                  [Status: Past due | Skipped | Kept | Open…]
                                        [Checkbox / status control]
```

- Trailing time: fixed → `h:mm a`; flexible → `by h:mm a`
- Checkbox: circle outline in task color; **filled check** when kept; **forward/skip glyph** when skipped; empty when open.
- Tap checkbox when open → **Mark kept** (today/past only).
- Long-press / context menu on checkbox or row: **Mark done**, **Skip today**, **Clear** (if resolved).
- Tap row body → `TaskEditorView` edit mode.
- Swipe trailing: **Done** (if open) / **Clear** (if kept or skipped).
- Swipe leading: **Skip** (if open) | **Stop** (confirm) if active.

Section opacity via `SectionOpacity`.

Priority badge: show `HIGH` only when high.

### 8.5 Day sections copy

Exact section titles:

- `Kept today` / `Kept`
- `Skipped`
- `Past due`
- `Next hour`
- `Later today`
- `Missed` (past)
- `Scheduled` (future)

### 8.6 Completion Prompt Sheet (`CompletionPromptSheet.swift`)

Triggered by notification default tap (deep link) and optional in-app.

**Content:**

- Color disc + task name
- Fixed: `Scheduled for {h:mm a}` / Flexible: `Anytime before {h:mm a} · first remind {h:mm a}`
- Notes if present
- Primary: **Yes — mark done**
- Secondary: **Not yet**
- Tertiary: **Skip today**
- Quaternary (if past due): **Keep reminding me** → schedule one more follow-up in 1 hour if allowed (respect Quiet hours)

On Yes / Skip: write log, dismiss, haptic, stay on Day view.

### 8.7 Add / Edit Task (`TaskEditorView.swift`)

**Presentation:** modal sheet, navigation title:

- Create: **New daily reminder**
- Edit: **Edit reminder**

**Fields in order:**

1. **Name** — TextField, placeholder: `e.g. Take evening pill`  
   Helper: `What should d-ally remind you about every day?`

2. **Schedule** — `ScheduleKindPicker`: **Specific time** | **Anytime before**  
   Helper: `Daily reminders always use a time of day — never all-day.`

3. **Time fields**
   - If Specific: **Remind me at** — hour/minute (default 09:00)
   - If Anytime before (`FlexibleWindowFields`):
     - **Complete by** — default 22:00
     - **First remind me at** — default 18:00; must be ≤ complete by  
     Helper: `Mark done any time before the complete-by time. Past due only after that.`

4. **Color** — `ColorSwatchPicker`  
   Helper: `This color marks days you kept on your calendar — not skips.`

5. **Priority** — Low / Normal / High. Default Normal.

6. **Duration** — Until I stop | Until a date (unchanged).

7. **If still open** — `OverdueReminderPicker`  
   Helper notes Quiet hours may delay follow-ups.

8. **Notes** — optional, max 2000 chars.

9. **Notifications for this reminder** — Toggle, default on.

**Toolbar:**

- Leading: **Cancel**
- Trailing: **Save** (disabled if name empty)

**On first Save ever (create) if notification permission not determined:**

1. Dismiss editor after save OR present priming first — **order:** Save task to DB first, then present `NotificationPrimingView` sheet so data isn’t lost if they deny.

**Delete (edit only):** destructive button at bottom **Delete reminder** with confirm:  
Title: Delete this daily reminder?  
Body: Past completions stay on your calendar unless you wipe data (actually: **deleting removes completions too** — say: `This removes the reminder and its history from d-ally.`).

**Stop (edit only):** button **Stop reminding** — keeps history, ends future occurrences.

### 8.8 Calendar Month View (`MonthCalendarView.swift`)

**Header:** Month year with prev/next. Button **Today** jumps month + selects today.

**Grid:** 7 columns Sun–Sat (use `Calendar.current.firstWeekday` for locale-correct first day — label accordingly).

**Day cell (`DayCellView`):**

- Day number
- Today: subtle aqua ring
- Selected: elevated glass/fill
- Below number: **horizontal row of dots** (max 4 visible; if more, 3 + `+N`)
- **Filled dot** = task color for each **kept** log that day only
- **Skipped:** do **not** add a filled color dot. If a day has only skips (no kept), show a single tiny hollow gray ring (stroke `textTertiary`, 4pt) so the day doesn’t look identical to “empty/missed” — one ring max regardless of skip count. If day has both kept dots and skips, show kept dots only (skips stay invisible on the grid; detail sheet lists them).
- Future days: no marks
- Missed-only days: empty (no red X)

**Tap day → `DayDetailSheet`:** list tasks with status Kept / Skipped / Missed / Scheduled + **Open in Day view**

**Legend:** `Filled colors = kept · Hollow ring = skipped only · Empty = missed or nothing logged`

**Personality line:** `Your month at a glance — color means you kept it. Skip stays off the color trail.`

### 8.9 Settings (`SettingsView.swift`)

Grouped list (native `List` / inset grouped):

**Section: Appearance**

- Theme: System / Light / Dark

**Section: Notifications**

- Master toggle: **Daily reminder alerts**
- Status row: Authorized / Denied / Not asked
- Enable / Open iOS Settings as before
- Explanation: `Local alerts at your remind time, plus follow-ups if still open.`

**Section: Quiet hours**

- Embed `QuietHoursSettingsView` content (§5A.2): toggle, start, end, helper about iPhone clock / no location

**Section: Defaults**

- Default follow-up mode (new tasks only)

**Section: About** / **Data** — unchanged intent from prior plan; onboarding reset allowed for testing.

---

## 9. Calendar day-log mapping (exact)

For each day `d` in month:

```
logs = TaskDayLog where dayKey == d.localDayKey
kept = logs where status == kept
skipped = logs where status == skipped

filledDots = kept.map { task.colorHex }  // resolve task by taskId; include stopped tasks; skip deleted
order filledDots by task.dueDate then name

if filledDots.isEmpty && !skipped.isEmpty:
  show single hollow tertiary ring
else:
  show filledDots (max 4 with +N overflow)
```

Cascade-delete all `TaskDayLog` rows when a `DailyTask` is deleted.

---

## 10. Notifications — full mechanism

### 10.1 Categories & actions (register at launch in `AppDelegate`)

Category ID: `dally.reminder`

| Action ID | Title | Options |
|---|---|---|
| `dally.action.done` | Mark done | background OK (no `.foreground`) |
| `dally.action.skip` | Skip today | background OK |
| `dally.action.open` | Open | `.foreground` |

Default tap → open deep link with prompt.

### 10.2 Content voice (exact templates)

**On-time / nudge reminder** (`kind: ontime`)

- Title: `{task.name}`
- Fixed body: `It’s time. Mark it done in d-ally when you’ve kept it.`
- Flexible body: `Window’s open until {completeBy}. Mark done whenever you finish.`
- Subtitle: `Daily reminder`
- Sound: `.default`
- `interruptionLevel`: `.active` (or `.timeSensitive` if entitlement added easily)

**Overdue once** (`kind: overdueOnce`) — anchors from **dueDate**

- Title: `{task.name}`
- Body: `Still open. Kept it — or skip today?`

**Hourly overdue** (`kind: overdueHourly`)

- Title: `{task.name}`
- Body: `Still on your day. Mark done, skip today, or open d-ally.`

### 10.3 userInfo payload (every request)

```
[
  "url": "dally://day?date={yyyy-MM-dd}&taskId={uuid}&prompt=1",
  "taskId": "{uuid}",
  "dayKey": "{yyyy-MM-dd}",
  "kind": "ontime" | "overdueOnce" | "overdueHourly"
]
```

### 10.4 Notification identifiers

- On-time/nudge: `ontime.{taskId}.{dayKey}`
- Overdue once: `overdue10.{taskId}.{dayKey}`
- Hourly: `overdueHourly.{taskId}.{dayKey}.{yyyyMMddHHmm}` of fire time

Cancel all pending IDs containing `.{taskId}.{dayKey}` when kept **or** skipped.

### 10.5 Scheduling algorithm (`NotificationSchedulingService.rescheduleAll`)

**Inputs:** tasks, day logs for next 7 local days, settings (incl. Quiet hours), auth status.

**Steps:**

1. If OS auth != authorized OR master disabled → remove app pending requests; return.
2. For `dayOffset` in `0...6`, for each active task that day:
   - If log status is kept **or** skipped → schedule nothing
   - If `notificationsEnabled == false` → skip
   - `nudge = task.nudgeDate(on: day)`
   - `due = task.dueDate(on: day)`
   - If `nudge > now` → schedule `ontime` at `nudge` (primary always allowed in Quiet hours)
   - Overdue follow-ups only if mode != off and task still open after due:
     - **onceAfter10Minutes:** candidate = `due + 10m`. If candidate in Quiet hours → defer to `QuietHoursService.nextQuietEnd(after: candidate)`. If deferred > now and same resolution still needed → schedule once.
     - **everyHourUntilDone:** generate hourly fires from `due + 1h` (or `due+10m` then hourly — **use every 60m starting at due+60m**) through end of that local day 23:59. **Drop any fire inside Quiet hours.** Do not spill past local day end.
3. Remove all pending; add desired; if > 64 keep soonest 64.

**When to call:** launch, scene active, task CRUD, kept/skip/clear, settings (notifications + quiet hours), BG refresh.

### 10.6 Handling actions

- `dally.action.done` → `markKept`
- `dally.action.skip` → `markSkipped`
- Default / Open → router → Day tab → prompt sheet (if still open)

Shared `ModelContainer` accessible from AppDelegate.

### 10.7 BGAppRefresh (recommended)

Identifier: `com.dally.app.refresh` — rescheduleAll best-effort.

### 10.8 Permission priming copy (`NotificationPrimingView`)

Title: **Don’t miss the moment**  
Body: d-ally can alert you at the time you chose — and follow up if it’s still open. Quiet hours keep overnight nags off. Alerts stay on your iPhone.  
Primary: **Enable alerts**  
Secondary: **Not now**
---

## 11. Deep linking

### 11.1 URL format

`dally://day?date=2026-09-03&taskId=UUID&prompt=1`

### 11.2 Router state (`DeepLinkRouter` `@Observable`)

```
selectedTab: AppTab
selectedDayKey: String?
focusTaskId: UUID?
showCompletionPrompt: Bool
```

`ContentRootView` observes and applies.

---

## 12. Copy Deck (complete strings)

### 12.1 Welcome

- Brand: `d-ally`
- Tagline: `Your daily ally.`
- Body: `d-ally is for the things you do every day at a time of day — medicine, gym, a run, not smoking. Set a time or a window. Mark it kept — or skip a day without faking a win. See your month in color.`
- Point1: `A time, every day` / `Exact time, or anytime before a deadline. Not a calendar event.`
- Point2: `Done, next, later` / `See kept, skipped, what’s soon, and what’s still ahead.`
- Point3: `Your month in color` / `Color means kept. Skips stay off the color trail.`
- CTA: `Begin`

### 12.2 Day empty

- `Nothing on your day yet.`
- `Add a daily reminder for a specific time — or an anytime-before window for things like a gym session.`
- `Add daily reminder`

### 12.3 Notifications (templates in §10.2)

### 12.4 Alerts

Delete: `Delete reminder?` / `This removes the reminder and its history from d-ally.` / `Delete` / `Cancel`  
Stop: `Stop this daily reminder?` / `You won’t be reminded going forward. Past days stay on your calendar.` / `Stop` / `Cancel`

### 12.5 Accessibility labels

- Checkbox open: `Mark {name} done`
- Kept: `Mark {name} not done`
- Skip: `Skip {name} today`
- Clear skip: `Clear skip for {name}`
- Flexible time: `{name}, anytime before {time}`

### 12.6 Quiet hours

- Toggle: `Quiet hours`
- Helper: `Uses your iPhone’s clock — no location needed. Follow-up nags wait; timed reminders still sound.`
- Start / End labels: `Starts` / `Ends`

---

## 13. Edge Cases (must handle)

| Case | Behavior |
|---|---|
| User denies notifications | App works; Settings banners; no crash |
| Kept before nudge fires | Cancel that day’s pending; calendar kept dot |
| Skipped before/after due | Cancel pending; no kept dot; hollow ring only if day has zero kept |
| Kept after overdue fired | Cancel remaining hourlies |
| Flexible: done at 15:00, window ends 22:00 | Kept immediately; cancel remaining notifs |
| Flexible: nudge 18:00, still open at 22:10 | Past due; overdue follow-ups from due+10m |
| Flexible: nudge after window end (invalid) | Editor blocks Save |
| Quiet hours 22–07; hourly would fire 23:00 | Drop that fire; next after 07:00 if still open same day — if quiet end is next calendar morning and task day already ended, **no spill** (hourlies end at local day 23:59; quiet simply removes late-night slots) |
| Quiet hours; overdue-once lands at 23:05 | Defer to 07:00 next morning **only if** that timestamp is still before end of scheduling usefulness — **spec: defer to quiet end even if next morning; if dayKey is yesterday and user opens app after, past-due UI remains; notification may still deliver at 07:00 with that dayKey so user can resolve yesterday** |
| On-time at 22:30 during quiet | Still fires |
| Quiet start == end | Treat as off; Settings validation message `Pick a longer quiet window` |
| Phone off during fire | iOS delivers later — OK |
| Multiple tasks same minute | All schedule; stable name sort |
| End date = today | Active today; gone tomorrow |
| Stop mid-day | Remove upcoming; keep logs; cancel notifs |
| Edit fixed ↔ flexible | Reschedule window |
| DST | Accept system local components |
| Locale 24h | System formatter |
| First weekday | `Calendar.current` |
| >64 pending | Keep soonest |
| Notification action Skip when killed | AppDelegate writes `skipped` via shared container |
| Future day resolve | Disallowed |
| Empty name | Save disabled |
| Notes length | Soft max 2000 |
| Travel / timezone change | Uses new local clock automatically; no location API |

---

## 14. Implementation Order (for executing agent)

1. Create Xcode project + folder structure + assets accent
2. Theme tokens + glass modifier
3. Models (`DailyTask`, `TaskDayLog`, enums) + ModelContainer
4. Date utilities + DayLogService + occurrence + QuietHoursService + DaySectioningService
5. DayPagerView + DayView + TaskRow + empty state (kept/skip/clear; no notifs yet)
6. TaskEditor with ScheduleKind + flexible fields + delete/stop
7. Settings appearance + Quiet hours
8. Welcome onboarding gate
9. Calendar month + day detail (kept dots vs skip hollow)
10. AppDelegate notification categories (done/skip/open) + priming
11. NotificationSchedulingService with due vs nudge + quiet deferral
12. Deep link + CompletionPromptSheet (done / skip / not yet)
13. BG refresh optional
14. Haptics, polish, Dynamic Type
15. Device test: fixed + flexible tasks; skip; quiet hours
16. Unit tests: dayKey, sectioning, quiet hours interval, flexible validation, notification IDs

---

## 15. Sample Seed (Preview only — not production)

1. Take morning pill — fixed 08:00 — Sky — notes “With water”
2. Don’t smoke — flexible complete by 22:00, nudge 16:00 — Ember
3. Gym — flexible complete by 21:00, nudge 17:00 — Coral — hourly overdue
4. Evening meds — fixed 21:00 — Rose — once after 10m

Preview logs: mix of kept + skipped on prior days so calendar shows filled dots and at least one hollow-only day.

---

## 16. Testing Checklist (device)

- [ ] Welcome → Begin → empty day
- [ ] Create fixed task due in 5 minutes; on-time notification
- [ ] Ignore; +10m overdue once
- [ ] Hourly task; nags until kept **or** skipped; stops after either
- [ ] Skip from notification action; no kept calendar dot
- [ ] Flexible task: mark kept mid-afternoon; not past due; calendar dot appears
- [ ] Flexible task: leave open past complete-by; becomes Past due; follow-ups from due
- [ ] Quiet hours on 22–07: no hourly in that window; on-time at 22:30 still fires if scheduled
- [ ] Quiet hours change triggers reschedule
- [ ] Tap notification → prompt → Mark done / Skip today / Not yet
- [ ] Day swipe; Jump to today; section opacity hierarchy
- [ ] Calendar: kept colors; skip-only day hollow ring; missed empty
- [ ] Light/Dark/System
- [ ] Deny notifications; manual kept/skip still works
- [ ] Stop / Delete / Edit schedule kind
- [ ] Portrait; Dynamic Type

---

## 17. Non-Goals (explicitly out of v1)

- Weekly/monthly recurrence patterns
- Multiple times per day for one task
- Streak counters / gamification
- Social / sharing
- iCloud sync
- Widgets / Watch / Live Activities
- Apple Health
- Accounts / paywall
- Siri App Intents
- Folders/tags beyond priority
- Natural language parsing
- **Location-based quiet hours / sunset** (explicitly rejected — clock only)
- Sunrise/sunset or WeatherKit

---

## 18. Success Criteria

The app is done when:

1. User can install from Xcode and create a daily timed or flexible reminder within 2 minutes.
2. Day view shows Kept / Skipped / Past due / Next hour / Later with correct opacity.
3. Skip never paints a kept color on the calendar.
4. Flexible windows only go past due after complete-by.
5. Quiet hours suppress overnight hourlies using the device clock with **zero** location permission.
6. Notifications deep-link to a prompt that can mark done or skip.
7. Copy makes clear this is a daily time-of-day ally, not a generic todo app.
8. Fully local; SwiftData persists.

---

## 19. Executing Agent Rules

1. Follow this plan; do not invent product features beyond §5A and the rest of this doc.
2. Prefer compiling, runnable code over abstractions.
3. If an API is unavailable on iOS 18, use Material fallbacks.
4. Keep files named as specified unless a merge is trivial.
5. Fix compile errors until `DAlly` runs on simulator and device.
6. Short `RUN.md` allowed for open/signing/run steps.

---

## 20. Addendum index (features added after initial draft)

| Feature | Spec sections |
|---|---|
| Skip today | §5.2c, §5.5, §5A.1, §6.3–6.5, §8.4–8.6, §9, §10 |
| Quiet hours (clock only) | §5.6, §5A.2, §8.9, §10.5, `QuietHoursService` |
| Flexible window | §5.2b, §5.4, §5A.3, §6.4, §8.7, §10.2/10.5 |

*End of build plan.*

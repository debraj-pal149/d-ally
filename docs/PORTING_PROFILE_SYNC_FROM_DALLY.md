# Porting d·ally profile + sync to your other app

Copy this file into the other app’s repo and rename it for that product.  
**Firebase account for all of this: `debraj@theminarnet.com` only** — never `mailme.debrajpal@gmail.com`.

This describes how d·ally does Google/Apple identity, Firestore sync, history, backups, Profile UI, and marketing hosting, so you can rebuild the same system elsewhere.

---

## Two jobs (do in this order)

### Task 1 — Profile + sync in the app (do first)

Ship the same **local-first + optional cloud profile** model as d·ally:

1. Guest works fully offline (SwiftData / on-device store).
2. Google or Apple sign-in creates a Firebase Auth user (identity only).
3. Habits / records / day history sync under `users/{uid}` in Firestore.
4. Sign out can **keep** or **remove** local data.
5. Delete profile wipes **that UID’s** cloud data + Firebase user; phone copy can stay until uninstall.
6. Soft-delete keeps history; hard erase is the only tombstone path.
7. Add a **Profile** tab (this app doesn’t have one yet).
8. In **Corner** (your Settings equivalent), add **Show welcome again** that resets onboarding **and** any in-app coach (same pattern as d·ally Settings).

### Task 2 — Marketing site on Firebase + your domain (do second)

After Task 1’s Firebase project exists under theminarnet:

1. Put the static site in a `website/` folder (or equivalent).
2. Point `firebase.json` hosting `public` at that folder; `.firebaserc` default = **this app’s** project id under theminarnet.
3. `firebase login` as **debraj@theminarnet.com** → `firebase deploy --only hosting`.
4. Firebase Hosting → Add custom domain → Namecheap DNS (A + TXT; remove parking/URL redirects).
5. App Store Privacy Policy URL = `https://YOURDOMAIN/privacy`.

---

## Firebase (theminarnet)

| Item | d·ally reference | Your app |
|---|---|---|
| Google account | `debraj@theminarnet.com` | Same account, **new** Firebase project (don’t reuse personal gmail projects) |
| Project | `d-ally-f0f63` | Create e.g. `yourapp-xxxxx` |
| iOS config | `GoogleService-Info.plist` (gitignored) | Download for your bundle id; gitignore it |
| Auth | Google + Apple | Same providers; Apple needs Services ID + Key (.p8) + Team ID |
| Apple handler | `https://d-ally-f0f63.firebaseapp.com/__/auth/handler` | `https://YOUR-PROJECT.firebaseapp.com/__/auth/handler` |
| Data path | `users/{uid}/habits\|logs\|bookmarks` | `users/{uid}/…` for **your** collections |
| Hosting | site `d-ally-f0f63` → `dallytasks.app` | New hosting site → **your** Namecheap domain |
| CLI | Logged in as theminarnet only | Same |

**Rules of thumb**

- Identity ≠ data. Auth gives `uid`; product data is Firestore + local store.
- One Firebase project per product under theminarnet is fine; don’t mix d·ally and this app’s users.
- Paste `firestore.rules` (adapted) into that project’s console.
- Never commit `.p8`, `GoogleService-Info.plist`, or Mixpanel tokens.

---

## How d·ally sync works (mirror this)

### Local store

- SwiftData (or equivalent) in an App Group if you have a widget.
- Phone is source of truth while offline.
- On first sign-in with local rows + different owner UID → **merge choice**: add local into profile, or wipe local and take cloud.

### Cloud

- Firestore `users/{uid}` profile doc (display name, email, providers, `updatedAt`, schema).
- Subcollections for synced entities; each doc has `updatedAt`; deletions use tombstones or soft-delete fields.
- Outbox / `SyncRecorder`: every local create/update/delete enqueues a push.
- `SyncEngine`: drain outbox up; listen inbound; last `updatedAt` wins; soft-delete ≠ hard wipe.
- First sign-in / `enqueueAll`: upload full local union once.

### Soft-delete vs hard erase (habits example)

- Soft-delete: set `deletedAt`, **keep logs**, push full record via “changed”, not a habit tombstone that drops history.
- Hard erase (account delete / wipe): delete cloud trees for that uid; optional local wipe only if user chose “remove”.

### Sign out / delete (Profile)

| Action | Cloud | Local |
|---|---|---|
| Sign out → keep on phone | Untouched | Kept; sync stops |
| Sign out → remove from phone | Untouched | Wiped |
| Delete profile | Delete `users/{uid}` + Auth user | d·ally keeps phone copy; clear owner markers |

Apple delete needs a **recent** sign-in and working Apple provider config (Services ID + key).

### Local backups

- Before a destructive merge, snapshot the store under Application Support / Backups (d·ally does this on merge).
- Export history from Profile as JSON-safe dates (strings), for user download / support.

### Checklist before any model change

Same as d·ally’s `.cursor/rules/history-and-sync.mdc`:

1. Local model + safe defaults  
2. Cloud encode/decode/apply + tombstones  
3. Every write → sync recorder  
4. Inbound merge  
5. enqueueAll / first sign-in  
6. History export  
7. UI live vs ended/deleted filters  

---

## UI to add in the other app

### Bottom tabs (add Profile)

Today you have no Profile tab. Target pattern like d·ally:

| Tab | Role |
|---|---|
| …existing… | Product |
| **Profile** (new) | Account, sync status, export, sign out / delete |
| **Corner** | App prefs (your Settings). **Not** the place for Google/Apple buttons as the only home — Profile owns account |

Suggested Profile contents (match d·ally):

- Header: avatar / name / email or “On this phone only”
- If signed in: Sync status row (idle / syncing / error)
- Counts: core entities + “days marked” / history size as fits your product
- If guest: **Continue with Google**, **Continue with Apple**, footnote that data stays on device until sign-in
- **Export history**
- If signed in: **Sign out** (keep vs remove dialog), **Delete profile and synced data**

Onboarding (if you have Welcome):

1. Welcome  
2. Profile setup (sign in or continue without account) → sets `hasCompletedOnboarding`  
3. Optional Day/home coach (d·ally style) armed with `dayCoachPending`

### Corner — Show welcome again

In Corner (not a separate Settings tab), add under Data / About:

**Show welcome again** → reset:

- `welcomeSeen = false` (or equivalent)
- `hasCompletedOnboarding = false`
- `dayCoachPending = true` (if you add a coach)

Same as d·ally Settings → “Show welcome again”.

---

## Files / modules to copy or reimplement from d·ally

Use as a map, not a blind copy-paste (bundle ids, models, and collections differ):

| Area | d·ally paths |
|---|---|
| Auth | `DAlly/Sync/AuthService.swift` |
| Sync | `SyncEngine.swift`, `SyncRecorder.swift`, `CloudCodec.swift`, `SyncOutbox.swift` |
| Export | `HistoryExport.swift` |
| Profile UI | `Features/Profile/ProfileView.swift`, `ProfileSetupView.swift`, `SignInButtons` |
| Merge UI | `MergeProgressSheet` + merge alerts in `ContentRootView` |
| Onboarding flags | `AppStorageKey.hasCompletedOnboarding`, `welcomeSeen`, `dayCoachPending` |
| Hosting | `firebase.json`, `.firebaserc`, `website/` |
| Rules | `firestore.rules` |
| Cursor rule | `.cursor/rules/history-and-sync.mdc` |

Wire Sign in with Apple capability, URL schemes from `GoogleService-Info`, and Google Sign-In SDK the same way.

---

## Hosting + domain (Task 2 detail)

1. Project under theminarnet → Enable Hosting.  
2. `firebase use YOUR_PROJECT` (CLI = theminarnet).  
3. Deploy website. Confirm `https://YOUR_PROJECT.web.app/privacy`.  
4. Add custom domain in console; Namecheap Advanced DNS:
   - Remove parking A (`192.64…`) and URL Redirect `@` → www  
   - Add Firebase A (+ TXT `hosting-site=…`)  
   - Keep SPF TXT if present  
5. Wait for SSL. App Store Privacy URL = `https://YOURDOMAIN/privacy`.

---

## What not to do

- Don’t put this product on the personal Gmail Firebase project.  
- Don’t share d·ally’s `users/{uid}` tree with this app.  
- Don’t ship account creation without in-app delete (App Review 5.1.1).  
- Don’t start Individual→Organization conversion mid–membership change for unrelated reasons; seller name can wait.

---

## Suggested build order for the other app

1. Firebase project (theminarnet) + `GoogleService-Info` + Auth Google/Apple  
2. Local models + SyncRecorder/Engine/Codec for **your** entities  
3. Profile tab + Profile setup in onboarding  
4. Sign out keep/remove + delete account  
5. Export + merge choice  
6. Corner → Show welcome again  
7. Deploy website + connect domain  
8. App Store privacy URL + nutrition labels  

When you’re ready to implement in that repo, open this file there and start at Task 1.

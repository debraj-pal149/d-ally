# App Store Connect — App Privacy answers for d·ally

Fill **App Store Connect → Your App → App Privacy** to match the live app and `website/privacy.html`.  
Privacy Manifest in the binary: `DAlly/PrivacyInfo.xcprivacy` (`NSPrivacyTracking` = false).

## Do you collect data?

**Yes.**

## Data types (declare these)

| Type | Linked to identity? | Used for tracking? | Purposes |
|---|---|---|---|
| **User ID** (Firebase uid) | Yes | No | App functionality (sync), Analytics (Mixpanel when on) |
| **Email address** | Yes | No | App functionality (from Apple/Google if provided) |
| **Name** | Yes | No | App functionality (display in Profile) |
| **Other user content** | Yes | No | App functionality — habits, day marks, **day notes**, bookmarks |
| **Product interaction** | Yes (when signed in) / may be on-device id when guest | No | Analytics (Mixpanel), App functionality |
| **Device ID** | Yes when Mixpanel is on | No | Analytics only (Mixpanel SDK) |

Do **not** declare: Precise Location, Contacts, Photos, Health, Financial, Advertising Data (unless you add those later).

## Tracking

**No** — d·ally does not use data to track users across other companies’ apps/websites for ads.  
`NSPrivacyTracking` in the privacy manifest is `false`. Do not enable App Tracking Transparency unless that changes.

## Third-party partners (nutrition label partners)

- **Google** — Firebase Auth, Firestore (sign-in + sync)  
- **Mixpanel** — product analytics (respects in-app **Product analytics** toggle)  
- **Apple** — Sign in with Apple, App Store, on-device notifications  

## Privacy Policy URL

`https://dallytasks.app/privacy`

## Notes for reviewers

- Guest mode works with no account.  
- Delete profile is under Profile when signed in.  
- Day notes sync when signed in and appear in history export.  
- Users can turn off product analytics in **Settings → Privacy**.

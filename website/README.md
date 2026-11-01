# d·ally website

Short marketing site for the App Store listing (US & India).

## Pages

- `index.html` - home (uses real Day, Calendar, and Sunday review screenshots, plus decorative rhythm art in `assets/`)
- `privacy.html` - Privacy Policy
- `terms.html` - Terms of Use

Replace `assets/app-day.png`, `assets/app-calendar.png`, and `assets/app-week.jpg` anytime with fresher device captures.

## Run locally

```bash
cd website
python3 -m http.server 8765
```

Open http://localhost:8765

## Production

- Firebase account: **debraj@theminarnet.com** only (project `d-ally-f0f63`)
- Domain: **dallytasks.app** (Namecheap) → Hosting site `d-ally-f0f63`
- Temporary URL: https://d-ally-f0f63.web.app
- Deploy: `firebase deploy --only hosting` from the repo root (CLI must be logged in as theminarnet)
- App Store Privacy Policy URL: `https://dallytasks.app/privacy`
- Terms: `https://dallytasks.app/terms`

## Before launch

1. Replace App Store URLs with the real app ID once App Store Connect publishes it.
2. Confirm `debraj@theminarnet.com` is monitored and matches App Store Connect.
3. In App Store Connect → App Information, set Privacy Policy URL to `https://dallytasks.app/privacy`.

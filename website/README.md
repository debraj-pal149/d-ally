# d·ally website

Short marketing site for the App Store listing (US & India).

## Pages

- `index.html` — home (uses real Day + Calendar screenshots in `assets/`)
- `privacy.html` — Privacy Policy
- `terms.html` — Terms of Use

Replace `assets/app-day.png` and `assets/app-calendar.png` anytime with fresher device captures.

## Run locally

```bash
cd website
python3 -m http.server 8765
```

Open http://localhost:8765

## Before launch

1. Replace App Store URLs with the real app ID once App Store Connect publishes it.
2. Confirm `hello@dally.app` (or your real support email) is live and matches App Store Connect.
3. Host these files on your domain and set that URL in App Store Connect → App Information → Privacy Policy URL (and Terms if asked).

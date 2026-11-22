# Pebble website

Landing page for **Pebble**, a focus companion for macOS. Pebble is a small blob that lives in the MacBook notch: you give it one goal and one app, it runs a 15, 25 or 45 minute sprint, turns red when you drift to a blocked site or app, asks for a reason before you open anything else, and shows a recap when the sprint ends.

This repository holds only the public website and the downloadable build. The site is static: no backend, no analytics, no environment variables, no API keys.

## What's here

```
.
├── index.html          The whole landing page (HTML + inline CSS, Google Fonts)
├── favicon.svg         Pebble mascot icon
├── download/
│   └── Pebble.dmg      Universal (Apple Silicon + Intel) macOS build, ad-hoc signed
├── vercel.json         Download headers for the .dmg
└── README.md
```

## Tech stack

- Plain HTML and CSS, no build step
- Hosted on Vercel as a static site; every push to `main` redeploys

## Run it locally

Prerequisites: any static file server, for example Python 3.

```bash
git clone <this repo>
cd <repo folder>
python3 -m http.server 8080
# open http://localhost:8080
```

There is no `.env` to set up: the site uses no secrets or environment variables.

## Updating the download

The `.dmg` is produced from the app source with `make-release.sh` (kept with the app, not in this repo). It builds both architectures, ad-hoc signs the app so no developer identity is embedded, refuses to package if a local path or username is found in the binary, and copies the result to `download/Pebble.dmg`. Commit and push to publish it.

## Installing Pebble (for users)

1. Download `Pebble.dmg` and drag Pebble into Applications.
2. Open it once. Pebble isn't notarized by Apple, so macOS shows a "can't be verified" warning.
3. Go to **System Settings › Privacy & Security**, scroll down and click **Open Anyway**. You only do this once.

Requirements: macOS 14 or later. The AI guardrail judge runs through an AI command-line tool already on your Mac (Claude Code, agy or opencode).

## License

MIT, see [LICENSE](LICENSE).

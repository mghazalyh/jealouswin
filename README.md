# Jealouswin — Jealousfin Web

An alternative Flutter web client for the existing Jealousfin LAN gateway, with independent English/Malay selection, live HLS playback, current programme titles, shared favorites and authoritative channel policy, channel surf rotation, previous/next, pause, stop, mute, brightness and fullscreen.

Production: https://jealouswin.pages.dev/

## Connect

Enter the English and Malay gateway URLs (typically HTTP LAN addresses on ports 18796 and 18797) and the same gateway credentials as the native Jealousfin client. Allow local-network access in the browser when prompted. The LAN gateway must permit the exact production origin via CORS and preflight. If a browser blocks HTTP from HTTPS, use a trusted HTTPS endpoint on your LAN or a browser supporting secure-context local network access. No Cloudflare proxy, public tunnel, external stream service or embedded credentials are required.

Only the application files are hosted on Cloudflare Pages. Authentication, catalogue and video requests go directly from the browser to the selected server. Passwords and tokens remain in memory. Only server addresses are stored locally.

Server policy is authoritative: all eligibility, ban, hiatus, success and failure history is read from the same gateway. Favorites are updated through its authenticated endpoint. The client reports ordinary playback sessions, but deliberately does not write shared success/failure penalties or approval events: browser networking and codec errors cannot reliably prove upstream channel failure. The browser has its own in-memory rotation ledger and does not control the native iPad. Native maintenance/engineering controls are not ported.

## CI/CD

Flutter 3.32.4 / Dart 3.8.1. The GitHub-hosted workflow uses the committed Flutter and Wrangler lockfiles, runs analysis and tests, builds the web app and bundles a checksum-verified HLS.js release, then deploys to Cloudflare Pages via Wrangler. It verifies the canonical production commit and HTTPS assets. The Cloudflare account ID and scoped Pages Write token are configured as GitHub Actions secrets. Do not commit credentials.

All Jealouswin engineering uses GitHub and GitHub Actions only. No Fast Consumer, OpenCode, Macmini, SentinelX or self-hosted runner is used to build or deploy the web app. Gateway maintenance is a separate explicitly authorized operation.

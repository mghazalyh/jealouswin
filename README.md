# jealouswin

A responsive Flutter web starter with an interactive session-only checklist,
progress tracking, and light/dark themes. No backend, accounts, or external API
keys are required. The starter is live at https://jealouswin.pages.dev/.

## Run locally

Use Flutter 3.32.4 (the existing local SDK, also pinned in CI):

```sh
flutter pub get --enforce-lockfile
flutter run -d chrome
```

Edit `lib/main.dart` to begin customizing the application. Checklist items and
theme choices reset on reload. Generated Flutter icons are placeholders.

```sh
flutter analyze --no-pub
flutter test --no-pub
flutter build web --release --no-pub
```

Tests cover checklist interactions, theme changes, and mobile layout. Build output
is written to `build/web`. Upgrade Flutter and regenerate `pubspec.lock` together
when choosing a newer SDK for ongoing development.

## Application layout

The Flutter project lives at the repository root. Keep `pubspec.lock` committed
and preserve `.github/` when extending the application.

## Deployment

`.github/workflows/cloudflare-deploy.yml` runs on pushes to `main` and supports
manual runs from the Actions tab. Until `pubspec.yaml` exists, it reports that
source is missing and skips deployment. That result is not a live deployment.

The workflow requires a committed lockfile, installs locked
dependencies, runs `flutter analyze` and any unit/widget tests in `test/`, builds
with `flutter build web --release`, and uploads `build/web` using pinned Wrangler.
If either Cloudflare secret is missing, the workflow still validates the app and
explicitly skips publishing with a warning and a run summary. A green run alone
does not prove deployment. Integration tests should grow with the app's behavior.
Production runs are serialized and use a GitHub-hosted runner with read-only
repository permissions. No self-hosted runner is required.

## Cloudflare project

The Pages Direct Upload project `jealouswin` exists, with production branch
`main` and the free Cloudflare domain https://jealouswin.pages.dev/.
The initial production deployment was uploaded and its HTTPS assets verified.
No custom domain or paid service was enabled.

The account ID Actions secret is configured. Automatic publishing still requires
the dedicated `CLOUDFLARE_API_TOKEN` secret. The local Wrangler OAuth login is
kept in encrypted storage backed by Windows Credential Manager; it is not used
as a substitute for a permanent CI deployment token.

Remaining credential setup:

1. Create a dedicated token named `github-actions-cloudflare-deploy` with only
   **Account / Cloudflare Pages / Edit**, scoped to the selected account.
   Do not add DNS permissions, Workers administration, or a global API key.
2. Set repository Actions secret `CLOUDFLARE_API_TOKEN`.
   Never commit or print its value.
3. Run the workflow. After uploading, it verifies that Cloudflare's production
   deployment matches the workflow commit and checks the production and preview
   HTTPS assets. It records the verified URLs in the run summary.

Use Cloudflare's provided domain. Do not enable paid services or make unrelated
DNS changes. Recheck current Pages and GitHub Actions free-tier limits before
the first real deployment. Browser API tokens and private application credentials
must never be embedded in Flutter web output; that output is public client code.

Official references: [Flutter web deployment](https://docs.flutter.dev/deployment/web),
[Cloudflare CI deployment](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/),
[Pages limits](https://developers.cloudflare.com/pages/platform/limits/).

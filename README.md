# jealouswin

Reserved for a future Flutter web application. No application has been created or deployed yet.

## Application layout

Place the Flutter project at the repository root. Commit `pubspec.yaml`,
`pubspec.lock`, `lib/`, `web/`, and your tests. Keep this repository's `.github/`
deployment configuration when adding the application. The SDK revision is pinned
in the workflow; review it against your application's Dart/Flutter requirements.

## Deployment

`.github/workflows/cloudflare-deploy.yml` runs on pushes to `main` and supports
manual runs from the Actions tab. Until `pubspec.yaml` exists, it reports that
source is missing and skips deployment. That result is not a live deployment.

Once source exists, the workflow requires a committed lockfile, installs locked
dependencies, runs `flutter analyze` and any unit/widget tests in `test/`, builds
with `flutter build web --release`, and uploads `build/web` using pinned Wrangler.
Integration and browser tests must be added when the app's behavior is defined.
Production runs are serialized and use a GitHub-hosted runner with read-only
repository permissions. No self-hosted runner is required.

Cloudflare setup is **pending**:

1. Verify the intended Cloudflare account and its free-tier status.
2. Create or verify an appropriate Pages Direct Upload project named `jealouswin`,
   production branch `main`. Change `CLOUDFLARE_PROJECT` in the workflow if the
   available project name differs. Existing unrelated projects must not be reused.
3. Create a dedicated token named `github-actions-cloudflare-deploy` with only
   **Account / Cloudflare Pages / Edit**, scoped to the selected account.
   Do not add DNS permissions, Workers administration, or a global API key.
4. Set repository Actions secrets `CLOUDFLARE_API_TOKEN` and
   `CLOUDFLARE_ACCOUNT_ID`. Never commit or print their values.
5. Push the real app, monitor the deployment job, and verify the returned HTTPS URL
   and application behavior. No public deployment URL is confirmed yet.

Use Cloudflare's provided domain. Do not enable paid services or make unrelated
DNS changes. Recheck current Pages and GitHub Actions free-tier limits before
the first real deployment. Browser API tokens and private application credentials
must never be embedded in Flutter web output; that output is public client code.

Official references: [Flutter web deployment](https://docs.flutter.dev/deployment/web),
[Cloudflare CI deployment](https://developers.cloudflare.com/pages/how-to/use-direct-upload-with-continuous-integration/),
[Pages limits](https://developers.cloudflare.com/pages/platform/limits/).

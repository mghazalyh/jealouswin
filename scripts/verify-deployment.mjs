import { appendFileSync, readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const { CLOUDFLARE_ACCOUNT_ID: account, CLOUDFLARE_API_TOKEN: token,
  CLOUDFLARE_PROJECT: project, GITHUB_SHA: commit, GITHUB_STEP_SUMMARY: summary } = process.env;
if (!account || !token || !project || !commit) {
  throw new Error('Missing deployment verification configuration.');
}

const endpoint = `https://api.cloudflare.com/client/v4/accounts/${encodeURIComponent(account)}/pages/projects/${encodeURIComponent(project)}`;
let deployment;
let subdomain;
for (let attempt = 0; attempt < 12; attempt++) {
  const response = await fetch(endpoint, {
    headers: { Authorization: `Bearer ${token}` },
    signal: AbortSignal.timeout(20_000),
  });
  if (!response.ok) throw new Error(`Cloudflare project verification returned HTTP ${response.status}.`);
  const body = await response.json();
  if (!body.success) throw new Error('Cloudflare project verification failed.');
  deployment = body.result.canonical_deployment;
  subdomain = body.result.subdomain;
  if (deployment?.environment === 'production' &&
      deployment.latest_stage?.status === 'success' &&
      deployment.deployment_trigger?.metadata?.commit_hash === commit) break;
  deployment = undefined;
  await new Promise(resolve => setTimeout(resolve, 5_000));
}
if (!deployment) throw new Error('No successful production deployment found for this commit.');

const preview = new URL(deployment.url);
if (!subdomain?.endsWith('.pages.dev') ||
    preview.protocol !== 'https:' || !preview.hostname.endsWith(`.${subdomain}`)) {
  throw new Error('Cloudflare returned an unexpected deployment domain.');
}
const production = `https://${subdomain}`;
const digest = data => createHash('sha256').update(data).digest('hex');
for (const base of [preview.origin, production]) {
  for (const asset of ['/', '/flutter_bootstrap.js', '/main.dart.js', '/manifest.json', '/player.js', '/assets/jealouswin/rtc.js', '/hls.min.js', '/flutter_service_worker.js', '/rtc-test.html', '/rtc-test-ui.js', '/assets/jealouswin/rtc-test.js']) {
    const response = await fetch(`${base}${asset}?release=${commit}`, {
      signal: AbortSignal.timeout(30_000),
    });
    if (!response.ok) throw new Error(`HTTPS check failed for ${base}${asset}: ${response.status}`);
    const bytes = await response.arrayBuffer();
    if (!bytes.byteLength) throw new Error(`Empty deployment asset: ${asset}`);
    const local=readFileSync('build/web'+(asset==='/'?'/index.html':asset));
    if(digest(Buffer.from(bytes))!==digest(local))throw new Error(`Stale or mismatched deployment asset: ${base}${asset}`);
    if(!/no-store/i.test(response.headers.get('cache-control')||''))throw new Error(`Missing no-store policy for ${base}${asset}`);
    console.log(`Verified ${base}${asset}: HTTP ${response.status}`);
  }
}
console.log(`Production deployment verified for commit ${commit}: ${production}`);
if (summary) appendFileSync(summary,
  `\n### Production deployment verified\n\n[Open app](${production}) · [Deployment](${preview.origin})\n\nCommit: \`${commit}\`\n`);

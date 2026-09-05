# Forgejo on Fly.io

Standalone Forgejo deployment for Fly.io with one initial admin, optional Caddy HTTP basic auth, and optional restic backups.

## Setup

Install and authenticate the [Fly CLI](https://fly.io/docs/flyctl/install/), then run:

```bash
./setup.sh
```

The script prompts for:

- A globally unique Fly app name
- A [Fly region](https://fly.io/docs/reference/regions/)
- The initial Forgejo admin username and email
- Whether visitors must sign in before viewing Forgejo
- Whether to enable Caddy HTTP basic auth and, if enabled, its single username and password

It creates the Fly app, writes the generated `fly.toml`, stores credentials as Fly secrets, and deploys Forgejo with a 10 GB persistent volume. The Forgejo admin password is generated securely and printed before and after deployment. Save it when displayed.

The app is available at `https://<appname>.fly.dev/`. Registration is disabled, so the generated admin is the only account on a new installation. Add any later users through Forgejo's admin interface.

## Access Control

Two independent settings restrict access by default:

- Forgejo's `GITEA__service__REQUIRE_SIGNIN_VIEW` prevents anonymous visitors from viewing Forgejo content when enabled during setup.
- Caddy basic auth is enabled when both `CADDY_BASIC_AUTH_USERNAME` and `CADDY_BASIC_AUTH_PASSWORD` are set. The setup script can configure them for you. Git HTTP endpoints and the package API remain outside Caddy authentication so Git and package clients can authenticate directly with Forgejo.

To make the instance publicly viewable, answer no to both access-control prompts during setup. For an existing instance, leave the Caddy credentials unset, change `GITEA__service__REQUIRE_SIGNIN_VIEW` to `false` in the generated `fly.toml`, then run `fly deploy`.

To enable or change Caddy authentication later:

```bash
fly secrets set CADDY_BASIC_AUTH_USERNAME=forge CADDY_BASIC_AUTH_PASSWORD='your-password'
```

To disable it, unset both secrets:

```bash
fly secrets unset CADDY_BASIC_AUTH_USERNAME CADDY_BASIC_AUTH_PASSWORD
```

## Backups

Set all restic configuration as Fly secrets. Backups stay disabled until every value is present.

```bash
fly secrets set \
  AWS_ACCESS_KEY_ID='...' \
  AWS_SECRET_ACCESS_KEY='...' \
  RESTIC_REPOSITORY='s3:https://.../forgejo' \
  RESTIC_PASSWORD='...'
```

Initialize the repository once:

```bash
fly ssh console --command "/usr/local/bin/backup-init.sh"
```

The backup process snapshots `/data` hourly when all required variables are available. To restore a snapshot from inside a stopped or debug machine:

```bash
backup-restore.sh latest
```

## Debug Startup

Set `DEBUGDEPLOY` to keep a machine alive without starting services, or use:

```bash
./bin/debug-deploy.sh start
./bin/debug-deploy.sh stop
```

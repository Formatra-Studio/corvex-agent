# BRANDING.md: every change Corvex Agent makes to Pterodactyl Wings

Corvex Agent is a light fork. Wire protocol, HTTP routes, JSON payloads, config keys, JWT checks,
remote API calls to the panel and WebSocket events are **unchanged**. Only the items below differ
from upstream; keep this list complete and the diff small so upstream security fixes merge in
minutes. Line numbers refer to the files at the time of the change; re-check them after a merge.

Base: Pterodactyl Wings `v1.13.4`. The Go module path stays `github.com/pterodactyl/wings` on
purpose: renaming it would touch every import in every file.

## Added files (no upstream conflict possible)

| File | Purpose |
|---|---|
| `NOTICE`, `BRANDING.md`, `README.md` (rewritten) | Attribution, this list, Corvex build and release notes |
| `config/corvex.go`, `config/corvex_test.go` | Agent default paths; Wings defaults for configs read from `/etc/pterodactyl/config.yml` |
| `system/corvex.go`, `system/corvex_test.go` | `daemon`, `agent_version`, `features` for `GET /api/system` |
| `packaging/corvex-agent.service` | systemd unit `corvex-agent.service` |
| `scripts/build-release.sh` | Reproducible release build (`CGO_ENABLED=0`, `-trimpath`, `-buildid=`) |
| `.github/workflows/corvex-ci.yaml`, `corvex-release.yaml`, `corvex-upstream.yaml` | CI, signed releases, weekly upstream merge |

## Removed files

| File | Reason |
|---|---|
| `.github/workflows/release.yaml` | Upstream release job; it would run on our `v*` tags and publish to Pterodactyl's CDN |
| `.github/workflows/docker.yaml` | We ship binaries, not container images |
| `.github/dependabot.yaml` | Dependencies follow upstream; our own bumps would only add merge conflicts |

## Changed lines

| File | Line(s) | Change | Reason |
|---|---|---|---|
| `config/config.go` | 31 | `DefaultLocation` = `/etc/corvex-agent/config.yml` | Default config location |
| `config/config.go` | 140-156 | Default root, log, data, archive, backup and tmp paths under `corvex-agent` | New installs only (see `config/corvex.go`) |
| `config/config.go` | 350 | Default `app_name` = `Corvex` | Console prefix `[Corvex Daemon]:` |
| `config/config.go` | 466-468 | `NewAtPath` applies Wings defaults for `/etc/pterodactyl/config.yml` | Migrated nodes never move data or network |
| `config/config.go` | 817-840 | Log rotation file `/etc/logrotate.d/corvex-agent`, `corvex-agent.log`, `corvex-agent.service` | Log name and unit name |
| `config/config_docker.go` | 37, 40 | Default network `corvex_nw` | New installs only |
| `environment/docker.go` | 48, 95 | Log line; bridge `corvex0` (`pterodactyl0` for `pterodactyl_nw`) | Branding, new installs only |
| `cmd/root.go` | 45, 80 | `--config` default: agent file, or the Wings file when only that exists | Config fallback |
| `cmd/root.go` | 50-57, 81, 87, 112, 114, 292 | Command name `corvex-agent`, help and log texts | Branding |
| `cmd/root.go` | 69 | `version` prints `corvex-agent v<agent> (based on Pterodactyl Wings v<upstream>)` | `--version` |
| `cmd/root.go` | 479-482 | Log file `corvex-agent.log` | Log name |
| `cmd/root.go` | 492-519 | Startup banner and missing-config notice | Banner (MIT notice kept) |
| `cmd/diagnostics.go` | 51-155 | Report title, versions, headers, log file | Diagnostics report |
| `remote/http.go` | 128 | User-Agent `Corvex Agent/v<agent> (id:…)` | User agent (the `Accept` header is protocol and stays) |
| `router/downloader/downloader.go` | 26, 214 | User-Agent `Corvex Agent/v<agent>` for remote file pulls | User agent |
| `router/router_system.go` | 28-48 | Both `/api/system` forms gain `daemon`, `agent_version`, `features` | Additive detection fields |
| `sftp/server.go` | 205 | SSH version string `SSH-2.0-CorvexAgent` | SFTP identification |
| `server/install.go` | 383 | Install log header `Server Installation Log` | Customer-visible text |
| `server/mounts.go` | 143 | "check the node daemon logs" | Customer-visible text |
| `router/router_server_files.go` | 471 | "the node daemon does not understand" | Customer-visible text |

## Deliberately unchanged

- `system.Version` stays the upstream version (`1.13.4`): panels compare it against the Wings
  versions they support. The agent release is `agent_version` (`1.13.4-cvx.1`).
- `Accept: application/vnd.pterodactyl.v1+json`, backup adapter name `wings`, container label
  `Service=Pterodactyl`, the `pterodactyl` system user, `/run/wings/*` runtime paths, `wings.db`
  and the `WINGS_*` environment variables: they are protocol, data or state an existing node
  depends on.
- The `configure` command (talks to a Pterodactyl panel API; Corvex nodes use the bootstrap).

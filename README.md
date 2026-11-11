# Corvex Agent

The node daemon for [Corvex](https://github.com/Formatra-Studio/Corvex-Panel). It runs game
servers in Docker and speaks the Pterodactyl Wings protocol unchanged, so a Corvex panel can mix
Corvex Agent nodes and plain Wings nodes.

**Corvex Agent is based on Pterodactyl Wings (MIT).** See `LICENSE`, `NOTICE` and, for every
change from upstream, `BRANDING.md`. The Go modules in the binary and their licenses are listed in
`THIRD_PARTY_NOTICES.md`; `corvex-agent license --all` prints every license text from the binary.

## Layout on a node

| | New install | Node migrated from Wings |
|---|---|---|
| Binary / unit | `/usr/local/bin/corvex-agent`, `corvex-agent.service` | same |
| Config | `/etc/corvex-agent/config.yml` | `/etc/pterodactyl/config.yml` (read automatically when the agent file does not exist) |
| Data | `/var/lib/corvex-agent/{volumes,archives,backups}` | unchanged (`/var/lib/pterodactyl/...`) |
| Logs | `/var/log/corvex-agent/corvex-agent.log` | `/var/log/pterodactyl/corvex-agent.log` |
| Docker network | `corvex_nw` (bridge `corvex0`) | unchanged (`pterodactyl_nw`) |
| System user | `corvex` (uid 988) | unchanged (`pterodactyl`) |
| Runtime files / state | `/run/corvex-agent`, `corvex-agent.db` | unchanged (`/run/wings`, `wings.db`) |

## Build

Go version from `go.mod`.

```
go test ./...
scripts/build-release.sh 1.13.4-cvx.1 dist    # binaries, .tar.gz archives with licenses, SHA256SUMS
scripts/check-release.sh 1.13.4-cvx.1 dist    # checksums and license files in every archive
```

`dist/` then holds:

| File | Contents |
|---|---|
| `corvex-agent_linux_{amd64,arm64}` | Bare binary; the node bootstrap installs this one (license texts embedded: `corvex-agent license --all`) |
| `corvex-agent_linux_{amd64,arm64}.tar.gz` | `corvex-agent_<version>_linux_<arch>/` with the binary, `LICENSE`, `NOTICE`, `THIRD_PARTY_NOTICES.md`, `third_party/licenses/` and `third_party/sources/` (source zips of the MPL-2.0 and LGPL-3.0 modules) |
| `SHA256SUMS` | SHA-256 of the four files above |

Builds are deterministic: CI builds twice and compares the checksums. To check a release independently,
rebuild the tag with the same Go version and compare the binaries with `SHA256SUMS` (the archives
also depend on the local `tar` and `gzip`).

## Third-party licenses

`THIRD_PARTY_NOTICES.md` and `third_party/` are generated from the modules compiled into the binaries.
After a dependency change or an upstream merge:

```
go install github.com/google/go-licenses/v2@v2.0.1
scripts/update-licenses.sh            # rewrites THIRD_PARTY_NOTICES.md and third_party/; commit them
```

CI runs `scripts/update-licenses.sh --check`: it fails when the files are stale or a module brings a
license outside MIT, BSD, ISC, Apache-2.0 and MPL-2.0 (LGPL-3.0 only for `github.com/juju/ratelimit`,
which has a static-linking exception). Such a license needs a review before the next release.

## Release

Versions are `<upstream version>-cvx.<n>`, e.g. `1.13.4-cvx.1`.

1. Tag `main`: `git tag v1.13.4-cvx.1 && git push origin v1.13.4-cvx.1`.
2. `corvex-release.yaml` tests and builds without secrets, then waits for approval on the
   `agent-release` environment.
3. After approval it signs each binary, each archive and `SHA256SUMS` with the Ed25519 key in the
   environment secret `AGENT_SIGNING_KEY` and publishes a GitHub release with the binaries, the
   `.tar.gz` archives, `SHA256SUMS`, the `.sig` files and the public key. Before that, a separate job
   checks that the third-party notices are current and the build job checks that every archive
   carries the license files.
4. In Corvex, add the version and both SHA-256 values to `config/corvex.php` →
   `daemons.agent.releases`. The node bootstrap checks the SHA-256 and the signature against the
   public key built into the script.

Signing key (once, by the founder, offline):

```
openssl genpkey -algorithm ed25519 -out corvex-agent-signing.key
openssl pkey -in corvex-agent-signing.key -pubout -out corvex-agent-signing.pub
```

Store the private key as `AGENT_SIGNING_KEY` in the `agent-release` environment (Settings →
Environments: required reviewers, and deployment tags limited to `v*-cvx.*`) and keep an offline
backup. The public key goes into
Corvex's `resources/scripts/node-bootstrap.sh`. The release key is separate from every other key.

## Upstream merges

`corvex-upstream.yaml` runs every Monday (or by hand). When Pterodactyl tags a new Wings release
it merges the tag and runs the Go tests in a job with read-only access, then a second job (which runs
no project code) pushes `upstream/<tag>`, opens a pull request and starts Corvex CI on it.

1. Resolve conflicts on that branch, keeping every change in `BRANDING.md` and nothing more. Run
   `scripts/update-licenses.sh` when the merge changed `go.mod`.
2. Run the Corvex contract suite against a build of the branch (`tests/Contract` in Corvex).
3. Merge, update `BRANDING.md` if line numbers moved, and release `<tag>-cvx.1`.

Security releases: merged and released within 72 hours.

The workflow needs "Allow GitHub Actions to create and approve pull requests" in the repository
settings. Pull requests opened with the workflow token do not start `pull_request` workflows, so the
workflow starts Corvex CI with `workflow_dispatch` instead.

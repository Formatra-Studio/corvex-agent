#!/usr/bin/env bash
# Builds the release binaries reproducibly: the same tag and Go version give byte-identical files.
# Usage: scripts/build-release.sh <agent version, e.g. 1.13.4-cvx.1> [output dir]
set -euo pipefail

version="${1:?agent version required, e.g. 1.13.4-cvx.1}"
out="${2:-dist}"
if [[ ! "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-cvx\.[0-9]+$ ]]; then
    echo "version must look like 1.13.4-cvx.1, got: $version" >&2
    exit 1
fi
upstream="${BASH_REMATCH[1]}"
pkg="github.com/pterodactyl/wings"
mkdir -p "$out"

for arch in amd64 arm64; do
    CGO_ENABLED=0 GOOS=linux GOARCH="$arch" go build -trimpath -buildvcs=false \
        -ldflags="-s -w -buildid= -X ${pkg}/system.Version=${upstream} -X ${pkg}/system.AgentVersion=${version}" \
        -o "${out}/corvex-agent_linux_${arch}" "$pkg"
    chmod 755 "${out}/corvex-agent_linux_${arch}"
done

(cd "$out" && sha256sum corvex-agent_linux_amd64 corvex-agent_linux_arm64 > SHA256SUMS)
cat "${out}/SHA256SUMS"

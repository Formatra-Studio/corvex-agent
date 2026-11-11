#!/usr/bin/env bash
# Builds the release reproducibly: the same tag and Go version give byte-identical binaries.
# Usage: scripts/build-release.sh <agent version, e.g. 1.13.4-cvx.1> [output dir]
#
# Output:
#   corvex-agent_linux_{amd64,arm64}         bare binaries, the files the Corvex node bootstrap installs
#   corvex-agent_linux_{amd64,arm64}.tar.gz  the binary with LICENSE, NOTICE, THIRD_PARTY_NOTICES.md,
#                                            third_party/licenses/ and third_party/sources/
#   SHA256SUMS                               checksums of all four files
# The license texts are also embedded in each binary (`corvex-agent license --all`).
set -euo pipefail
export LC_ALL=C # file lists and sort order must not depend on the caller's locale

version="${1:?agent version required, e.g. 1.13.4-cvx.1}"
out="${2:-dist}"
if [[ ! "$version" =~ ^([0-9]+\.[0-9]+\.[0-9]+)-cvx\.[0-9]+$ ]]; then
    echo "version must look like 1.13.4-cvx.1, got: $version" >&2
    exit 1
fi
upstream="${BASH_REMATCH[1]}"
pkg="github.com/pterodactyl/wings"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
cd "$(dirname "$0")/.."

stage="$(mktemp -d)"
trap 'rm -rf "$stage"' EXIT
# Archive timestamps: the commit time, so a rebuild of the same commit gives the same archive.
epoch="${SOURCE_DATE_EPOCH:-$(git log -1 --format=%ct 2>/dev/null || echo 0)}"

# What every archive carries next to the binary: the license files, and the source of each module
# whose license (MPL-2.0, LGPL-3.0) asks for it to go with the binary: the module zip go.sum pins.
legal="$stage/legal"
mkdir -p "$legal/third_party"
cp LICENSE NOTICE THIRD_PARTY_NOTICES.md "$legal/"
cp -r third_party/licenses "$legal/third_party/licenses"
while read -r mod ver; do
    [[ -n "$mod" ]] || continue
    # The default proxy, so the zip is the one proxy.golang.org serves (THIRD_PARTY_NOTICES.md).
    zip="$(GOPROXY=https://proxy.golang.org go mod download -json "${mod}@${ver}" | sed -n 's/^\t"Zip": "\(.*\)",$/\1/p')"
    if [[ ! -f "$zip" ]]; then
        echo "could not download the source of ${mod}@${ver}" >&2
        exit 1
    fi
    install -D -m 0644 "$zip" "$legal/third_party/sources/${mod}@${ver}.zip"
done <third_party/source-modules.txt

for arch in amd64 arm64; do
    CGO_ENABLED=0 GOOS=linux GOARCH="$arch" go build -trimpath -buildvcs=false \
        -ldflags="-s -w -buildid= -X ${pkg}/system.Version=${upstream} -X ${pkg}/system.AgentVersion=${version}" \
        -o "${out}/corvex-agent_linux_${arch}" "$pkg"
    chmod 755 "${out}/corvex-agent_linux_${arch}"

    dir="corvex-agent_${version}_linux_${arch}"
    cp -r "$legal" "$stage/$dir"
    cp "${out}/corvex-agent_linux_${arch}" "$stage/$dir/corvex-agent"
    find "$stage/$dir" -type d -exec chmod 755 {} + -o -type f -exec chmod 644 {} +
    chmod 755 "$stage/$dir/corvex-agent"
    tar --sort=name --format=gnu --owner=0 --group=0 --numeric-owner --mtime="@${epoch}" \
        -C "$stage" -cf - "$dir" | gzip -n -9 >"${out}/corvex-agent_linux_${arch}.tar.gz"
done

(cd "$out" && sha256sum corvex-agent_linux_amd64 corvex-agent_linux_arm64 \
    corvex-agent_linux_amd64.tar.gz corvex-agent_linux_arm64.tar.gz >SHA256SUMS)
cat "${out}/SHA256SUMS"

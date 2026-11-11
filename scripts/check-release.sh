#!/usr/bin/env bash
# Checks the output of scripts/build-release.sh before it is signed: checksums, and that every archive
# carries the binary with LICENSE, NOTICE, THIRD_PARTY_NOTICES.md, every file in third_party/licenses
# and the source zip of every module in third_party/source-modules.txt.
# Usage: scripts/check-release.sh <agent version> <release dir>
set -euo pipefail
export LC_ALL=C # file lists and sort order must not depend on the caller's locale

version="${1:?agent version required, e.g. 1.13.4-cvx.1}"
dir="${2:?release dir required}"
dir="$(cd "$dir" && pwd)"
cd "$(dirname "$0")/.."

fail() {
    echo "release check failed: $*" >&2
    exit 1
}

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

expected=(corvex-agent_linux_amd64 corvex-agent_linux_arm64 corvex-agent_linux_amd64.tar.gz corvex-agent_linux_arm64.tar.gz)
[[ "$(awk '{ print $2 }' "$dir/SHA256SUMS")" == "$(printf '%s\n' "${expected[@]}")" ]] ||
    fail "SHA256SUMS must list exactly: ${expected[*]}"
(cd "$dir" && sha256sum --check --quiet SHA256SUMS) || fail "checksum mismatch"
# The release job publishes everything in the directory.
[[ "$(cd "$dir" && find . -mindepth 1 -printf '%P\n' | sort)" == "$(printf '%s\n' "${expected[@]}" SHA256SUMS | sort)" ]] ||
    fail "$dir must hold exactly: ${expected[*]} SHA256SUMS"

# The files each archive must hold, relative to its top directory.
{
    printf '%s\n' corvex-agent LICENSE NOTICE THIRD_PARTY_NOTICES.md
    find third_party/licenses -type f
    awk 'NF { printf "third_party/sources/%s@%s.zip\n", $1, $2 }' third_party/source-modules.txt
} | sort >"$work/want"
grep -q '^third_party/licenses/go/LICENSE$' "$work/want" || fail "third_party/licenses/go/LICENSE is missing"

for arch in amd64 arm64; do
    top="corvex-agent_${version}_linux_${arch}"
    archive="$dir/corvex-agent_linux_${arch}.tar.gz"
    mkdir "$work/$arch"
    tar -xzf "$archive" -C "$work/$arch"
    [[ "$(ls "$work/$arch")" == "$top" ]] || fail "$archive: top directory must be $top"
    (cd "$work/$arch/$top" && find . -type f -printf '%P\n' | sort) >"$work/have_$arch"
    diff -u "$work/want" "$work/have_$arch" >&2 || fail "$archive: files differ from the list above"
    cmp -s "$dir/corvex-agent_linux_${arch}" "$work/$arch/$top/corvex-agent" ||
        fail "$archive: corvex-agent differs from corvex-agent_linux_${arch}"
    for f in LICENSE NOTICE THIRD_PARTY_NOTICES.md; do
        cmp -s "$f" "$work/$arch/$top/$f" || fail "$archive: $f differs from the source tree"
    done
    diff -r third_party/licenses "$work/$arch/$top/third_party/licenses" >&2 ||
        fail "$archive: third_party/licenses differs from the source tree"
    while read -r mod ver; do
        [[ -n "$mod" ]] || continue
        # go mod download verifies the module zip against go.sum.
        zip="$(go mod download -json "${mod}@${ver}" | sed -n 's/^\t"Zip": "\(.*\)",$/\1/p')"
        cmp -s "$zip" "$work/$arch/$top/third_party/sources/${mod}@${ver}.zip" ||
            fail "$archive: the source zip of ${mod}@${ver} is not the module zip pinned in go.sum"
    done <third_party/source-modules.txt
done

# The binary for this machine prints the embedded texts (protocol untouched: `license` only reads them).
case "$(uname -m)" in
x86_64) native=amd64 ;;
aarch64 | arm64) native=arm64 ;;
*) native="" ;;
esac
if [[ -n "$native" && "$(uname -s)" == "Linux" ]]; then
    bin="$dir/corvex-agent_linux_${native}"
    "$bin" license | grep -q 'Permission is hereby granted' || fail "$bin license: MIT text missing"
    "$bin" license --all >"$work/all.txt"
    { echo THIRD_PARTY_NOTICES.md; find third_party/licenses -type f | sort; } | while read -r f; do
        grep -qxF "==> $f <==" "$work/all.txt" || fail "$bin license --all: $f missing"
    done
    "$bin" version | grep -qF "corvex-agent v${version} " || fail "$bin version: expected v${version}"
fi

echo "release ${version} in ${dir}: checksums, license files and source zips present"

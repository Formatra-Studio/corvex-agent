#!/usr/bin/env bash
# Regenerates THIRD_PARTY_NOTICES.md and third_party/ from the Go modules compiled into the release
# binaries (linux/amd64 and linux/arm64, CGO_ENABLED=0). Run it after every dependency change or
# upstream merge and commit the result; CI runs it with --check and fails when the files are stale or
# a module brings a license that is not on the list below.
#
# Usage: scripts/update-licenses.sh           rewrite THIRD_PARTY_NOTICES.md and third_party/
#        scripts/update-licenses.sh --check   only compare (CI)
# Needs go-licenses v2: go install github.com/google/go-licenses/v2@v2.0.1 (or set GO_LICENSES).
set -euo pipefail

cd "$(dirname "$0")/.."
check=0
[[ "${1:-}" == "--check" ]] && check=1

golicenses="${GO_LICENSES:-$(go env GOPATH)/bin/go-licenses}"
if [[ ! -x "$golicenses" ]]; then
    echo "go-licenses not found; install it: go install github.com/google/go-licenses/v2@v2.0.1" >&2
    exit 1
fi

# Licenses a module may carry without a review. LGPL-3.0 is only accepted for the modules named here,
# whose license adds a static-linking exception (checked below).
allowed=" Apache-2.0 BSD-0-Clause BSD-2-Clause BSD-3-Clause ISC MIT MPL-2.0 "
lgpl_ok=" github.com/juju/ratelimit "

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
main="$(go list -m)"
toolchain="$(awk '$1 == "toolchain" { print $2 }' go.mod)"
toolchain="${toolchain:-go$(awk '$1 == "go" { print $2 }' go.mod)}"

export CGO_ENABLED=0 GOOS=linux
for arch in amd64 arm64; do
    GOARCH="$arch" go list -deps -f '{{with .Module}}{{if not .Main}}{{.Path}} {{.Version}}{{end}}{{end}}' . >>"$work/modules.raw"
    GOARCH="$arch" "$golicenses" report . 2>"$work/report_$arch.log" >>"$work/report.raw" ||
        { cat "$work/report_$arch.log" >&2; exit 1; }
    GOARCH="$arch" "$golicenses" save . --save_path="$work/save_$arch" 2>"$work/save_$arch.log" ||
        { cat "$work/save_$arch.log" >&2; exit 1; }
done
sort -u "$work/modules.raw" >"$work/modules"
sort -u "$work/report.raw" >"$work/report.csv"

# Module of a package path or file path: the longest module path that is a prefix of it.
by_module() {
    awk -v main="$main" '
        NR == FNR { mods[NR] = $1; n = NR; next }
        {
            best = ""
            if ($1 == main || index($1, main "/") == 1) best = main
            for (i = 1; i <= n; i++) {
                m = mods[i]
                if (($1 == m || index($1, m "/") == 1) && length(m) > length(best)) best = m
            }
            if (best == "") { print "no module for " $1 > "/dev/stderr"; exit 1 }
            print best, $0
        }' "$work/modules" -
}

# module license (one line per pair), without the main module.
tr ',' ' ' <"$work/report.csv" | awk '{ print $1, $3 }' | by_module |
    awk -v main="$main" '$1 != main { print $1, $3 }' | sort -u >"$work/licenses"

status=0
while read -r mod lic; do
    if [[ "$allowed" != *" $lic "* ]] && ! [[ "$lic" == "LGPL-3.0" && "$lgpl_ok" == *" $mod "* ]]; then
        echo "license needs a review before release: $mod is $lic" >&2
        status=1
    fi
done <"$work/licenses"
while read -r mod _; do
    if ! awk -v m="$mod" '$1 == m { found = 1 } END { exit !found }' "$work/licenses"; then
        echo "go-licenses reported no license for $mod" >&2
        status=1
    fi
done <"$work/modules"
[[ "$status" -eq 0 ]] || exit 1

# License, notice and copying files only: go-licenses also saves the full source of MPL/LGPL modules,
# which the release ships as the module zip instead (third_party/source-modules.txt).
out="$work/out"
dest="$out/third_party/licenses"
mkdir -p "$dest/go"
for arch in amd64 arm64; do
    (cd "$work/save_$arch" && find . -type f \( -iname 'licen[cs]e*' -o -iname 'notice*' -o -iname 'copying*' \) \
        ! -iname '*.go' -printf '%P\n')
done | sort -u | while read -r f; do
    [[ "$f" == "$main/LICENSE" || "$f" == "$main/NOTICE" ]] && continue # top-level LICENSE and NOTICE
    src="$work/save_amd64/$f"
    [[ -f "$src" ]] || src="$work/save_arm64/$f"
    install -D -m 0644 "$src" "$dest/$f"
done
install -m 0644 "$(go env GOROOT)/LICENSE" "$dest/go/LICENSE"

# LGPL-3.0 is a set of additional permissions on top of GPL-3.0; both texts go with the binary.
awk '$2 == "LGPL-3.0" { print $1 }' "$work/licenses" | while read -r mod; do
    if ! grep -q 'links statically or dynamically' "$dest/$mod/LICENSE"; then
        echo "$mod: static-linking exception not found in its LICENSE" >&2
        exit 1
    fi
    install -m 0644 /usr/share/common-licenses/GPL-3 "$dest/$mod/GPL-3.0.txt"
done

(cd "$dest" && find . -type f ! -path './go/*' -printf '%P\n') | by_module | sort >"$work/files"
# Modules whose license asks for the source to go with the binary; build-release.sh ships their zips.
awk 'NR == FNR { if ($2 == "MPL-2.0" || $2 == "LGPL-3.0") want[$1] = 1; next } want[$1]' \
    "$work/licenses" "$work/modules" >"$out/third_party/source-modules.txt"

licenses_of() { awk -v m="$1" '$1 == m { print $2 }' "$work/licenses" | paste -sd, - | sed 's/,/, /g'; }
files_of() { awk -v m="$1" '$1 == m { printf "%s`third_party/licenses/%s`", sep, $2; sep = "<br>" }' "$work/files"; }
# Module proxy paths escape upper-case letters as !lower.
proxy_url() { printf 'https://proxy.golang.org/%s/@v/%s.zip' "$(sed 's/[A-Z]/!\L&/g' <<<"$1")" "$2"; }

{
    cat <<EOF
# Third-party notices

<!-- Generated by scripts/update-licenses.sh from go-licenses; do not edit by hand. -->

Corvex Agent release binaries (\`linux/amd64\`, \`linux/arm64\`) contain the code listed here. Every
license text and NOTICE file is in \`third_party/licenses/\`, next to this file in the source tree and
in every release archive; \`corvex-agent license --all\` prints the same texts from the binary. None of
these components is modified.

## Pterodactyl Wings

Corvex Agent is based on Pterodactyl Wings, https://github.com/pterodactyl/wings, used under the MIT
license. The full license text, with its copyright notice, is in \`LICENSE\`; the attribution is in
\`NOTICE\`:

> Copyright (c) 2018 - 2021 Dane Everitt <dane@daneeveritt.com> and Contributors

Every change Corvex made is listed in \`BRANDING.md\`. The Wings package \`internal/ufs\` carries its own
MIT license: \`third_party/licenses/$main/internal/ufs/LICENSE\`.

## Go

The Go standard library and runtime (toolchain \`$toolchain\`), BSD-3-Clause:
\`third_party/licenses/go/LICENSE\`.

## Licenses with source obligations

EOF
    while read -r mod ver; do
        lics="$(licenses_of "$mod")"
        printf -- '- `%s` %s (%s), unmodified.\n' "$mod" "$ver" "$lics"
        printf '  Source: `third_party/sources/%s@%s.zip` in every release archive, identical to\n' "$mod" "$ver"
        printf '  %s (checksum in `go.sum`).\n' "$(proxy_url "$mod" "$ver")"
        if [[ "$lics" == *LGPL-3.0* ]]; then
            printf '  Linked statically under the static-linking exception in its LICENSE; LGPL-3.0 builds on GPL-3.0,\n'
            printf '  whose text is in `third_party/licenses/%s/GPL-3.0.txt`.\n' "$mod"
        fi
    done <"$out/third_party/source-modules.txt"
    cat <<EOF

## Apache-2.0 NOTICE files

Carried unchanged, as Apache-2.0 section 4(d) requires:

EOF
    awk 'tolower($2) ~ /(^|\/)notice[^\/]*$/' "$work/files" | while read -r mod f; do
        printf -- '- `%s`: `third_party/licenses/%s`\n' "$mod" "$f"
    done
    cat <<EOF

## Go modules

| Module | Version | License | License and notice files |
|---|---|---|---|
EOF
    while read -r mod ver; do
        printf '| `%s` | %s | %s | %s |\n' "$mod" "$ver" "$(licenses_of "$mod")" "$(files_of "$mod")"
    done <"$work/modules"
} >"$out/THIRD_PARTY_NOTICES.md"

if [[ "$check" -eq 1 ]]; then
    if ! diff -u THIRD_PARTY_NOTICES.md "$out/THIRD_PARTY_NOTICES.md" || ! diff -r third_party "$out/third_party"; then
        echo "THIRD_PARTY_NOTICES.md or third_party/ is out of date: run scripts/update-licenses.sh" >&2
        exit 1
    fi
    echo "third-party notices are up to date ($(wc -l <"$work/modules") modules)"
else
    rm -rf third_party
    cp -r "$out/third_party" third_party
    cp "$out/THIRD_PARTY_NOTICES.md" THIRD_PARTY_NOTICES.md
    echo "wrote THIRD_PARTY_NOTICES.md and third_party/ ($(wc -l <"$work/modules") modules)"
fi

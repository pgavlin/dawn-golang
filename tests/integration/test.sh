#!/usr/bin/env bash
set -euo pipefail

repo=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/dawn-golang-integration.XXXXXX")
tmp=$(cd "$tmp" && pwd -P)
trap 'rm -rf "$tmp"' EXIT
cp -R "$repo/tests/integration/project/." "$tmp/"
cp "$repo/go_binary.dawn" "$repo/go_sources.dawn" "$tmp/"
cd "$tmp"

git init -q
git config user.email test@example.com
git config user.name Test
git add .
git commit -qm initial

# Module-in-a-subdirectory, tags, extra flags, and CGO/Go flag parameters.
dawn //:default >/dev/null
[[ $(go/bin/feature-default) == default ]]
[[ $(go/bin/feature-special) == special ]]
[[ $(go/bin/cgo) == 42 ]]

# A tag-only source belongs only to the binary built with that tag.
printf '\n// tag-only change\n' >> go/cmd/feature/feature_special.go
special_log=$(dawn //:feature_special 2>&1)
default_log=$(dawn //:feature_default 2>&1)
grep -q 'evaluating' <<<"$special_log"
grep -q 'up-to-date' <<<"$default_log"

# A source used by A does not invalidate unrelated binary B.
printf '\n// A-only change\n' >> go/internal/a/a.go
a_log=$(dawn //:a 2>&1)
b_log=$(dawn //:b 2>&1)
grep -q 'evaluating' <<<"$a_log"
grep -q 'up-to-date' <<<"$b_log"

# A commit alone does not change a binary built with -buildvcs=false. Even after
# forcing that binary to rebuild, a target that consumes it remains up to date.
before=$(shasum -a 256 go/bin/stable | awk '{print $1}')
lines_before=$(wc -l < downstream.txt)
git add . && git commit -qm 'source tracking checks'
dawn -B //:stable >/dev/null
after=$(shasum -a 256 go/bin/stable | awk '{print $1}')
[[ $before == "$after" ]]
downstream_log=$(dawn //:downstream 2>&1)
grep -q 'up-to-date' <<<"$downstream_log"
[[ $(wc -l < downstream.txt) -eq $lines_before ]]

echo "integration test passed"

#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Negative control for scripts/check-membership.sh, offline: the real manifest
# must pass and four planted corruptions must each fail. A gate that cannot
# fail is not a gate.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
real=machine-readable/descriptiles/ECOSYSTEM.a2ml
tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
ok=0; bad=0
expect() { # expect pass|fail MANIFEST LABEL
  if MEMBERSHIP_OFFLINE=1 MEMBERSHIP_MANIFEST="$2" bash scripts/check-membership.sh >/dev/null 2>&1; then got=pass; else got=fail; fi
  if [ "$got" = "$1" ]; then ok=$((ok + 1)); echo "ok   $3"; else bad=$((bad + 1)); echo "FAIL $3 (expected $1, got $got)"; fi
}
expect pass "$real" "real manifest passes"
sed 's/x15-rocket-glider -> planer-1/x15-rocket-glider -> x-15/' "$real" > "$tmp/chain.a2ml"
expect fail "$tmp/chain.a2ml" "corrupted chain fails"
grep -v 'name = "planer-1"' "$real" > "$tmp/missing.a2ml"
expect fail "$tmp/missing.a2ml" "missing member entry fails"
sed 's/^  { order = 7, name = "tardis-rule-disruption"/  { order = 8, name = "688-attack-hub", display = "x", repo = "x", group = "x", member-phase = "x", slot = "x" },\n&/' "$real" > "$tmp/smuggled.a2ml"
expect fail "$tmp/smuggled.a2ml" "688-attack-hub smuggled into members fails"
sed 's|^coordination = .*|coordination = "metadatastician"|' "$real" > "$tmp/coord.a2ml"
expect fail "$tmp/coord.a2ml" "org-not-repo coordination fails"
echo "membership negative control: $ok passed, $bad failed"
[ "$bad" -eq 0 ]

#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# check-membership.sh — the hub's one real gate.
#   1. The manifest must carry exactly one chain of seven members, a [members]
#      entry for each in chain order, this repo as coordination, and no
#      688-attack-hub entry (an estate sibling that is not a glider).
#   2. Unless MEMBERSHIP_OFFLINE=1: every member must exist on GitHub and its own
#      ECOSYSTEM.a2ml (machine-readable/ or .machine_readable/ layout) must carry
#      the same chain string and name this hub as coordination.
# Env: MEMBERSHIP_MANIFEST (path override; used by the negative-control test),
#      MEMBERSHIP_OFFLINE=1 (skip the remote half), GH_TOKEN (CI).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
manifest="${MEMBERSHIP_MANIFEST:-machine-readable/descriptiles/ECOSYSTEM.a2ml}"
expected_hub="metadatastician/stealth-glider-ecosystem"
failures=0
fail() { printf 'membership error: %s\n' "$1" >&2; failures=$((failures + 1)); }

[ -f "$manifest" ] || { fail "manifest $manifest not found"; exit 1; }
chain_count="$(grep -cE '^chain = ' "$manifest" || true)"
[ "$chain_count" -eq 1 ] || fail "expected exactly one chain line, found $chain_count"
chain="$(grep -m1 -E '^chain = ' "$manifest" | cut -d'"' -f2)"
hub="$(grep -m1 -E '^coordination = ' "$manifest" | cut -d'"' -f2)"
[ -n "$chain" ] || fail "chain is empty"
[ "$hub" = "$expected_hub" ] || fail "coordination is '$hub', expected '$expected_hub'"

mapfile -t members < <(printf '%s\n' "$chain" | sed 's/ -> /\n/g')
[ "${#members[@]}" -eq 7 ] || fail "chain has ${#members[@]} members, expected 7"
i=0
for m in "${members[@]}"; do
  i=$((i + 1))
  grep -Fq "{ order = $i, name = \"$m\"," "$manifest" \
    || fail "[members] has no entry for order $i, name \"$m\""
done
if grep -Eq '^[[:space:]]*\{ order = [0-9]+, name = "688-attack-hub"' "$manifest"; then
  fail "688-attack-hub must not be a member"
fi
entries="$(grep -cE '^[[:space:]]*\{ order = [0-9]+, name = "' "$manifest" || true)"
[ "$entries" -eq "${#members[@]}" ] || fail "[members] has $entries entries, chain has ${#members[@]}"

if [ "${MEMBERSHIP_OFFLINE:-0}" != "1" ]; then
  owner="${hub%%/*}"
  fetch_raw() { curl -fsSL "https://raw.githubusercontent.com/$1/main/$2"; }
  for m in "${members[@]}"; do
    repo="$owner/$m"
    if ! gh api "repos/$repo" --silent >/dev/null 2>&1; then
      fail "$repo does not exist on GitHub (or is not visible to this token)"; continue
    fi
    eco="$(fetch_raw "$repo" machine-readable/descriptiles/ECOSYSTEM.a2ml 2>/dev/null \
        || fetch_raw "$repo" .machine_readable/descriptiles/ECOSYSTEM.a2ml 2>/dev/null || true)"
    [ -n "$eco" ] || { fail "$repo: ECOSYSTEM.a2ml not found at either descriptile layout"; continue; }
    grep -Fq "chain = \"$chain\"" <<<"$eco" || fail "$repo: chain differs from the hub's"
    grep -Fq "coordination = \"$hub\"" <<<"$eco" || fail "$repo: coordination is not $hub"
  done
fi

if [ "$failures" -gt 0 ]; then
  printf 'membership integrity FAILED (%d error(s))\n' "$failures" >&2
  exit 1
fi
mode=""; [ "${MEMBERSHIP_OFFLINE:-0}" = "1" ] && mode=", offline"
printf 'membership integrity passed (%d members%s)\n' "${#members[@]}" "$mode"

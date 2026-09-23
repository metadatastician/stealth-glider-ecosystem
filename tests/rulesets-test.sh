#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
# Positive and negative controls for the repository's GitHub ruleset policy.
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_root="$(mktemp -d /tmp/rsr-rulesets-test.XXXXXX)"

cleanup() {
  case "$fixture_root" in
    /tmp/rsr-rulesets-test.*) rm -rf -- "$fixture_root" ;;
    *) echo "refusing unsafe cleanup target: $fixture_root" >&2 ;;
  esac
}
trap cleanup EXIT

validate_rulesets() {
  local root="$1"
  local tag_ruleset="$root/.github/rulesets/Immutable-Tags.json"
  local branch_ruleset="$root/.github/rulesets/Optimus-Branch.json"
  local settings="$root/.github/settings.yml"

  [[ -f "$tag_ruleset" && -f "$branch_ruleset" && -f "$settings" ]] || return 1
  [[ ! -e "$root/.github/rulesets/tag-protection.json" ]] || return 1

  jq -e '
    .name == "Immutable-Tags" and
    .target == "tag" and
    .enforcement == "active" and
    .conditions.ref_name.include == ["~ALL"] and
    .conditions.ref_name.exclude == [] and
    .bypass_actors == [] and
    (.rules | map(.type) | sort) == [
      "creation",
      "deletion",
      "non_fast_forward",
      "required_signatures",
      "update"
    ] and
    (.rules | length == (map(.type) | unique | length)) and
    all(.rules[]; keys == ["type"])
  ' "$tag_ruleset" >/dev/null || return 1

  jq -e '
    .name == "Optimus-Branch" and
    .target == "branch" and
    .enforcement == "active" and
    .conditions.ref_name.include == ["~DEFAULT_BRANCH"] and
    .conditions.ref_name.exclude == [] and
    .bypass_actors == [] and
    (.rules | map(.type) | sort) == [
      "deletion",
      "non_fast_forward",
      "pull_request",
      "required_signatures",
      "required_status_checks"
    ] and
    (.rules | length == (map(.type) | unique | length)) and
    ([.rules[] | select(.type == "pull_request")] | length) == 1 and
    (.rules[] | select(.type == "pull_request").parameters |
      .required_approving_review_count == 2 and
      .dismiss_stale_reviews_on_push == true and
      .require_code_owner_review == true and
      .require_last_push_approval == true and
      .required_review_thread_resolution == true and
      .require_extra_approval_for_unattributed_changes == true and
      .required_reviewers == [] and
      .allowed_merge_methods == []
    ) and
    ([.rules[] | select(.type == "required_status_checks")] | length) == 1 and
    (.rules[] | select(.type == "required_status_checks").parameters |
      .strict_required_status_checks_policy == true and
      .do_not_enforce_on_create == false and
      .required_status_checks == []
    )
  ' "$branch_ruleset" >/dev/null || return 1

  grep -Eq '^  default_branch: main[[:space:]]*$' "$settings" || return 1
  ! grep -Eq '^branches:[[:space:]]*$' "$settings"
}

copy_policy_fixture() {
  local destination="$1"
  mkdir -p "$destination/.github/rulesets"
  cp "$repo_root/.github/rulesets/Immutable-Tags.json" "$destination/.github/rulesets/"
  cp "$repo_root/.github/rulesets/Optimus-Branch.json" "$destination/.github/rulesets/"
  cp "$repo_root/.github/settings.yml" "$destination/.github/"
}

mutate_json() {
  local file="$1"
  local filter="$2"
  jq "$filter" "$file" > "$file.tmp"
  mv "$file.tmp" "$file"
}

ok=0
bad=0
expect() { # expect pass|fail ROOT LABEL
  local expected="$1"
  local root="$2"
  local label="$3"
  local actual

  if validate_rulesets "$root"; then
    actual=pass
  else
    actual=fail
  fi

  if [[ "$actual" == "$expected" ]]; then
    ok=$((ok + 1))
    echo "ok   $label"
  else
    bad=$((bad + 1))
    echo "FAIL $label (expected $expected, got $actual)"
  fi
}

expect pass "$repo_root" "current rulesets enforce the complete policy"

missing_tag_rule="$fixture_root/missing-tag-rule"
copy_policy_fixture "$missing_tag_rule"
mutate_json "$missing_tag_rule/.github/rulesets/Immutable-Tags.json" \
  'del(.rules[] | select(.type == "deletion"))'
expect fail "$missing_tag_rule" "removing immutable-tag deletion protection fails"

narrow_tag_scope="$fixture_root/narrow-tag-scope"
copy_policy_fixture "$narrow_tag_scope"
mutate_json "$narrow_tag_scope/.github/rulesets/Immutable-Tags.json" \
  '.conditions.ref_name.include = ["refs/tags/releases/*"]'
expect fail "$narrow_tag_scope" "narrowing immutable-tag coverage fails"

unsigned_branch="$fixture_root/unsigned-branch"
copy_policy_fixture "$unsigned_branch"
mutate_json "$unsigned_branch/.github/rulesets/Optimus-Branch.json" \
  'del(.rules[] | select(.type == "required_signatures"))'
expect fail "$unsigned_branch" "removing signed-commit enforcement fails"

weak_review="$fixture_root/weak-review"
copy_policy_fixture "$weak_review"
mutate_json "$weak_review/.github/rulesets/Optimus-Branch.json" \
  '(.rules[] | select(.type == "pull_request").parameters.required_approving_review_count) = 1'
expect fail "$weak_review" "reducing required approvals fails"

bypass_actor="$fixture_root/bypass-actor"
copy_policy_fixture "$bypass_actor"
mutate_json "$bypass_actor/.github/rulesets/Optimus-Branch.json" \
  '.bypass_actors = [{"actor_id": 5, "actor_type": "RepositoryRole", "bypass_mode": "always"}]'
expect fail "$bypass_actor" "adding an unrestricted bypass actor fails"

phantom_check="$fixture_root/phantom-check"
copy_policy_fixture "$phantom_check"
mutate_json "$phantom_check/.github/rulesets/Optimus-Branch.json" \
  '(.rules[] | select(.type == "required_status_checks").parameters.required_status_checks) = [{"context": "never-emitted"}]'
expect fail "$phantom_check" "adding an unverified required status check fails"

legacy_protection="$fixture_root/legacy-protection"
copy_policy_fixture "$legacy_protection"
printf '\nbranches:\n  - name: main\n' >> "$legacy_protection/.github/settings.yml"
expect fail "$legacy_protection" "restoring legacy Probot branch protection fails"

echo "ruleset policy controls: $ok passed, $bad failed"
[[ "$bad" -eq 0 ]]

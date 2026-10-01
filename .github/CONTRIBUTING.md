<!--
SPDX-License-Identifier: CC-BY-SA-4.0
Copyright (c) Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
-->
# Clone the repository
git clone https://github.com/metadatastician/stealth-glider-ecosystem.git
cd stealth-glider-ecosystem

# Using Guix (recommended for reproducibility)
guix shell -D -f guix.scm

# Or using toolbox/distrobox
toolbox create stealth-glider-ecosystem-dev
toolbox enter stealth-glider-ecosystem-dev
# Install dependencies manually

# Verify setup
just check   # or: cargo check / mix compile / etc.
just test    # Run test suite
```

### Repository Structure

The authoritative map is **generated** from the tree and checked in CI, so it
cannot drift:
[`docs/architecture/REPOSITORY-MAP.adoc`](../docs/architecture/REPOSITORY-MAP.adoc).
Regenerate it with `just repo-map`.

A hand-written tree used to live here. It described `lib/`, `extensions/`,
`plugins/` and `spec/` directories that this repository has never contained,
which is precisely why the map is now generated rather than typed.

---

## How to Contribute

### Reporting Bugs

**Before reporting**:
1. Search existing issues
2. Check if it's already fixed in `main`
3. Determine which perimeter the bug affects

**When reporting**:

Use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.md) and include:

- Clear, descriptive title
- Environment details (OS, versions, toolchain)
- Steps to reproduce
- Expected vs actual behaviour
- Logs, screenshots, or minimal reproduction

### Suggesting Features

**Before suggesting**:
1. Check the [roadmap](../docs/status/ROADMAP.adoc) if available
2. Search existing issues and discussions
3. Consider which perimeter the feature belongs to

**When suggesting**:

Use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.md) and include:

- Problem statement (what pain point does this solve?)
- Proposed solution
- Alternatives considered
- Which perimeter this affects

### Your First Contribution

Look for issues labelled:

- [`good first issue`](https://github.com/metadatastician/stealth-glider-ecosystem/labels/good%20first%20issue) — Simple Perimeter 3 tasks
- [`help wanted`](https://github.com/metadatastician/stealth-glider-ecosystem/labels/help%20wanted) — Community help needed
- [`documentation`](https://github.com/metadatastician/stealth-glider-ecosystem/labels/documentation) — Docs improvements
- [`perimeter-3`](https://github.com/metadatastician/stealth-glider-ecosystem/labels/perimeter-3) — Community sandbox scope

---

## Development Workflow

### Branch Naming
```
docs/short-description       # Documentation (P3)
test/what-added              # Test additions (P3)
feat/short-description       # New features (P2)
fix/issue-number-description # Bug fixes (P2)
refactor/what-changed        # Code improvements (P2)
security/what-fixed          # Security fixes (P1-2)
```

### Commit Messages

We follow [Conventional Commits](https://www.conventionalcommits.org/):
```
<type>(<scope>): <description>

[optional body]

[optional footer]

## Signed commits

Estate policy requires every commit that reaches the default branch to be
signed. If the required-signatures ruleset is active, GitHub refuses unsigned
pushes. Check the live ruleset before relying on this enforcement:
[SIGNING-POLICY](https://github.com/hyperpolymath/standards/blob/main/docs/SIGNING-POLICY.adoc).

- **People and interactive agents** sign with an SSH key registered on GitHub
  as a *signing* key (`gpg.format=ssh`, `user.signingkey=<key>.pub`,
  `commit.gpgsign=true`). The committer email must be verified on that account.
- **Apps, bots and workflows** never `git push` local commits. They write
  through the API (`createCommitOnBranch` or the estate `signed-push` action)
  so that GitHub signs each commit.
- Use **squash** merges as estate policy. If the required-signatures ruleset is
  active, it checks the commits introduced by the pull request, so an unsigned
  commit can block the merge. Re-create such a branch with signed commits
  (`git cherry-pick -S`) and open a new PR. Check the repository's live merge
  settings before stating that rebase merging is disabled.

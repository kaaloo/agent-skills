---
name: local-signing-bridge
description: >-
  Finalizes remote-worker pull request branches from a trusted local machine by recreating or amending the PR diff into locally signed commits. Use when Railway, cloud workers, remote agents, bot accounts, or unsigned commits need to be converted into GitHub-verified commits without exposing a user's private SSH/GPG signing key. Covers: PR branch handoff, local commit signing, force-with-lease updates, and safe remote-worker provenance.
---

# Local Signing Bridge

Use this skill when code was produced in an untrusted or semi-trusted remote environment, but the final PR branch must be signed from a trusted local machine.

Core rule: **never put a user's personal signing key in the remote worker**. Treat Railway/cloud workers as code producers, not personal signing authorities.

## Security model

- Remote worker: edit code, run checks, push a draft branch, write a handoff summary.
- Local trusted machine: fetch the PR branch, inspect the diff, recreate the change as a local signed commit, and update the PR branch with `--force-with-lease`.
- Bot identity: optional for autonomous remote commits, but do not confuse bot-signed commits with personal signed commits.

Read `references/security-model.md` when explaining tradeoffs or designing variants.

## Required preflight

Before modifying a PR branch:

1. Confirm the current environment is trusted and has the user's signing capability available.
2. Inspect the repo state and PR metadata.
3. Require a clean working tree.
4. Preserve or review the remote worker's PR body/handoff notes.
5. Never force-push `main`, `master`, or a protected base branch.
6. Use `--force-with-lease` with the expected remote head SHA, never plain `--force`.

## Preferred helper script

Use `scripts/finalize-pr-branch.sh` from this skill when available. It fetches a same-repository PR branch, replays the PR's merge-base diff onto the current base as one locally signed commit, and optionally force-with-lease updates the PR branch.

Dry run / inspect only:

```bash
bash ~/.letta/skills/local-signing-bridge/scripts/finalize-pr-branch.sh \
  --repo ~/Code/org/repo/main \
  --pr 123 \
  --name "Jane Doe" \
  --email "jane@example.com"
```

Apply and update the PR branch:

```bash
bash ~/.letta/skills/local-signing-bridge/scripts/finalize-pr-branch.sh \
  --repo ~/Code/org/repo/main \
  --pr 123 \
  --name "Jane Doe" \
  --email "jane@example.com" \
  --push
```

For a checked-out PR branch with exactly one intended commit, a manual amend is acceptable:

```bash
GIT_AUTHOR_NAME="Jane Doe" \
GIT_AUTHOR_EMAIL="jane@example.com" \
GIT_COMMITTER_NAME="Jane Doe" \
GIT_COMMITTER_EMAIL="jane@example.com" \
git commit --amend --no-edit --reset-author

git push --force-with-lease origin HEAD:<pr-branch>
```

After pushing, verify GitHub sees the signature:

```bash
sha=$(git rev-parse HEAD)
gh api "repos/<owner>/<repo>/commits/$sha" --jq '.commit.verification'
```

`verified: true` and `reason: valid` are the desired results.

## Remote-worker behavior

If this skill is loaded in Railway or another remote worker that lacks the user's private signing key:

- Do not attempt to sign as the user.
- Do not ask the user to upload their personal signing key.
- Push a draft branch only if the user accepts bot/unsigned provenance, or provide a patch/handoff for local finalization.
- Tell the user to switch to a trusted local environment to run the signing bridge.

## Identity selection

Use the user's project or account preference for the final author/committer identity passed via `--name` and `--email`.

Do not update global Git config from this skill. Prefer command-scoped environment variables or repo-local config only when the user explicitly asks.

## Known limitation

The helper script intentionally squashes the PR into one signed commit by applying a diff from the PR merge base to the PR head. This is safer for stale branches than copying the PR head tree, but it may not preserve rename history as faithfully as a manual commit-by-commit replay. If preserving rename detection or per-commit history is important, use a reviewed manual workflow instead of the helper.

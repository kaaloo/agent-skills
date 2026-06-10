#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Finalize a same-repository PR branch with a locally signed commit.

This script is intended to run on a trusted local machine that already has Git
commit signing configured. It fetches a PR branch, recreates the complete diff
against the PR base as one local signed commit, and optionally updates the PR
branch with --force-with-lease.

Usage:
  finalize-pr-branch.sh --repo PATH --pr NUMBER --name NAME --email EMAIL [--push]

Options:
  --repo PATH          Git worktree path. Defaults to current directory.
  --pr NUMBER          Pull request number to finalize.
  --name NAME          Author/committer name for the signed commit.
  --email EMAIL        Author/committer email for the signed commit.
  --message TEXT       Commit message. Defaults to first PR commit message.
  --message-file PATH  Read commit message from file.
  --remote NAME        Remote to fetch/push. Defaults to origin.
  --push               Force-with-lease update the PR branch after signing.
  --keep-branch        Keep the temporary local signing branch after --push.
  -h, --help           Show this help.

Safety:
  - refuses dirty worktrees
  - refuses fork PRs (same-repository branches only)
  - refuses main/master head branches
  - uses --force-with-lease=<expected-head-sha> when pushing
  - never changes Git config
USAGE
}

repo="$(pwd)"
pr=""
name=""
email=""
message=""
message_file=""
remote="origin"
push=0
keep_branch=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo) repo="${2:?missing --repo value}"; shift 2 ;;
    --pr) pr="${2:?missing --pr value}"; shift 2 ;;
    --name) name="${2:?missing --name value}"; shift 2 ;;
    --email) email="${2:?missing --email value}"; shift 2 ;;
    --message) message="${2:?missing --message value}"; shift 2 ;;
    --message-file) message_file="${2:?missing --message-file value}"; shift 2 ;;
    --remote) remote="${2:?missing --remote value}"; shift 2 ;;
    --push) push=1; shift ;;
    --keep-branch) keep_branch=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; usage >&2; exit 2 ;;
  esac
done

if [ -z "$pr" ] || [ -z "$name" ] || [ -z "$email" ]; then
  echo "--pr, --name, and --email are required" >&2
  usage >&2
  exit 2
fi

for cmd in git gh python3; do
  command -v "$cmd" >/dev/null 2>&1 || { echo "Missing required command: $cmd" >&2; exit 127; }
done

repo=$(cd "$repo" && pwd)
cd "$repo"

git rev-parse --is-inside-work-tree >/dev/null
if [ -n "$(git status --porcelain)" ]; then
  echo "Refusing to run with a dirty working tree: $repo" >&2
  git status --short >&2
  exit 1
fi

repo_slug=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
pr_json=$(mktemp)
trap 'rm -f "$pr_json"' EXIT

gh pr view "$pr" --repo "$repo_slug" \
  --json number,url,title,baseRefName,headRefName,headRefOid,headRepository,headRepositoryOwner,commits \
  > "$pr_json"

IFS=$'\t' read -r pr_number pr_url base_ref head_ref head_oid head_repo first_headline first_body < <(
  python3 - "$pr_json" <<'PY'
import json, sys
p = json.load(open(sys.argv[1]))
head_repo = p.get("headRepository") or {}
head_owner = p.get("headRepositoryOwner") or {}
commits = p.get("commits") or []
first = commits[0] if commits else {}
fields = [
    str(p.get("number") or ""),
    p.get("url") or "",
    p.get("baseRefName") or "",
    p.get("headRefName") or "",
    p.get("headRefOid") or "",
    head_repo.get("nameWithOwner") or head_repo.get("name") or "",
    first.get("messageHeadline") or p.get("title") or "local signed PR finalization",
    first.get("messageBody") or "",
]
print("\t".join(s.replace("\t", " ").replace("\r", "") for s in fields))
PY
)

if [ -z "$base_ref" ] || [ -z "$head_ref" ] || [ -z "$head_oid" ]; then
  echo "Could not resolve PR metadata for PR #$pr" >&2
  exit 1
fi

case "$head_ref" in
  main|master)
    echo "Refusing to rewrite protected-looking head branch: $head_ref" >&2
    exit 1
    ;;
esac

if [ "$head_repo" != "$repo_slug" ]; then
  echo "Refusing fork PR by default: head repo '$head_repo' != local repo '$repo_slug'" >&2
  echo "Use a manual reviewed workflow for fork PRs." >&2
  exit 1
fi

if [ -n "$message_file" ]; then
  message=$(cat "$message_file")
elif [ -z "$message" ]; then
  if [ -n "$first_body" ]; then
    message="$first_headline

$first_body"
  else
    message="$first_headline"
  fi
fi

printf 'Repository: %s\nPR: #%s %s\nBase: %s\nHead: %s @ %s\nIdentity: %s <%s>\n' \
  "$repo_slug" "$pr_number" "$pr_url" "$base_ref" "$head_ref" "$head_oid" "$name" "$email"

original_branch=$(git branch --show-current || true)

git fetch "$remote" \
  "+refs/heads/$base_ref:refs/remotes/$remote/$base_ref" \
  "+refs/heads/$head_ref:refs/remotes/$remote/$head_ref" \
  --prune
base="refs/remotes/$remote/$base_ref"
head="refs/remotes/$remote/$head_ref"

actual_head=$(git rev-parse "$head")
if [ "$actual_head" != "$head_oid" ]; then
  echo "Remote head changed while preparing: expected $head_oid, got $actual_head" >&2
  echo "Re-run after reviewing the new PR state." >&2
  exit 1
fi

if git diff --quiet "$base" "$head"; then
  echo "PR diff is empty; nothing to sign." >&2
  exit 1
fi

safe_head=$(printf '%s' "$head_ref" | tr '/[:space:]' '--' | tr -cd 'A-Za-z0-9._-')
local_branch="local-signing/pr-${pr_number}-${safe_head}-$(date +%Y%m%d%H%M%S)"

git switch --create "$local_branch" "$head" >/dev/null
# Recreate the PR diff as one commit on top of the current base branch.
git reset --soft "$base" >/dev/null

if git diff --cached --quiet; then
  echo "No staged changes after reset; aborting." >&2
  exit 1
fi

GIT_AUTHOR_NAME="$name" \
GIT_AUTHOR_EMAIL="$email" \
GIT_COMMITTER_NAME="$name" \
GIT_COMMITTER_EMAIL="$email" \
git commit -S -m "$message"

new_sha=$(git rev-parse HEAD)
if ! git cat-file -p HEAD | grep -q '^gpgsig '; then
  echo "Commit was created but no signature block was found. Aborting before push." >&2
  exit 1
fi

printf '\nCreated signed commit: %s\n' "$new_sha"
printf '\nDiff summary against base:\n'
git diff --stat "$base" HEAD

if [ "$push" -eq 1 ]; then
  printf '\nUpdating %s with --force-with-lease...\n' "$head_ref"
  git push --force-with-lease="refs/heads/$head_ref:$head_oid" "$remote" "HEAD:refs/heads/$head_ref"
  printf '\nGitHub verification for %s:\n' "$new_sha"
  gh api "repos/$repo_slug/commits/$new_sha" --jq '.commit.verification'
else
  cat <<EOF2

Dry run complete. Review the signed commit above.
To update the PR branch, re-run with --push or execute:
  git push --force-with-lease=refs/heads/$head_ref:$head_oid $remote HEAD:refs/heads/$head_ref
EOF2
fi

if [ "$push" -eq 1 ] && [ "$keep_branch" -eq 0 ] && [ -n "$original_branch" ]; then
  git switch "$original_branch" >/dev/null
  git branch -D "$local_branch" >/dev/null
  printf '\nRemoved temporary local branch: %s\n' "$local_branch"
else
  cat <<EOF3

Temporary local branch kept as current branch: $local_branch
After reviewing/pushing, remove it from another branch with:
  git switch $base_ref
  git branch -D $local_branch
EOF3
fi

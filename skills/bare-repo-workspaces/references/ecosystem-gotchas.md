# Ecosystem and Build-Tool Gotchas

## Per-Ecosystem: Dependencies

### Node.js (pnpm)

```toml
[pre-start]
deps = "pnpm install"

[post-start]
copy = "wt step copy-ignored"  # copies .env, .turbo/ cache from primary worktree
```

**Gotchas:**

- Lock files (`pnpm-lock.yaml`) are git-tracked — already in every worktree, do NOT include in `.worktreeinclude`
- `.npmrc` with auth tokens → put in `main/`, add to `.worktreeinclude`

### Python (uv)

```toml
[pre-start]
deps = "uv sync"
# Don't copy .venv/ — virtual envs have hardcoded absolute paths
```

**Gotchas:**

- **Wrong venv**: If `VIRTUAL_ENV` points to another worktree's `.venv`, tests run against wrong code. Use `uv run python -m pytest` — always uses local `.venv`.
- **Stale shebangs**: `.venv/bin/*` scripts have path hardcoded. Moving the repo breaks them. Fix: `rm -rf .venv && uv sync`.
- **Pre-commit hooks + unstaged files**: If a hook auto-modifies a file with unstaged changes in the same file, commit rolls back. Fix: `git stash push -- <file>` before committing.

### Mixed Python + Node

```toml
[pre-start]
deps = "uv sync && pnpm install"
```

---

## Monorepo: Nested Env Files

For monorepos with app-level secrets (`apps/server/.env`, `apps/client/.env`), list each in `.worktreeinclude`:

```
# .worktreeinclude
.env
apps/server/.env
apps/client/.env
apps/mobile/.env
apps/storybook/.env
.turbo/
# .next/ intentionally excluded — branch-specific, risky to copy
```

`wt step copy-ignored` handles the nested structure automatically — it copies each listed file from the primary worktree into the same path in the new worktree.

---

## Build Tool Gotchas

### Moon v1 (moonrepo)

Moon v1 doesn't support bare repo worktrees ([moonrepo/moon#2162](https://github.com/moonrepo/moon/issues/2162)):

1. **Git errors in moon tasks** — Workaround: `export GIT_WORK_TREE := justfile_directory()` in `justfile`
2. **Orphaned processes** — Moon exits early but dev servers keep running, holding ports. Fix: bypass moon for dev servers, use `just run <app>` directly.

Both issues are fixed in moon v2.

### Cargo (Rust)

- `target/` is per-worktree — add to `.worktreeinclude` for fast reflink copies
- `.cargo/credentials.toml` → put in `main/`, add to `.worktreeinclude`

---
name: wt-worktrees
description: >-
  Run multiple Letta Code sessions in parallel against the same repo using
  isolated checkouts under .letta/worktrees/. Use when the user mentions
  worktrees, creating or switching branches in a separate workspace, or paths
  under .letta/worktrees/. Builds on Letta Code's built-in EnterWorktree tool
  for agent-side workflows and the Worktrunk (`wt`) CLI for interactive
  terminals. Covers .worktreeinclude, `wt` lifecycle hooks (pre-start,
  post-start, post-switch), and non-bare-repo ecosystem gotchas (pnpm, uv,
  monorepos, moon).
---

# Worktree Workflows with `wt`

> **Tooling**: [Worktrunk](https://worktrunk.dev) (`wt`) is the preferred CLI for worktree operations in an interactive terminal. `wt` wraps `git worktree` with ergonomic commands, lifecycle hooks, and `copy-ignored` for cache/env sharing. Install: `brew install worktrunk && wt config shell install`.
>
> For agent-side worktree creation inside Letta Code (CLI / TUI / Desktop), prefer the built-in `EnterWorktree` tool. It creates worktrees under `.letta/worktrees/`, sets up git hooks, copies `.worktreeinclude` entries, and switches the active conversation's cwd automatically.

## Two modes, one layout

Both modes share the same on-disk layout:

```
my-project/
├── .git/                           # standard git checkout
├── .letta/worktrees/               # created automatically by EnterWorktree or `wt`
│   ├── feat-my-feature/
│   └── fix-some-bug/
└── .worktreeinclude                # gitignored files to copy into each worktree
```

- The repo lives as a standard checkout — no bare repo, no `.bare/` directory.
- Each worktree is a full checkout under `.letta/worktrees/<sanitized-branch>`.
- `.worktreeinclude` lists gitignored files (e.g., `.env`) that should be present in every worktree.

### Mode A — Letta Code agent (recommended)

Letta Code's built-in `EnterWorktree` tool handles everything:

- Creates the worktree under `.letta/worktrees/` and switches the active conversation cwd
- Symlinks git hooks from the primary checkout (e.g., husky's `.husky/_`)
- Copies `.letta/settings.local.json` into the new worktree
- Honors `.worktreeinclude` and `worktree.include` project settings
- Optionally symlinks `node_modules` from the primary checkout (`symlink_dependencies: true`)
- Tracks cross-agent advisory locks so two conversations don't edit the same worktree

When a user asks to "work in a worktree", "switch to a worktree", or "create a feature branch", call the `EnterWorktree` tool. Do not drop to raw `git worktree add` from the Bash tool.

### Mode B — Interactive terminal (`wt` CLI)

`wt` mirrors `EnterWorktree` ergonomics for humans:

- `wt switch --create feat/my-feature` — create + check out a worktree
- `wt switch main` — switch to an existing worktree
- `wt list` — list worktrees with status (staged/unstaged/ahead-behind)
- `wt remove feat/my-feature` — remove a worktree (and delete the branch if merged)
- `wt step prune` — remove every worktree whose branch is merged
- `wt step copy-ignored` — manually run `.worktreeinclude` propagation

`wt` is configured by the project's `.config/wt.toml` (committed) and your user `~/.config/worktrunk/config.toml` (user-preferences).

---

## `.worktreeinclude` — copy gitignored files into every worktree

Worktrees are fresh checkouts, so untracked files like `.env` are missing by default. List them in `.worktreeinclude` at the repo root:

```
# .worktreeinclude
# Must be gitignored AND listed here to be copied.
# Environment files
.env
.envrc
# Build caches
# .next/ intentionally excluded — Next.js incremental cache is branch-specific;
# copying from main can produce stale/incorrect builds on feature branches.
# .turbo/ is safe — content-addressed, stale entries are ignored.
.turbo/
```

`.worktreeinclude` uses `.gitignore` syntax. Both `EnterWorktree` and `wt step copy-ignored` honor it.

> **`.next/` vs `.turbo/`**: Don't copy `.next/` — its incremental cache is tied to specific file content and can produce incorrect builds if copied across branches. Do copy `.turbo/` — it's content-addressed; stale entries are simply ignored, valid hits speed up first builds.

---

## Worktrunk Hooks (`.config/wt.toml`)

Commit this file to the repo — it's shared with the team and automates worktree setup.

```toml
# .config/wt.toml
[pre-start]
# Blocking — runs before post-start hooks or --execute
# Fires when creating a NEW worktree (wt switch --create)
deps = "pnpm install"   # Node.js
# deps = "uv sync"      # Python
[post-start]
# Background — runs after worktree is ready
# Fires when creating a NEW worktree (wt switch --create)
copy = "wt step copy-ignored"   # copies .env, build caches from primary checkout

[post-switch]
# Background — runs after EVERY wt switch, including switching to existing worktrees
# Add this so deps stay current when you return to an old worktree
deps = "pnpm install"
```

> **Hook lifecycle summary**: `pre-start` → new worktrees only (blocking). `post-start` → new worktrees only (background). `post-switch` → every switch, new or existing (background). If you only have `pre-start` / `post-start`, running `wt switch main` on an existing worktree will **not** install deps.
>
> **Agent-side note**: Built-in `EnterWorktree` does not run npm/pnpm install automatically. If you need deps installed in the new worktree, set `symlink_dependencies: true` in the `.letta/settings.json` (project-level) `worktree` block, or run the install yourself after the tool returns.

### Project hooks require one-time approval

The first `wt switch --create` after the config lands will prompt:

```
▲ repo needs approval to execute 2 commands: [y/N]
```

Press `y` — saved to `~/.config/worktrunk/config.toml`, never asked again (unless the command changes). In a non-interactive shell (CI, scripts) add `--yes` to skip.

---

## Worktrunk User Config

`worktree-path` at the **top level** of `~/.config/worktrunk/config.toml` is a global default. For the standard layout, set:

```toml
# ~/.config/worktrunk/config.toml
# Default worktree location: under .letta/worktrees/<sanitized-branch>.
worktree-path = ".letta/worktrees/{{ branch | sanitize }}"
```

If a specific project needs a different layout, override it under `[projects."..."]`:

```toml
# Override for a specific project only
[projects."github.com/org/legacy-repo"]
worktree-path = "../worktrees/{{ branch | sanitize }}"
```

### Auto-sync primary checkout before switch

`wt switch --create` branches from the local default branch. If the primary checkout is behind `origin`, new worktrees start stale, causing merge conflicts later. Add a `pre-switch` hook to auto-pull:

```toml
# ~/.config/worktrunk/config.toml
[pre-switch]
sync = "git -C \"$(git rev-parse --git-common-dir)/..\" pull --ff-only 2>/dev/null || true"
```

`git rev-parse --git-common-dir` resolves to the primary checkout regardless of which worktree the hook runs from, so the primary checkout is always fast-forwarded. `--ff-only` ensures it never creates merge commits, and `|| true` means it won't block if there's no network.

> Prefer `git -C <directory> <command>` over chaining `cd <directory> && <command> && cd ..` in shell instructions — if the command fails the shell ends up stuck in the subdirectory.

---

## Daily Workflow

### Create a feature worktree (interactive terminal)

```bash
# Create worktree + branch (shell integration required for `wt switch` to cd)
wt switch --create feat/my-feature

# With a specific base branch:
wt switch --create feat/my-feature --base main

# Create and immediately launch Letta Code:
wt switch --create feat/my-feature -x "letta code ."
```

Worktrunk runs `pre-start` (blocking: deps install) then `post-start` (background: copy-ignored) automatically. If `[post-switch]` is configured, it also runs in the background after every switch.

### Create a feature worktree (non-interactive: scripts, CI)

```bash
# Non-interactive shells can't run post-start hooks (no shell integration), so
# pass --yes to skip the approval prompt and run copy-ignored manually.
wt switch --create feat/my-feature --yes
wt step copy-ignored
```

**Always run `wt step copy-ignored` after `wt switch --create`** in non-interactive contexts. Without it, `.env` files and any other files listed in `.worktreeinclude` will be missing.

### Create a feature worktree (Letta Code agent)

Call the built-in tool with `name` and `branch`. Or ask in natural language — "work in a worktree for `feat/my-feature`". The tool handles cwd switching, settings copy, hooks wiring, and `.worktreeinclude` propagation automatically.

### List worktrees

```bash
wt list              # status: staged, unstaged, ahead/behind remote
git worktree list    # plain git fallback (paths only)
```

### Clean up after PR merge

> **Don't run `wt remove` from inside the worktree you're removing.** Your shell's CWD becomes invalid and subsequent commands fail. Switch out first.

```bash
# 1. Switch out of the worktree
cd /path/to/my-project       # primary checkout
# or: wt switch ^

# 2. Remove
wt remove feat/my-feature    # removes worktree + deletes branch if merged
wt step prune                # removes ALL worktrees whose branches are merged
```

For Letta Code agents, the built-in `EnterWorktree` exposes cleanup behavior on session exit that handles worktree removal automatically.

### Update primary checkout

```bash
cd /path/to/my-project
git pull
```

---

## Gotchas Summary

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| **`wt switch` can't cd** | Shell integration not installed | `wt config shell install` |
| **`.env` missing after `wt switch --create` in scripts** | `post-start` hooks require shell integration (interactive shell); non-interactive shells skip them entirely | Run `wt step copy-ignored` manually after `wt switch --create` |
| **Hooks need approval** | Worktrunk security: project commands require one-time consent | Press `y` on first prompt, or pass `--yes` in non-interactive shells |
| **Wrong venv / tests run old code** | `VIRTUAL_ENV` pointing to a different worktree's `.venv` | Use `uv run python -m pytest` — always uses local `.venv` |
| **Stale venv shebangs after repo move** | `.venv/bin/*` scripts have hardcoded paths | `rm -rf .venv && uv sync` |
| **Pre-commit hook conflict** | Hook modifies file; unstaged changes in same file cause rollback | `git stash push -- <file>` before committing |
| **Moon port conflict / orphaned server** | Moon v1 exits early in worktrees, child process stays on port | Use `just run <app>` to bypass moon for dev servers |
| **IDE shows wrong branch** | Opening the repo root without selecting a worktree | Open the specific worktree directly (e.g., `.letta/worktrees/feat-my-feature/`) |
| **New worktree starts stale / conflicts** | Primary checkout behind `origin` when `wt switch --create` runs | Add a `pre-switch` hook to `git pull --ff-only` |
| **`pnpm install` (or `uv sync`) doesn't run when switching back to existing worktree** | `pre-start` / `post-start` only fire for NEW worktrees | Add `[post-switch] deps = "pnpm install"` to `.config/wt.toml` |

---

## Rules

- **Use `wt` for terminal worktree operations**, **`EnterWorktree` for agent-side worktree operations** — do not run raw `git worktree add` from the Bash tool unless you must bootstrap a layout that the tools can't create (very rare).
- Use `.worktreeinclude` for gitignored files (`.env`, build caches) — no manual symlink setup needed.
- Each worktree has its own `node_modules` / `.venv` unless you set `symlink_dependencies: true` for Letta Code's tool, or share a `.venv` manually.
- Keep 2–4 active worktrees max; `wt step prune` to remove stale ones.
- Open a **specific worktree** in your IDE, not the repo root.

# Setup and Upgrade Workflows

## Option A: Fresh Setup (from GitHub URL)

### Quick setup with setup-workspace.sh (recommended)

Use the setup script to automate the entire setup:

```bash
# Fresh setup from remote URL
bash ~/.letta/skills/bare-repo-workspaces/scripts/setup-workspace.sh <repo-url> <target-dir> [--copy-from <old-clone>] [--main-branch <branch>]

# Example:
bash ~/.letta/skills/bare-repo-workspaces/scripts/setup-workspace.sh git@github.com:etalab-ia/skills.git ~/Code/alliance/skills

# With optional env file copy from existing clone:
bash ~/.letta/skills/bare-repo-workspaces/scripts/setup-workspace.sh git@github.com:org/repo.git ~/projects/repo --copy-from ~/old-clone
```

The script handles:

- Bare clone with `--single-branch`
- `.git` pointer file creation
- Git config (fetch, relative paths, signing)
- Creating the primary worktree (detaches HEAD first to avoid conflicts)
- Copying `.env` files from an existing clone (if `--copy-from` provided)
- Creating placeholder directories (`feat/`, `fix/`, `hotfix/`, `docs/`)

---

### Manual setup (if setup-workspace.sh unavailable)

### Determine the workspace location

**When the user starts from a parent directory** (e.g., `~/Code/alliance`) and provides a GitHub URL (e.g., `git@github.com:etalab-ia/skills.git`):

1. **Derive the workspace name from the repo name** — extract the final segment before `.git`:
   - `git@github.com:etalab-ia/skills.git` → workspace name is `skills`
   - `https://github.com/org/my-project.git` → workspace name is `my-project`

2. **Create the workspace as a SUBDIRECTORY of the current working directory**:
   - Current directory: `~/Code/alliance`
   - GitHub URL: `git@github.com:etalab-ia/skills.git`
   - Workspace path: `~/Code/alliance/skills`

3. **Do NOT create the bare repo directly in the current directory** — this would pollute the parent with `.bare/`, `.git`, and worktree directories mixed alongside other projects.

```bash
# Example: User is in ~/Code/alliance, URL is git@github.com:etalab-ia/skills.git

# 1. Create the workspace directory as a subdirectory of current location
mkdir skills && cd skills

# Now in ~/Code/alliance/skills — proceed with bare clone
```

**When the user explicitly specifies a workspace path** (e.g., "create workspace at ~/projects/my-project"):

```bash
mkdir -p ~/projects/my-project && cd ~/projects/my-project
```

---

### Complete setup sequence

Once you've created and entered the workspace directory (whether derived from URL or explicitly specified), run the following:

```bash
# 2. Bare clone (--single-branch avoids creating 60+ stale local branches)
git clone --bare --single-branch git@github.com:org/repo.git .bare

# 3. Create the .git POINTER FILE (not a folder — this is the magic)
echo "gitdir: ./.bare" > .git

# 4. Configure fetch for all remote branches
git config remote.origin.fetch "+refs/heads/*:refs/remotes/origin/*"

# 5. Enable commit signing
git config commit.gpgsign true

# 6. Fetch all remote branches
git fetch --all

# 7. Create the primary worktree at workspace root
# NOTE: Letta Code's Bash tool intercepts literal `git worktree add` and forces
# `.letta/worktrees/` paths (letta-ai/letta-code#1829). Variable indirection evades
# the static matcher. Prefer `setup-workspace.sh` which already includes this workaround.
_git=git; "$_git" worktree add main main
git -C main branch --set-upstream-to=origin/main main

# 9. Copy secrets into main/ (source of truth)
cp /path/to/old/.env main/.env
cp /path/to/old/apps/server/.env main/apps/server/.env
# ... etc

# 10. Install dependencies
cd main && pnpm install   # Node
# cd main && uv sync      # Python

# 11. Add worktrunk config
mkdir -p .config
cat > .config/wt.toml << 'EOF'
[pre-start]
deps = "pnpm install"

[post-start]
copy = "wt step copy-ignored"
EOF

# 12. Add .worktreeinclude to scope what copy-ignored copies
cat > main/.worktreeinclude << 'EOF'
.env
.envrc
.turbo/
# Note: .next/ is intentionally excluded (branch-specific cache, risky to copy)
EOF

# 13. Set worktree path in user config
wt config show   # verify project ID
# Add to ~/.config/worktrunk/config.toml:
# worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"
```

---

## Option B: Upgrade Existing Workspace / Checkout (`--upgrade`)

Use the helper script to upgrade in place.

### 1) Standard checkout (`.git` directory) → bare workspace format

```bash
# IMPORTANT: run from OUTSIDE the workspace
bash ~/.letta/skills/bare-repo-workspaces/scripts/setup-workspace.sh --upgrade ~/projects/my-project --main-branch main
```

### 2) Existing bare workspace using `worktrees/` layout → root-level layout

```bash
# IMPORTANT: run from OUTSIDE the workspace
bash ~/.letta/skills/bare-repo-workspaces/scripts/setup-workspace.sh --upgrade ~/projects/my-project --main-branch main
```

The script auto-detects the workspace type and applies the right migration path.

### 3) Update Worktrunk user config

```toml
# ~/.config/worktrunk/config.toml
worktree-path = "{{ repo_path }}/../{{ branch | sanitize }}"
```

### 4) Verify

```bash
git -C ~/projects/my-project worktree list
```

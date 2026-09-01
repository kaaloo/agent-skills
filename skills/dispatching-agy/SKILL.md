---
name: dispatching-agy
description: >-
  Dispatches the Antigravity CLI (agy) as a second-opinion or
  parallel-research coding agent, one-shot headless or multi-turn
  stream-json. Use for a second opinion from another model family,
  cross-model code review, parallel research, or when asked to run
  Gemini 3.x Flash / Gemini 3.1 Pro / Claude 4.6 / gpt-oss-120b
  through agy or Antigravity.
---

# Dispatching agy (Antigravity CLI)

Headless dispatch of Google's Antigravity agent CLI. Gives a second model family for second opinions, adversarial review, and parallel research. agy has no memory of your other agent conversations: every prompt must be fully self-contained and in English (Google terms restrict prompts/instructions to English).

## Preconditions

- Verify presence first: `which agy`. Confirmed at `~/.local/bin/agy` (v1.1.18) on macOS; verify before assuming on any host.
- Cheap auth/model check: `agy models >/dev/null 2>&1`
- Headless workspace is NOT the shell cwd: `agy -p` starts in a scratch workspace (`~/.gemini/antigravity-cli/scratch`). Target a repo with `--add-dir <absolute path>` (repeatable; reads and writes there both work, verified). Use absolute paths in prompts — the agent cannot infer "cwd" in headless mode.

## One-shot dispatch

```bash
agy -p "$(cat <<'EOF'
<self-contained English prompt>
EOF
)" \
  --add-dir <repo absolute path> \
  --model gemini-3.7-flash-medium --dangerously-skip-permissions --print-timeout 20m
```

The quoted heredoc keeps prompt text literal: `$(...)`, backticks, and quotes inside the prompt are neither expanded nor corrupted by the local shell, and the command-substitution output is passed to agy verbatim.

Permission handling is mandatory in headless mode — see Headless permissions and workspace.

- Never pass prompt text through plain double quotes — shell syntax in the prompt (`$(cmd)`, backticks) would execute locally. For long or reused prompts, write them to a file and dispatch with `agy -p "$(cat /path/to/prompt.txt)" ...`; file contents are never re-expanded either.

- Reasoning effort is a model-id suffix: `-low`, `-medium`, `-high`.
- Read-only consult (no edits): add `--mode plan`.
- Sandboxed terminal: add `--sandbox` (headless still requires command permission — see Headless permissions and workspace).
- Structured result: `--output-format json`, optionally `--json-schema '<json string or path to schema file>'`.

## Multi-turn session (driver keeps the conversation open)

```bash
agy -p --input-format stream-json --output-format stream-json \
  --add-dir <repo absolute path> --dangerously-skip-permissions --model <model-id>
```

Reads one NDJSON prompt per stdin line, one turn per message (requires agy >= 1.1.15; `stream-json` input requires `stream-json` output).

## Model roster (verified against agy 1.1.18, 2026-08-22)

- `gemini-3.7-flash-{low,medium,high}` — default choice for dispatch
- `gemini-3.6-flash-{low,medium,high}`, `gemini-3.5-flash-{low,medium,high}`
- `gemini-3.1-pro-{high,low}`
- `claude-sonnet-4-6`, `claude-opus-4-6-thinking`, `gpt-oss-120b-medium` — third-party models; usable only if the account plan grants access

## Quota and cost

- Google One AI Pro plan: baseline Antigravity quota refreshes every 5 hours up to a weekly cap. Consumption correlates with agent work done, not prompt count.
- Keep AI-credit overage at Never (`useG1Credits` off in settings, or `/settings` in an interactive session) so exhaustion pauses work instead of silently billing credits.
- Check remaining quota with `/usage` in an interactive session before large dispatches.
- Effort guidance: `medium` for substantial analysis/code work, `low` for quick questions, `high` sparingly.

## Headless permissions and workspace (verified 2026-08-22, agy 1.1.18)

In print mode, tool permission requests are auto-denied — a bare `agy -p` run cannot even execute `pwd`.

- `--mode accept-edits` does NOT cover the shell `command` permission; `--sandbox` does not grant it either.
- Fixes per agy's own error text: add a scoped allow-rule under `permissions.allow` in agy's `settings.json` (e.g. `command(<target>)`), or pass `--dangerously-skip-permissions`.
- Writes persist to the session workspace — scratch by default, plus any `--add-dir` directories (verified in both). Sandbox mode does not change this.
- For one-shot dispatches needing real filesystem effect, use `--add-dir <repo>` + `--dangerously-skip-permissions`, contained by: a clean git checkout, a prompt forbidding unrelated edits, and a post-run `git status` audit.

## Safety

- agy sends code to Google Cloud, and to third-party providers for non-Gemini models. Do not dispatch against work, private, or public-sector repos unless the user has cleared data handling. Personal and open-source repos are generally fine.
- Wrap dispatches in a generous `--print-timeout`; agent runs on real repos routinely exceed the 5m default.

## Troubleshooting

- Run aborts with `Agent execution terminated due to error` and an empty stdout: read `~/.gemini/antigravity-cli/cli.log` — the real cause is a backend/network error, not the prompt. Verified signature: `read: can't assign requested address` on `streamGenerateContent` = the machine's network interface changed mid-run (DHCP/Wi-Fi roam), killing in-flight connections. Fix: wait for a stable network and retry.

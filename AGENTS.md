# Agent Guidance for This Skills Repository

This repository publishes Agent Skills. Keep guidance here focused on skill authoring and validation so it applies across editors, CLIs, and local workspace styles.

## Skill layout

- Shareable skills live under `skills/<skill-name>/`.
- Each skill directory must contain `SKILL.md`.
- `SKILL.md` must start with YAML frontmatter delimited by `---`.
- Required frontmatter fields:
  - `name`: must match the parent directory name.
  - `description`: must explain what the skill does and when to use it.
- Optional support directories inside a skill are limited to:
  - `scripts/` for executable helpers.
  - `references/` for additional documentation loaded on demand.
  - `assets/` for templates and static resources.

## YAML frontmatter gotchas

Skill loaders such as Codex and skills.sh use strict YAML parsing. Avoid unquoted YAML syntax inside scalar fields.

- Long descriptions should use a block scalar:

  ```yaml
  description: >-
    Use when working with PDFs. Covers: extraction, form filling, and merging.
  ```

- Alternatively quote values containing `: `, brackets, braces, or other YAML-significant characters.
- Do not save `SKILL.md` with a UTF-8 BOM before the opening `---` delimiter.
- Keep `description` under 1024 characters.

## Size and structure

- Keep each main `SKILL.md` under 500 lines.
- Move detailed procedures, long examples, or reference material to `references/`.
- Keep bundled scripts deterministic, executable when appropriate, and documented from `SKILL.md`.

## Validation

Run the repository linter before committing or opening a PR:

```bash
scripts/lint-skills.sh
```

The linter is self-contained and validates all `skills/*/` directories using Ruby's standard YAML parser. It is the project quality gate.

The Agent Skills specification documents `skills-ref validate ./my-skill` as the reference validator. Treat `skills-ref` as an optional compatibility check when it is available, not as a required global dependency for this repo.

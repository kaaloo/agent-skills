#!/usr/bin/env bash
# Validate skills in this repository.
#
# Uses the installed skill-linter when available and adds a strict YAML
# frontmatter parse so Codex/skills.sh-compatible YAML errors are caught.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/skills"
VALIDATE_SKILL="${SKILL_LINTER:-$HOME/.agents/skills/skill-linter/scripts/validate-skill.sh}"

status=0

strict_yaml_parse() {
  local skill_file="$1"

  if command -v ruby >/dev/null 2>&1; then
    ruby - "$skill_file" <<'RUBY'
require 'yaml'

path = ARGV.fetch(0)
lines = File.readlines(path, chomp: true)
abort "[FAIL] #{path}: missing opening frontmatter delimiter" unless lines.first == '---'
closing_offset = lines[1..]&.index('---')
abort "[FAIL] #{path}: missing closing frontmatter delimiter" unless closing_offset
frontmatter = lines[1, closing_offset].join("\n")

data = YAML.safe_load(frontmatter, permitted_classes: [], aliases: false)
unless data.is_a?(Hash)
  abort "[FAIL] #{path}: frontmatter must parse to a mapping"
end
%w[name description].each do |field|
  value = data[field]
  if value.nil? || value.to_s.strip.empty?
    abort "[FAIL] #{path}: missing required field #{field.inspect}"
  end
end
puts "[PASS] Strict YAML frontmatter parse: #{path}"
RUBY
    return
  fi

  echo "[FAIL] ruby is required for strict YAML parsing; install ruby or set up a parser" >&2
  return 1
}

if [ "$#" -gt 0 ]; then
  skill_dirs=("$@")
else
  if [ ! -d "$SKILLS_DIR" ]; then
    echo "No skills directory found at $SKILLS_DIR" >&2
    exit 1
  fi
  skill_dirs=("$SKILLS_DIR"/*/)
fi

if [ "${#skill_dirs[@]}" -eq 0 ]; then
  echo "No skills found" >&2
  exit 1
fi

for skill_dir in "${skill_dirs[@]}"; do
  skill_dir="${skill_dir%/}"
  echo
  echo "==> $skill_dir"

  if [ -x "$VALIDATE_SKILL" ]; then
    if ! "$VALIDATE_SKILL" "$skill_dir"; then
      status=1
    fi
  else
    echo "[WARN] skill-linter script not found or not executable: $VALIDATE_SKILL" >&2
  fi

  if ! strict_yaml_parse "$skill_dir/SKILL.md"; then
    status=1
  fi
done

exit "$status"

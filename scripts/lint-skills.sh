#!/usr/bin/env bash
# Validate skills produced by this repository.
#
# This is a self-contained project quality gate. agentskills.io documents
# `skills-ref validate` as the reference validator, but this script avoids
# requiring global installs, network access, PyYAML, or Node dependencies.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_DIR="$ROOT_DIR/skills"

if ! command -v ruby >/dev/null 2>&1; then
  echo "[FAIL] ruby is required for skill linting (uses Ruby stdlib yaml)" >&2
  exit 1
fi

if [ "$#" -gt 0 ]; then
  skill_dirs=("$@")
else
  if [ ! -d "$SKILLS_DIR" ]; then
    echo "[FAIL] No skills directory found at $SKILLS_DIR" >&2
    exit 1
  fi
  mapfile -t skill_dirs < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d | sort)
fi

if [ "${#skill_dirs[@]}" -eq 0 ]; then
  echo "[FAIL] No skills found" >&2
  exit 1
fi

ruby - "${skill_dirs[@]}" <<'RUBY'
require 'yaml'
require 'set'

ALLOWED_FRONTMATTER = Set.new(%w[name description license compatibility metadata allowed-tools])
ALLOWED_DIRS = Set.new(%w[scripts references assets])
NAME_RE = /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/
XML_TAG_RE = /<[^>]+>/

$failures = 0
$warnings = 0

def pass(message)
  puts "[PASS] #{message}"
end

def fail(message)
  $failures += 1
  puts "[FAIL] #{message}"
end

def warn(message)
  $warnings += 1
  puts "[WARN] #{message}"
end

def frontmatter_and_body(path)
  raw = File.binread(path)
  if raw.start_with?("\xEF\xBB\xBF".b)
    fail "#{path}: UTF-8 BOM before frontmatter delimiter can break skill loaders"
    raw = raw.byteslice(3..)
  end

  text = raw.force_encoding('UTF-8')
  unless text.valid_encoding?
    fail "#{path}: file is not valid UTF-8"
    return [nil, nil]
  end

  lines = text.lines(chomp: true)
  unless lines.first == '---'
    fail "#{path}: missing opening frontmatter delimiter"
    return [nil, nil]
  end

  closing_index = lines[1..]&.index('---')
  unless closing_index
    fail "#{path}: missing closing frontmatter delimiter"
    return [nil, nil]
  end

  closing_line = closing_index + 1
  [lines[1...closing_line].join("\n"), lines[(closing_line + 1)..]&.join("\n") || '']
end

def validate_frontmatter(skill_dir, skill_file, frontmatter)
  data = nil
  begin
    data = YAML.safe_load(frontmatter, permitted_classes: [], aliases: false)
  rescue Psych::Exception => e
    fail "#{skill_file}: invalid YAML frontmatter: #{e.message}"
    return nil
  end

  unless data.is_a?(Hash)
    fail "#{skill_file}: frontmatter must parse to a mapping"
    return nil
  end

  unknown = data.keys.map(&:to_s) - ALLOWED_FRONTMATTER.to_a
  warn "#{skill_file}: unknown frontmatter field(s): #{unknown.sort.join(', ')}" unless unknown.empty?

  name = data['name']
  if !name.is_a?(String) || name.strip.empty?
    fail "#{skill_file}: required field 'name' must be a non-empty string"
  else
    name = name.strip
    fail "#{skill_file}: name exceeds 64 characters" if name.length > 64
    fail "#{skill_file}: name must use lowercase letters, digits, and single hyphens" unless name.match?(NAME_RE)
    dir_name = File.basename(skill_dir)
    fail "#{skill_file}: name '#{name}' must match directory '#{dir_name}'" unless name == dir_name
  end

  description = data['description']
  if !description.is_a?(String) || description.strip.empty?
    fail "#{skill_file}: required field 'description' must be a non-empty string"
  else
    description = description.strip
    fail "#{skill_file}: description exceeds 1024 characters" if description.length > 1024
    fail "#{skill_file}: description contains XML-like angle tags" if description.match?(XML_TAG_RE)
    warn "#{skill_file}: description should explain when to use the skill" unless description.match?(/\b(use when|when|trigger|mentions|asks)\b/i)
  end

  compatibility = data['compatibility']
  if compatibility && (!compatibility.is_a?(String) || compatibility.strip.empty? || compatibility.length > 500)
    fail "#{skill_file}: compatibility must be a non-empty string up to 500 characters"
  end

  metadata = data['metadata']
  if metadata
    if !metadata.is_a?(Hash)
      fail "#{skill_file}: metadata must be a mapping"
    else
      metadata.each do |key, value|
        fail "#{skill_file}: metadata key #{key.inspect} must be a string" unless key.is_a?(String)
        fail "#{skill_file}: metadata value for #{key.inspect} must be a string" unless value.is_a?(String)
      end
    end
  end

  allowed_tools = data['allowed-tools']
  if allowed_tools
    if !allowed_tools.is_a?(String)
      fail "#{skill_file}: allowed-tools must be a space-separated string"
    elsif allowed_tools.include?(',') || allowed_tools.include?('[') || allowed_tools.include?(']')
      fail "#{skill_file}: allowed-tools must be space-delimited, not comma-separated or array syntax"
    end
  end

  data
end

def validate_structure(skill_dir, skill_file)
  unless File.file?(skill_file)
    fail "#{skill_dir}: SKILL.md not found"
    return
  end

  line_count = File.readlines(skill_file, chomp: true).length
  if line_count > 500
    fail "#{skill_file}: line count exceeds 500 (#{line_count})"
  else
    pass "Line count: #{line_count}/500"
  end

  Dir.children(skill_dir).sort.each do |entry|
    path = File.join(skill_dir, entry)
    next unless File.directory?(path)
    fail "#{skill_dir}: invalid subdirectory '#{entry}' (allowed: scripts, references, assets)" unless ALLOWED_DIRS.include?(entry)
  end
end

ARGV.each do |skill_dir|
  skill_dir = skill_dir.delete_suffix('/')
  skill_file = File.join(skill_dir, 'SKILL.md')
  puts
  puts "==> #{skill_dir}"

  validate_structure(skill_dir, skill_file)
  next unless File.file?(skill_file)

  frontmatter, _body = frontmatter_and_body(skill_file)
  before = $failures
  validate_frontmatter(skill_dir, skill_file, frontmatter) if frontmatter
  pass "Frontmatter valid: #{skill_file}" if frontmatter && $failures == before
end

puts
if $failures.positive?
  puts "Result: #{$failures} failure(s), #{$warnings} warning(s)"
  exit 1
end

puts "Result: all checks passed#{$warnings.positive? ? " (#{$warnings} warning(s))" : ''}"
RUBY

if command -v skills-ref >/dev/null 2>&1; then
  echo
  echo "Optional reference validation with skills-ref:"
  status=0
  for skill_dir in "${skill_dirs[@]}"; do
    skills-ref validate "$skill_dir" || status=1
  done
  exit "$status"
fi

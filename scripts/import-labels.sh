#!/usr/bin/env bash
# =============================================================================
# import-labels.sh — import PGE labels from .github/labels.yml into a repo
# =============================================================================
#
# `gh label import` is NOT a real gh subcommand, so we parse labels.yml and
# create each label with `gh label create ... --force` (create-or-update).
#
# USAGE
# -----
#   # from your repo root (auto-detects owner/repo from git remote):
#   bash /tmp/ai-workflows-hub/scripts/import-labels.sh
#
#   # or pass the repo and/or an explicit labels file:
#   bash /tmp/ai-workflows-hub/scripts/import-labels.sh --repo OWNER/REPO
#   bash /tmp/ai-workflows-hub/scripts/import-labels.sh --repo OWNER/REPO --file path/to/labels.yml
#
# REQUIREMENTS: gh (authenticated) and ruby.
# =============================================================================

set -euo pipefail

REPO=""
FILE=".github/labels.yml"
for ((i = 1; i <= $#; i++)); do
  case "${!i}" in
    --repo) i=$((i + 1)); REPO="${!i}" ;;
    --file) i=$((i + 1)); FILE="${!i}" ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "Unknown arg: ${!i} (use --help)" >&2; exit 1 ;;
  esac
done

command -v gh   >/dev/null 2>&1 || { echo "✗ gh CLI not found. Install: https://github.com/cli/cli#installation" >&2; exit 1; }
command -v ruby >/dev/null 2>&1 || { echo "✗ ruby not found (needed to parse YAML)." >&2; exit 1; }
[ -f "$FILE" ] || { echo "✗ labels file not found: $FILE" >&2; exit 1; }

# Auto-detect OWNER/REPO from the current git remote when --repo is omitted.
if [ -z "$REPO" ]; then
  REPO="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  [ -n "$REPO" ] || { echo "✗ Could not detect repo. Pass --repo OWNER/REPO." >&2; exit 1; }
fi

echo "Importing labels from $FILE into $REPO …"

ruby -ryaml -e '
file, repo = ARGV
labels = YAML.load_file(file)
labels.each do |l|
  name  = l["name"]
  color = l["color"]
  desc  = l["description"] || ""
  cmd = ["gh", "label", "create", name, "--color", color, "--description", desc, "--repo", repo, "--force"]
  puts "Creating: #{name}"
  system(*cmd) or abort("Failed: #{name}")
end
puts "Done: #{labels.size} labels imported."
' "$FILE" "$REPO"

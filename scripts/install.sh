#!/usr/bin/env bash
# =============================================================================
# install.sh — one-shot PGE onboarding for ai-workflows-hub consumers
# =============================================================================
#
# Copies every PGE template file into a target repo so it can integrate the hub
# with a single command. This handles ALL the file-copy / preparation work:
#   .github/labels.yml
#   .github/ISSUE_TEMPLATE/*
#   .github/workflows/pge-*.yml      (5 trigger workflows)
#   .github/scripts/pge-verify.sh    (executable)
#   .cursor/skills/*                 (all SKILL files)
#   CLAUDE.md                        (from template, never overwritten unless --force)
#
# It does NOT perform the steps that can only be done by a human in a console
# (AWS IAM Role trust policy, creating a GitHub App / bot, adding repo Secrets,
# filling the ACCOUNT_ID / BOT placeholders). Those are printed as a checklist
# at the end.
#
# USAGE
# -----
#   git clone https://github.com/tiankai0114/ai-workflows-hub /tmp/ai-workflows-hub
#   cd /path/to/your-repo
#   bash /tmp/ai-workflows-hub/scripts/install.sh
#
#   # or target an explicit repo dir, and optionally import labels:
#   bash /tmp/ai-workflows-hub/scripts/install.sh /path/to/your-repo --with-labels
#
# ARGS / FLAGS
# ------------
#   [TARGET_DIR]    repo root to install into (default: current directory)
#   --with-labels   run `gh label import` after copying (needs gh authenticated)
#   --force         overwrite an existing CLAUDE.md
#   -h | --help     show this help
# =============================================================================

set -euo pipefail

# ── pretty output ────────────────────────────────────────────────────────────
if [ -t 1 ]; then
  BOLD=$'\033[1m'; DIM=$'\033[2m'; RED=$'\033[31m'; GRN=$'\033[32m'
  YLW=$'\033[33m'; CYN=$'\033[36m'; RST=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; CYN=""; RST=""
fi
info() { printf '%s\n' "${CYN}›${RST} $*"; }
ok()   { printf '%s\n' "${GRN}✓${RST} $*"; }
warn() { printf '%s\n' "${YLW}!${RST} $*"; }
die()  { printf '%s\n' "${RED}✗ $*${RST}" >&2; exit 1; }

# ── parse args ───────────────────────────────────────────────────────────────
TARGET="."
WITH_LABELS=0
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --with-labels) WITH_LABELS=1 ;;
    --force)       FORCE=1 ;;
    -h|--help)     sed -n '2,46p' "$0"; exit 0 ;;
    -*)            die "Unknown flag: $arg (use --help)" ;;
    *)             TARGET="$arg" ;;
  esac
done

# ── locate hub templates (this script lives in <hub>/scripts/) ───────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HUB_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATES="$HUB_ROOT/templates"
[ -d "$TEMPLATES" ] || die "Cannot find templates/ at $TEMPLATES — run this script from a cloned ai-workflows-hub."

# ── resolve target repo ──────────────────────────────────────────────────────
[ -d "$TARGET" ] || die "Target directory does not exist: $TARGET"
TARGET="$(cd "$TARGET" && pwd)"
[ -d "$TARGET/.git" ] || warn "Target is not a git repository root: $TARGET"

printf '\n%s\n' "${BOLD}ai-workflows-hub · PGE onboarding${RST}"
printf '%s\n'   "${DIM}hub:    $HUB_ROOT${RST}"
printf '%s\n\n' "${DIM}target: $TARGET${RST}"

# ── create directories ───────────────────────────────────────────────────────
mkdir -p \
  "$TARGET/.github/ISSUE_TEMPLATE" \
  "$TARGET/.github/workflows" \
  "$TARGET/.github/scripts" \
  "$TARGET/.cursor/skills"

# ── copy: .github files ──────────────────────────────────────────────────────
cp "$TEMPLATES/labels.yml" "$TARGET/.github/labels.yml"
ok ".github/labels.yml"

cp -R "$TEMPLATES/ISSUE_TEMPLATE/." "$TARGET/.github/ISSUE_TEMPLATE/"
ok ".github/ISSUE_TEMPLATE/ ($(find "$TEMPLATES/ISSUE_TEMPLATE" -maxdepth 1 -name '*.yml' | wc -l | tr -d ' ') templates)"

cp "$TEMPLATES"/workflows/pge-*.yml "$TARGET/.github/workflows/"
ok ".github/workflows/ (5 PGE trigger workflows)"

cp "$TEMPLATES/scripts/pge-verify.sh.example" "$TARGET/.github/scripts/pge-verify.sh"
chmod +x "$TARGET/.github/scripts/pge-verify.sh"
ok ".github/scripts/pge-verify.sh (executable, placeholder — customise it)"

# ── copy: .cursor/skills ─────────────────────────────────────────────────────
cp -R "$TEMPLATES/cursor-skills/." "$TARGET/.cursor/skills/"
ok ".cursor/skills/ ($(find "$TEMPLATES/cursor-skills" -maxdepth 1 -mindepth 1 -type d | wc -l | tr -d ' ') skills)"

# ── copy: CLAUDE.md (never clobber unless --force) ───────────────────────────
if [ -f "$TARGET/CLAUDE.md" ] && [ "$FORCE" -ne 1 ]; then
  warn "CLAUDE.md already exists — left untouched (re-run with --force to overwrite)"
else
  cp "$TEMPLATES/CLAUDE.md.template" "$TARGET/CLAUDE.md"
  ok "CLAUDE.md (from template — fill in your project description)"
fi

# ── optional: import PGE labels ──────────────────────────────────────────────
if [ "$WITH_LABELS" -eq 1 ]; then
  if command -v gh >/dev/null 2>&1; then
    info "Importing PGE labels via gh…"
    if ( cd "$TARGET" && gh label import .github/labels.yml ); then
      ok "PGE labels imported"
    else
      warn "gh label import failed — import manually: gh label import .github/labels.yml"
    fi
  else
    warn "gh CLI not found — skipped label import"
  fi
fi

# ── next steps ───────────────────────────────────────────────────────────────
cat <<EOF

${BOLD}✓ Files prepared.${RST} Remaining MANUAL steps (cannot be scripted):

  ${BOLD}1.${RST} AWS IAM Role — add a trust policy allowing this repo via GitHub OIDC,
     and attach bedrock:InvokeModel permission.
  ${BOLD}2.${RST} GitHub App (bot) — create one, install it on this repo, note its
     App ID and numeric bot user id.
  ${BOLD}3.${RST} Repo Secrets — add GH_APP_ID, GH_APP_PRIVATE_KEY (and optionally
     FIGMA_TOKEN) under Settings → Secrets and variables → Actions.
  ${BOLD}4.${RST} Replace placeholders in ${CYN}.github/workflows/pge-*.yml${RST}:
       arn:aws:iam::ACCOUNT_ID:role/YOUR_ROLE_NAME → your role ARN
       YOUR_BOT_ID    → numeric bot user id
       your-app[bot]  → bot username
  ${BOLD}5.${RST} Fill in ${CYN}CLAUDE.md${RST} (tech stack, architecture, commands).
  ${BOLD}6.${RST} Customise ${CYN}.github/scripts/pge-verify.sh${RST} with real build/lint/test.
EOF

if [ "$WITH_LABELS" -ne 1 ]; then
  printf '%s\n' "  ${BOLD}7.${RST} Import labels:  ${CYN}gh label import .github/labels.yml${RST}  (or re-run with --with-labels)"
fi

cat <<EOF
  ${BOLD}8.${RST} Commit & push to the DEFAULT branch:
       git add .github .cursor CLAUDE.md
       git commit -m "chore: integrate ai-workflows-hub PGE"
       git push origin main

See the full guide: docs/onboarding.zh-CN.html
EOF

#!/bin/bash
# The AI Brief — Automated Generation & Deployment
# Runs via macOS launchd at 8am and 9pm CT
# Pipeline: Claude CLI generates edition → Vercel deploys → Twilio notifies subscribers

set -euo pipefail

# ─── Environment ───────────────────────────────────────────────
export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.npm-global/bin:$PATH"

# Source shell profile for additional PATH entries (e.g., nvm, pyenv)
[ -f "$HOME/.zshrc" ] && source "$HOME/.zshrc" 2>/dev/null || true
[ -f "$HOME/.bash_profile" ] && source "$HOME/.bash_profile" 2>/dev/null || true

WORKSPACE="$HOME/the-ai-brief"
SCRIPTS="$WORKSPACE/scripts"
LOGFILE="$SCRIPTS/ai-brief.log"
NOTIFY_SCRIPT="$SCRIPTS/notify-sms.sh"
SITE_URL="https://the-ai-brief-lilac.vercel.app"

# ─── Logging helpers ───────────────────────────────────────────
log() { echo "$(date '+%Y-%m-%d %H:%M:%S'): $*" >> "$LOGFILE"; }
divider() { echo "========================================" >> "$LOGFILE"; }

# ─── Determine edition type ───────────────────────────────────
HOUR=$(date +%H)
if [ "$HOUR" -lt 15 ]; then
  EDITION="morning"
else
  EDITION="evening"
fi
TODAY=$(date +%Y-%m-%d)
EDITION_FILE="$TODAY-$EDITION.html"
EDITION_URL="$SITE_URL/editions/$EDITION_FILE"
EDITION_TITLE="$(echo "$EDITION" | sed 's/./\U&/') Edition — $(date '+%B %d, %Y')"

# ─── Start ─────────────────────────────────────────────────────
divider
log "Starting AI Brief generation ($EDITION edition)..."
log "PATH=$PATH"
log "claude location: $(which claude 2>/dev/null || echo 'NOT FOUND')"

cd "$WORKSPACE" || { log "ERROR — workspace not found at $WORKSPACE"; exit 1; }

# ─── Step 1: Generate edition via Claude Code CLI ──────────────
log "Step 1/3: Generating edition content..."

/usr/local/bin/claude -p \
  "Run the /ai-brief skill now. Generate and deploy the current edition based on the time of day. Follow all steps in the SKILL.md exactly. IMPORTANT: In the <head> of the generated edition HTML, include these Open Graph meta tags for rich link previews:
  <meta property=\"og:type\" content=\"article\">
  <meta property=\"og:title\" content=\"The AI Brief — [Edition Type] Edition — [Date]\">
  <meta property=\"og:description\" content=\"[One-sentence summary of the lead story]\">
  <meta property=\"og:image\" content=\"$SITE_URL/og-image.png\">
  <meta property=\"og:url\" content=\"$SITE_URL/editions/[filename].html\">
  <meta name=\"twitter:card\" content=\"summary_large_image\">
  <meta name=\"twitter:title\" content=\"The AI Brief — [Edition Type] Edition — [Date]\">
  <meta name=\"twitter:description\" content=\"[One-sentence summary of the lead story]\">
  <meta name=\"twitter:image\" content=\"$SITE_URL/og-image.png\">" \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch,TodoWrite" \
  --max-turns 50 \
  >> "$LOGFILE" 2>&1

GEN_EXIT=$?

if [ $GEN_EXIT -ne 0 ]; then
  log "ERROR — Claude generation failed with exit code $GEN_EXIT"
  divider
  exit $GEN_EXIT
fi

log "Step 1/3: Generation complete."

# ─── Step 2: Deploy to Vercel ──────────────────────────────────
log "Step 2/3: Deploying to Vercel..."

DEPLOY_OUTPUT=$(/usr/local/bin/vercel --prod --yes --token="$VERCEL_TOKEN" 2>&1)
DEPLOY_EXIT=$?

if [ $DEPLOY_EXIT -ne 0 ]; then
  log "ERROR — Vercel deploy failed (exit $DEPLOY_EXIT): $DEPLOY_OUTPUT"
  divider
  exit $DEPLOY_EXIT
fi

log "Step 2/3: Deployed. Output: $DEPLOY_OUTPUT"

# ─── Step 3: Notify subscribers via SMS ────────────────────────
log "Step 3/3: Sending SMS notifications..."

if [ -x "$NOTIFY_SCRIPT" ]; then
  "$NOTIFY_SCRIPT" "$EDITION_URL" "$EDITION_TITLE" >> "$LOGFILE" 2>&1
  NOTIFY_EXIT=$?
  if [ $NOTIFY_EXIT -eq 0 ]; then
    log "Step 3/3: SMS notifications sent."
  else
    log "WARNING — SMS notification exited with code $NOTIFY_EXIT (non-fatal)"
  fi
else
  log "Step 3/3: Skipped — notify script not found or not executable at $NOTIFY_SCRIPT"
fi

# ─── Done ──────────────────────────────────────────────────────
log "AI Brief pipeline completed successfully ($EDITION edition)."
divider

#!/bin/bash
# The AI Brief — Generate, Deploy, Notify
# Called by launchd at 8am (morning) and 9pm (evening) CT
#
# How it works:
#   1. Claude CLI generates the edition HTML + updates index.html
#   2. git push triggers Vercel deploy via Git Integration
#   3. Optional: SMS notification via Twilio (if configured)

export PATH="/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin:$HOME/.npm-global/bin:$PATH"

WORKSPACE="$HOME/the-ai-brief"
LOGFILE="$WORKSPACE/scripts/ai-brief.log"
SITE_URL="https://the-ai-brief-lilac.vercel.app"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') — $*" >> "$LOGFILE"; }

# Morning or evening?
HOUR=$(date +%H)
if [ "$HOUR" -lt 15 ]; then EDITION="Morning"; else EDITION="Evening"; fi
TODAY=$(date '+%Y-%m-%d')
DATE_PRETTY=$(date '+%B %d, %Y')
FILENAME="${TODAY}-$(echo $EDITION | tr A-Z a-z).html"

log "=== Starting $EDITION Edition ==="

cd "$WORKSPACE" || { log "ERROR: workspace not found"; exit 1; }

# ── 1. Generate ────────────────────────────────────────────────
log "Generating..."

/usr/local/bin/claude -p "You are generating the $EDITION Edition of The AI Brief for $DATE_PRETTY.

TASK:
1. Search the web for the most important AI news from the last 12 hours
2. Write the edition as a single HTML file at public/editions/$FILENAME
   - Match the exact design/CSS of existing editions in public/editions/
   - Include Open Graph meta tags in <head>:
     <meta property=\"og:type\" content=\"article\">
     <meta property=\"og:title\" content=\"The AI Brief — $EDITION Edition — $DATE_PRETTY\">
     <meta property=\"og:description\" content=\"[one-sentence lead story summary]\">
     <meta property=\"og:image\" content=\"$SITE_URL/og-image.png\">
     <meta property=\"og:url\" content=\"$SITE_URL/editions/$FILENAME\">
     <meta name=\"twitter:card\" content=\"summary_large_image\">
     <meta name=\"twitter:title\" content=\"The AI Brief — $EDITION Edition — $DATE_PRETTY\">
     <meta name=\"twitter:description\" content=\"[one-sentence lead story summary]\">
     <meta name=\"twitter:image\" content=\"$SITE_URL/og-image.png\">
3. Update public/index.html — set the latest-card to this edition and prepend it to the archive list

Read an existing edition first to match the format exactly." \
  --allowedTools "Bash,Read,Write,Edit,Glob,Grep,WebSearch,WebFetch" \
  --max-turns 40 \
  >> "$LOGFILE" 2>&1

if [ $? -ne 0 ]; then
  log "ERROR: Generation failed (exit $?)"
  exit 1
fi

log "Generation complete."

# ── 2. Deploy (git push → Vercel Git Integration) ─────────────
log "Deploying..."

git add public/ >> "$LOGFILE" 2>&1
git commit -m "$EDITION Edition — $DATE_PRETTY" >> "$LOGFILE" 2>&1
git push origin main >> "$LOGFILE" 2>&1

if [ $? -ne 0 ]; then
  log "WARNING: git push failed — deploy may not have triggered"
else
  log "Pushed. Vercel will deploy automatically."
fi

# ── 3. Notify (optional — skips cleanly if Twilio not configured)
EDITION_URL="$SITE_URL/editions/$FILENAME"
NOTIFY="$WORKSPACE/scripts/notify-sms.sh"

if [ -x "$NOTIFY" ] && [ -n "${TWILIO_ACCOUNT_SID:-}" ]; then
  log "Sending SMS notifications..."
  "$NOTIFY" "$EDITION_URL" "$EDITION Edition — $DATE_PRETTY" >> "$LOGFILE" 2>&1
  log "SMS done."
else
  log "SMS skipped (Twilio not configured)."
fi

log "=== $EDITION Edition complete ==="

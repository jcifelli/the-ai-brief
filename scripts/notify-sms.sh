#!/bin/bash
# The AI Brief — Twilio SMS Notification
# Sends a rich-link SMS to all subscribers when a new edition is published.
#
# Usage: ./notify-sms.sh <edition_url> <edition_title>
#
# Required env vars:
#   TWILIO_ACCOUNT_SID   — Twilio account SID
#   TWILIO_AUTH_TOKEN     — Twilio auth token
#   TWILIO_FROM_NUMBER    — Twilio phone number (E.164 format, e.g. +1XXXXXXXXXX)

set -euo pipefail

EDITION_URL="${1:?Usage: notify-sms.sh <edition_url> <edition_title>}"
EDITION_TITLE="${2:?Usage: notify-sms.sh <edition_url> <edition_title>}"

SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBSCRIBERS_FILE="$SCRIPTS_DIR/subscribers.json"

# ─── Validate environment ─────────────────────────────────────
if [ -z "${TWILIO_ACCOUNT_SID:-}" ] || [ -z "${TWILIO_AUTH_TOKEN:-}" ] || [ -z "${TWILIO_FROM_NUMBER:-}" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S'): ERROR — Missing Twilio env vars. Set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER."
  exit 1
fi

if [ ! -f "$SUBSCRIBERS_FILE" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S'): WARNING — No subscribers file at $SUBSCRIBERS_FILE. Skipping."
  exit 0
fi

# ─── Build the message ────────────────────────────────────────
# Keep it concise — SMS has 160 char segments. The URL will generate
# a rich preview card in iMessage/RCS thanks to the OG tags.
MESSAGE="📰 ${EDITION_TITLE}

Read now: ${EDITION_URL}"

# ─── Send to each subscriber ──────────────────────────────────
TWILIO_API="https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json"

SENT=0
FAILED=0

# Parse subscriber list (JSON array of objects with "phone" and optional "name")
NUMBERS=$(python3 -c "
import json, sys
with open('$SUBSCRIBERS_FILE') as f:
    subs = json.load(f)
for s in subs:
    if s.get('active', True):
        print(s['phone'])
" 2>/dev/null)

if [ -z "$NUMBERS" ]; then
  echo "$(date '+%Y-%m-%d %H:%M:%S'): No active subscribers. Skipping."
  exit 0
fi

while IFS= read -r PHONE; do
  RESPONSE=$(curl -s -w "\n%{http_code}" \
    -X POST "$TWILIO_API" \
    -u "${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}" \
    --data-urlencode "To=${PHONE}" \
    --data-urlencode "From=${TWILIO_FROM_NUMBER}" \
    --data-urlencode "Body=${MESSAGE}" 2>&1)

  HTTP_CODE=$(echo "$RESPONSE" | tail -1)
  BODY=$(echo "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "201" ]; then
    SENT=$((SENT + 1))
    echo "$(date '+%Y-%m-%d %H:%M:%S'): ✓ Sent to $PHONE"
  else
    FAILED=$((FAILED + 1))
    echo "$(date '+%Y-%m-%d %H:%M:%S'): ✗ Failed for $PHONE (HTTP $HTTP_CODE)"
  fi
done <<< "$NUMBERS"

echo "$(date '+%Y-%m-%d %H:%M:%S'): SMS complete — $SENT sent, $FAILED failed."

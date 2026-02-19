#!/bin/bash
# The AI Brief — SMS Notification (Twilio)
# Usage: ./notify-sms.sh <url> <title>
# Requires: TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER

URL="${1:?Usage: notify-sms.sh <url> <title>}"
TITLE="${2:?Usage: notify-sms.sh <url> <title>}"
SCRIPTS_DIR="$(cd "$(dirname "$0")" && pwd)"
SUBS="$SCRIPTS_DIR/subscribers.json"

# Bail early if not configured
[ -z "${TWILIO_ACCOUNT_SID:-}" ] && echo "Twilio not configured, skipping." && exit 0
[ ! -f "$SUBS" ] && echo "No subscribers file, skipping." && exit 0

API="https://api.twilio.com/2010-04-01/Accounts/${TWILIO_ACCOUNT_SID}/Messages.json"
MSG=$(printf '\xf0\x9f\x93\xb0 %s\n\n%s' "$TITLE" "$URL")

python3 -c "
import json
with open('$SUBS') as f:
    print('\n'.join(s['phone'] for s in json.load(f) if s.get('active', True)))
" 2>/dev/null | while IFS= read -r PHONE; do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' \
    -X POST "$API" \
    -u "${TWILIO_ACCOUNT_SID}:${TWILIO_AUTH_TOKEN}" \
    --data-urlencode "To=$PHONE" \
    --data-urlencode "From=$TWILIO_FROM_NUMBER" \
    --data-urlencode "Body=$MSG")
  echo "$(date '+%H:%M:%S') $PHONE → $CODE"
done

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

TONE & VOICE:
- Write as if Johnny is personally explaining the news to a smart friend who doesn't work in tech
- Keep the story body text clear and jargon-free — when you must use a technical term, briefly explain it in plain English in the same sentence
- Avoid financial/industry insider language (e.g. instead of \"MoE architecture\" say \"a clever design that only uses a fraction of the model at a time, making it faster and cheaper\")
- The greeting and footer should feel warm and personal — like a note from a friend, not a press release

'WHAT DOES IT MEAN FOR ME?' BOXES — PERSONALIZED BY PROFESSION:
- Every story must end with a highlighted box using the CSS class \"so-what\"
- The label inside must read: \"What does it mean for me?\"
- Each box must contain 9 variants wrapped in <span class=\"so-what-text\" data-profession=\"X\"> tags
- The 11 professions are: general, engineer, teacher, healthcare, finance, legal, business, marketing, student, trades, firstresponder
- The \"general\" variant is visible by default; all others have style=\"display:none\"
- Each variant should speak directly to that profession's real-world concerns in 2-3 sentences
- Address the reader directly (\"you\", \"your\") — plain English, no jargon

Structure for EACH so-what box:
  <div class=\"so-what\"><span class=\"so-what-label\">What does it mean for me?</span>
    <span class=\"so-what-text\" data-profession=\"general\">General text...</span>
    <span class=\"so-what-text\" data-profession=\"engineer\" style=\"display:none\">Engineer text...</span>
    <span class=\"so-what-text\" data-profession=\"teacher\" style=\"display:none\">Teacher text...</span>
    <span class=\"so-what-text\" data-profession=\"healthcare\" style=\"display:none\">Healthcare text...</span>
    <span class=\"so-what-text\" data-profession=\"finance\" style=\"display:none\">Finance text...</span>
    <span class=\"so-what-text\" data-profession=\"legal\" style=\"display:none\">Legal text...</span>
    <span class=\"so-what-text\" data-profession=\"business\" style=\"display:none\">Business owner text...</span>
    <span class=\"so-what-text\" data-profession=\"marketing\" style=\"display:none\">Marketing text...</span>
    <span class=\"so-what-text\" data-profession=\"student\" style=\"display:none\">Student text...</span>
    <span class=\"so-what-text\" data-profession=\"trades\" style=\"display:none\">Trades text...</span>
    <span class=\"so-what-text\" data-profession=\"firstresponder\" style=\"display:none\">First responder text...</span>
  </div>

SHARE LINK — place inside the greeting bar as a float-right link:
  <span class=\"share-link\"><a id=\"sms-share\" href=\"sms:?&body=[URL-encoded single-topic teaser + edition URL]\">Share this edition &rarr;</a></span>

PERSONALIZE BAR — include between the greeting bar and the headlines block:
  <div class=\"personalize-bar\">
    <span class=\"personalize-prompt\">I'm a</span>
    <select id=\"profession-select\" class=\"profession-select\">
      <option value=\"general\">general reader</option>
      <option value=\"engineer\">software engineer</option>
      <option value=\"teacher\">teacher</option>
      <option value=\"healthcare\">nurse</option>
      <option value=\"finance\">investment manager</option>
      <option value=\"legal\">lawyer</option>
      <option value=\"business\">business owner</option>
      <option value=\"marketing\">marketer</option>
      <option value=\"student\">student</option>
      <option value=\"trades\">electrician</option>
      <option value=\"firstresponder\">firefighter</option>
    </select>
    <span class=\"personalize-prompt\">— show me why each story matters for my field.</span>
  </div>

The SMS body should be a URL-encoded single-topic teaser — one punchy sentence about the lead story, then \"This morning's AI Brief has the full story:\" followed by the edition URL ($SITE_URL/editions/$FILENAME). Keep it to one killer hook, not a summary of everything.

DYNAMIC SO-WHAT LABELS — the label text changes based on profession:
  general → \"What does it mean for me?\"
  engineer → \"What does it mean for software engineers?\"
  teacher → \"What does it mean for teachers?\"
  healthcare → \"What does it mean for nurses?\"
  finance → \"What does it mean for investment managers?\"
  legal → \"What does it mean for lawyers?\"
  business → \"What does it mean for business owners?\"
  marketing → \"What does it mean for marketers?\"
  student → \"What does it mean for students?\"
  trades → \"What does it mean for electricians?\"
  firstresponder → \"What does it mean for firefighters?\"

JAVASCRIPT — include at the end of <body>, before </body>:
  <script>
  (function() {
    var labels = { general:'What does it mean for me?', engineer:'What does it mean for software engineers?', teacher:'What does it mean for teachers?', healthcare:'What does it mean for nurses?', finance:'What does it mean for investment managers?', legal:'What does it mean for lawyers?', business:'What does it mean for business owners?', marketing:'What does it mean for marketers?', student:'What does it mean for students?', trades:'What does it mean for electricians?', firstresponder:'What does it mean for firefighters?' };
    var select = document.getElementById('profession-select');
    var allText = document.querySelectorAll('.so-what-text');
    var allLabels = document.querySelectorAll('.so-what-label');
    var saved = localStorage.getItem('ai-brief-profession') || 'general';
    function setProfession(prof) {
      allText.forEach(function(el) { el.style.display = el.dataset.profession === prof ? '' : 'none'; });
      allLabels.forEach(function(el) { el.textContent = labels[prof] || labels.general; });
      select.value = prof;
      localStorage.setItem('ai-brief-profession', prof);
    }
    setProfession(saved);
    select.addEventListener('change', function() { setProfession(select.value); });
  })();
  </script>

Tone example for profession variants:
  BAD (general):  \"The open-source moat of Western AI incumbents is being compressed by Chinese model releases.\"
  GOOD (general): \"A free AI model from China now performs as well as the paid ones. That's good news for anyone building with AI.\"
  GOOD (engineer): \"If you use OpenAI or Anthropic APIs, you now have a free open-source alternative that benchmarks within 2%. Time to evaluate it.\"
  GOOD (teacher): \"Students now have access to a free AI model as capable as ChatGPT. Expect classroom AI use to increase — and your policies to need updating.\"

Read an existing edition first to match the format exactly, then apply these tone guidelines throughout." \
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

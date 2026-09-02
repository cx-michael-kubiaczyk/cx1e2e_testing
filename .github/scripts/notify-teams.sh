#!/usr/bin/env bash
# Posts a run notification to a Microsoft Teams channel via a Power Automate
# "When a Teams webhook request is received" flow. Payload shape follows
# .github/scripts/payload_template.txt (adaptive card with a collapsible
# failed-tests section).
#
# Requires:
#   WEBHOOK_URL - the HTTP POST URL from the Power Automate flow
#                 (set as a GitHub Actions secret; if unset, this script
#                 does nothing so it's safe to leave wired up before the
#                 Teams side exists)
#   STATUS      - passed | unstable | failed
#   EXIT_CODE   - exit code from the suite run
#   RUN_LABEL   - e.g. nightly-main / nightly-staging (defaults to "manual")
#
# Reads the summary/fails files written by run-full-suite.sh:
#   results/<label>-summary.txt - the Ran/FAILED/SKIPPED/PASSED lines
#   results/<label>-fails.txt   - the failing test lines (FAIL x stripped)

set -uo pipefail

if [ -z "${WEBHOOK_URL:-}" ]; then
  echo "WEBHOOK_URL not set - skipping Teams notification"
  exit 0
fi

RUN_LABEL="${RUN_LABEL:-manual}"
STATUS="${STATUS:-unknown}"
EXIT_CODE="${EXIT_CODE:-?}"
SUMMARY_FILE="results/${RUN_LABEL}-summary.txt"
FAILS_FILE="results/${RUN_LABEL}-fails.txt"

SUMMARY_TEXT=""
[ -f "$SUMMARY_FILE" ] && SUMMARY_TEXT=$(cat "$SUMMARY_FILE")
if [ -z "$SUMMARY_TEXT" ]; then
  SUMMARY_TEXT="cx1e2e suite did not produce a results summary (exit code $EXIT_CODE) - it likely crashed before running."
fi

FAIL_TEXT=""
[ -f "$FAILS_FILE" ] && FAIL_TEXT=$(cat "$FAILS_FILE")

case "$RUN_LABEL" in
  nightly-main)    RUN_TITLE="cx1e2e - Main" ;;
  nightly-staging) RUN_TITLE="cx1e2e - Staging" ;;
  *)               RUN_TITLE="cx1e2e - ${RUN_LABEL}" ;;
esac

# ColumnSet + collapsible Container only appear when there are failed tests.
EXTRA_BODY='[]'
if [ -n "$FAIL_TEXT" ]; then
  EXTRA_BODY=$(jq -n --arg fails "$FAIL_TEXT" '[
    {
      type: "ColumnSet",
      spacing: "ExtraSmall",
      columns: [
        {
          type: "Column",
          width: "stretch",
          items: [ { type: "TextBlock", text: "Test Results" } ]
        },
        {
          type: "Column",
          width: "auto",
          spacing: "ExtraSmall",
          verticalContentAlignment: "Top",
          horizontalAlignment: "Right",
          targetWidth: "AtLeast:Standard",
          items: [
            {
              type: "Icon", name: "ChevronDown", size: "xSmall", id: "chevronDown",
              selectAction: {
                type: "Action.ToggleVisibility",
                targetElements: ["e2e_details", "chevronUp", "chevronDown"]
              }
            },
            {
              type: "Icon", name: "ChevronUp", size: "xSmall", id: "chevronUp", isVisible: false,
              selectAction: {
                type: "Action.ToggleVisibility",
                targetElements: ["e2e_details", "chevronUp", "chevronDown"]
              }
            }
          ]
        }
      ]
    },
    {
      type: "Container",
      id: "e2e_details",
      isVisible: false,
      roundedCorners: true,
      showBorder: true,
      style: "emphasis",
      verticalContentAlignment: "Top",
      targetWidth: "AtLeast:Standard",
      spacing: "None",
      items: [
        {
          type: "TextBlock",
          text: $fails,
          size: "Small",
          spacing: "None",
          wrap: false,
          color: "Attention"
        }
      ]
    }
  ]')
fi

PAYLOAD=$(jq -n \
  --arg runTitle "$RUN_TITLE" \
  --arg summary "$SUMMARY_TEXT" \
  --argjson extra "$EXTRA_BODY" \
  '{
    type: "message",
    attachments: [{
      contentType: "application/vnd.microsoft.card.adaptive",
      content: {
        type: "AdaptiveCard",
        "$schema": "http://adaptivecards.io/schemas/adaptive-card.json",
        version: "1.5",
        body: ([
          { type: "TextBlock", text: $runTitle, weight: "Bolder" },
          { type: "TextBlock", text: $summary }
        ] + $extra)
      }
    }]
  }')

HTTP_CODE=$(curl -sS -o /tmp/teams-response.txt -w '%{http_code}' \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  "$WEBHOOK_URL")

echo "Teams webhook responded with HTTP $HTTP_CODE"
cat /tmp/teams-response.txt || true

if [ "$HTTP_CODE" -ge 300 ]; then
  echo "::warning::Teams notification failed (HTTP $HTTP_CODE) - not failing the job over this"
fi

exit 0   # notification failures shouldn't fail the CI run

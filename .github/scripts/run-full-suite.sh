#!/usr/bin/env bash
# Runs the full cx1e2e scenario set against the Canary tenant.
# Expects CANARY_TENANT_URL / CANARY_CLIENT_ID / CANARY_CLIENT_SECRET
# to be set in the environment (populated from secrets in the workflow).
#
# Classifies the run into one of three states (mirrors the Jenkins
# passed/unstable/failed distinction, since GitHub Actions only has
# a binary success/failure job conclusion):
#   passed   - exit code 0
#   unstable - nonzero exit code, but the tool ran to completion
#              (exit code == number of failed tests)
#   failed   - nonzero exit code and no "Ran N tests" summary line,
#              i.e. the tool crashed/didn't run at all
#
# Exposes `status` and `exit_code` as step outputs so the workflow can
# react (fail the job / open a "neutral" check run), and writes a
# markdown summary + ::error:: annotation to the job summary so the
# failing tests are visible without opening the raw log.

set -uo pipefail   # no -e: we need to inspect the exit code ourselves

mkdir -p results
LOGFILE="results/${RUN_LABEL:-manual}-log.txt"

echo "Running cx1e2e full suite (${RUN_LABEL:-manual}) against ${CANARY_CX1_URL} - ${CANARY_TENANT} using ${CANARY_CLIENT_ID}"

(
  cd cx1e2e
  go run . \
    --cx1 "${CANARY_CX1_URL}" \
    --iam "${CANARY_IAM_URL}" \
    --tenant "${CANARY_TENANT}" \
    --client "${CANARY_CLIENT_ID}" \
    --secret "${CANARY_CLIENT_SECRET}" \
    --config ./examples/all.yaml \
    --threads 4 \
    --report-name "../results/${RUN_LABEL:-manual}-report" \
    --log trace \
    --logfile "../${LOGFILE}"
)
EXIT_CODE=$?

if [ "$EXIT_CODE" -eq 0 ]; then
  STATUS=passed
elif grep -q "^Ran [0-9]\+ tests" "$LOGFILE" 2>/dev/null; then
  STATUS=unstable
else
  STATUS=failed
fi

echo "cx1e2e suite finished: status=$STATUS exit_code=$EXIT_CODE"
echo "status=$STATUS"       >> "$GITHUB_OUTPUT"
echo "exit_code=$EXIT_CODE" >> "$GITHUB_OUTPUT"

# ---- Extract the same summary you trim out for the Jenkins email ----
SUMMARY_LINES=""
FAIL_LINES=""
if [ -f "$LOGFILE" ]; then
  SUMMARY_LINES=$(grep -E "^(Ran|FAILED|SKIPPED|PASSED)" "$LOGFILE" || true)
  FAIL_LINES=$(grep "^FAIL x " "$LOGFILE" | sed -E 's/^FAIL x //' || true)
fi

# ---- Job summary (readable markdown, always written) ----
{
  echo "## cx1e2e results (${RUN_LABEL:-manual})"
  echo ""
  echo "**Status:** \`$STATUS\` (exit code $EXIT_CODE)"
  echo ""
  if [ -n "$SUMMARY_LINES" ]; then
    echo '```'
    echo "$SUMMARY_LINES"
    echo '```'
  fi
  if [ -n "$FAIL_LINES" ]; then
    echo ""
    echo "### Failed tests"
    echo ""
    echo '```'
    echo "$FAIL_LINES"
    echo '```'
  fi
} >> "$GITHUB_STEP_SUMMARY"

# ---- ::error:: annotation carrying the same extract, for the checks/PR UI ----
if [ "$STATUS" != "passed" ]; then
  EXTRACT="$SUMMARY_LINES"
  if [ -n "$FAIL_LINES" ]; then
    EXTRACT="${EXTRACT}
${FAIL_LINES}"
  fi
  if [ -z "$EXTRACT" ]; then
    EXTRACT="cx1e2e suite did not produce a results summary (exit code $EXIT_CODE) - it likely crashed before running."
  fi
  # escape for the ::error:: workflow command (%, CR, LF)
  ESCAPED=$(printf '%s' "$EXTRACT" | sed -e 's/%/%25/g' -e 's/\r/%0D/g' | awk '{printf "%s%%0A", $0}')
  echo "::error::${ESCAPED}"
fi

exit 0   # let the step succeed; the workflow decides pass/unstable/fail from `status`

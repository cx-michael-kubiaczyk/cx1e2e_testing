#!/usr/bin/env bash
# Runs the full cx1e2e scenario set against the Canary tenant.
# Expects CANARY_TENANT_URL / CANARY_CLIENT_ID / CANARY_CLIENT_SECRET
# to be set in the environment (populated from secrets in the workflow).
#
# TODO: replace the placeholder invocation below with your actual
# cx1e2e CLI call and scenario set path.

set -euo pipefail

mkdir -p results

echo "Running cx1e2e full suite (${RUN_LABEL:-manual}) against ${CANARY_CX1_URL} - ${CANARY_TENANT} using ${CANARY_CLIENT_ID}"

cd cx1e2e

go run . \
  --cx1 "${CANARY_CX1_URL}" \
  --iam "${CANARY_IAM_URL}" \
  --tenant "${CANARY_TENANT}" \
  --client-id "${CANARY_CLIENT_ID}" \
  --client-secret "${CANARY_CLIENT_SECRET}" \
  --config ./examples/all.yaml \
  --threads 4 \
  --report "../results/${RUN_LABEL:-manual}-report" \
  --log trace \
  --logfile "../results/${RUN_LABEL:-manual}-log.txt" \
  | tee "../results/${RUN_LABEL:-manual}-log.txt"

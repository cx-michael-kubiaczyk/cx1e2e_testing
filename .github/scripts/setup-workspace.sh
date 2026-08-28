#!/usr/bin/env bash
# Usage: ./setup-workspace.sh <cx1clientgo-dir> <cx1e2e-dir>
# Generates a go.work at repo root linking both local checkouts,
# so cx1e2e resolves cx1clientgo to the local checkout instead of
# whatever version is pinned in its go.mod. Never commit the
# resulting go.work file.

set -euo pipefail

CG_DIR="${1:?cx1clientgo dir required}"
E2E_DIR="${2:?cx1e2e dir required}"

cat > go.work <<EOF
go 1.25

use (
    ./${CG_DIR}
    ./${E2E_DIR}
)
EOF

echo "Generated go.work:"
cat go.work

# Sanity check: make sure both modules actually build together
go work sync
go build ./... -C "${E2E_DIR}"

#!/usr/bin/env bash
set -euo pipefail

WEBHOOK_URL="${SLACK_WEBHOOK_URL:?SLACK_WEBHOOK_URL not set}"

CI_ARTIFACTS_DIR=".ci"
MISSING_FILE="${CI_ARTIFACTS_DIR}/missing_ssm_params.txt"

# GitHub context
ACTOR="${GITHUB_ACTOR:-unknown}"
REPO="${GITHUB_REPOSITORY:-unknown}"
RUN_URL="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

if [[ ! -s "$MISSING_FILE" ]]; then
  echo "No missing SSM params file found. Skipping Slack notification."
  exit 0
fi

PARAMS=$(sed 's/^/- /' "$MISSING_FILE")

PAYLOAD=$(cat <<EOF
{
  "text": "🚨 *Missing AWS SSM Parameters Detected*\n\n*Repository:* ${REPO}\n*Developer:* ${ACTOR}\n\n*Missing parameters:*\n${PARAMS}\n\n*Action required:* DevOps team – please create these SSM parameters.\n\n<${RUN_URL}|View CI run>"
}
EOF
)

curl -sS -X POST \
  -H "Content-Type: application/json" \
  --data "$PAYLOAD" \
  "$WEBHOOK_URL" >/dev/null

echo "✅ Slack notification sent."
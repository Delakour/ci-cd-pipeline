#!/usr/bin/env bash
set -euo pipefail

AWS_REGION="${AWS_REGION:-eu-north-1}"
BASE_PATH="/path"

GLOBAL_FILE="scripts/ci/ssm_global_envs.txt"
ENV_FILE="scripts/ci/ssm_env_specific_envs.txt"

ENVIRONMENTS=("dev" "prod")

missing=()

check_param () {
  local param="$1"

  if ! aws ssm get-parameter \
        --name "$param" \
        --with-decryption \
        --region "$AWS_REGION" \
        >/dev/null 2>&1; then
    missing+=("$param")
  fi
}

echo "🔎 Checking SSM parameters existence..."
echo "Region: $AWS_REGION"
echo

# ---- Global params ----
if [[ -f "$GLOBAL_FILE" ]]; then
  echo "🌍 Global parameters:"
  while IFS= read -r VAR; do
    [[ -z "$VAR" || "$VAR" == \#* ]] && continue
    PARAM="${BASE_PATH}/global/${VAR}"
    echo "  - $PARAM"
    check_param "$PARAM"
  done < "$GLOBAL_FILE"
fi

# ---- Env-specific params ----
if [[ -f "$ENV_FILE" ]]; then
  for ENV in "${ENVIRONMENTS[@]}"; do
    echo
    echo "🌱 Environment: $ENV"
    while IFS= read -r VAR; do
      [[ -z "$VAR" || "$VAR" == \#* ]] && continue
      PARAM="${BASE_PATH}/${ENV}/${VAR}"
      echo "  - $PARAM"
      check_param "$PARAM"
    done < "$ENV_FILE"
  done
fi


CI_ARTIFACTS_DIR=".ci"
MISSING_FILE="${CI_ARTIFACTS_DIR}/missing_ssm_params.txt"
mkdir -p "$CI_ARTIFACTS_DIR"
: > "$MISSING_FILE"

# ---- Result ----
if [[ "${#missing[@]}" -gt 0 ]]; then
  echo
  echo "❌ Missing SSM parameters:"
  for p in "${missing[@]}"; do
    echo " - $p"
    echo "$p" >> "$MISSING_FILE"
  done
  echo
  echo "Action required: create these SSM parameters."
  exit 1
fi

echo
echo "✅ All required SSM parameters exist."

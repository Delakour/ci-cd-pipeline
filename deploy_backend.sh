#!/usr/bin/env bash
set -euo pipefail

ENVIRONMENT="${1}"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  BRANCH="main"
  REPO_DIR="/home/ubuntu/backend"
  CONTAINER_NAME="backend-dev"
  IMAGE_TAG="backend:dev"
elif [[ "$ENVIRONMENT" == "prod" ]]; then
  BRANCH="prod"
  REPO_DIR="/opt/backend"
  CONTAINER_NAME="backend-prod"
  IMAGE_TAG="backend:prod"
else
  echo "Unknown ENVIRONMENT: $ENVIRONMENT (expected dev|prod)"
  exit 1
fi

ENV_FILE="${REPO_DIR}/backend.env"
GITHUB_TOKEN_PARAM="/company/global/GITHUB_TOKEN_RAG_SCRAPING"

# ---------------------------------------------------
# Logging setup
# ---------------------------------------------------

LOG_FILE="/home/ubuntu/deploy_backend.log"

mkdir -p "$(dirname "$LOG_FILE")"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$ENVIRONMENT] $*" | tee -a "$LOG_FILE" ; }

chown -R ubuntu:ubuntu "$REPO_DIR"

set -x

log "🚀 Starting deploy (branch=${BRANCH})"

# ---------------------------------------------------
# 1) Update code
# ---------------------------------------------------
log "📂 Switching to repo directory: $REPO_DIR"
cd "$REPO_DIR"

log "🛠 Marking repo as safe for Git..."
git config --global --add safe.directory "$REPO_DIR"

log "🔄 Fetching latest Git changes..."
git fetch origin "$BRANCH"
git checkout "$BRANCH"

log "🧹 Resetting to origin/$BRANCH..."
git reset --hard "origin/$BRANCH"

log "📁 Repository structure after pull:"
ls -la "$REPO_DIR"

# ---------------------------------------------------
# 2) Rebuild env file from SSM
# ---------------------------------------------------

log "🔐 Building env file from SSM"
rm -f "$ENV_FILE"

MONGODB_URL=$(aws ssm get-parameter --name "/company/${ENVIRONMENT,,}/MONGODB_URL" --with-decryption --query 'Parameter.Value' --output text)
MONGODB_NAME=$(aws ssm get-parameter --name "/company/global/MONGODB_NAME" --query 'Parameter.Value' --output text)
DATABASE_NAME=$(aws ssm get-parameter --name "/company/global/DATABASE_NAME" --query 'Parameter.Value' --output text)
OPENAI_API_KEY=$(aws ssm get-parameter --name "/company/global/OPENAI_API_KEY" --with-decryption --query 'Parameter.Value' --output text)
FERNET_KEY=$(aws ssm get-parameter --name "/company/global/FERNET_KEY" --with-decryption --query 'Parameter.Value' --output text)

AWS_ACCESS_KEY_ID=$(aws ssm get-parameter --name "/company/global/AWS_ACCESS_KEY_ID" --with-decryption --query 'Parameter.Value' --output text)
AWS_SECRET_ACCESS_KEY=$(aws ssm get-parameter --name "/company/global/AWS_SECRET_ACCESS_KEY" --with-decryption --query 'Parameter.Value' --output text)
AWS_REGION=$(aws ssm get-parameter --name "/company/global/AWS_REGION" --query 'Parameter.Value' --output text)
S3_LOCAL_FOLDER_BUCKET_NAME=$(aws ssm get-parameter --name "/company/${ENVIRONMENT,,}/S3_LOCAL_FOLDER_BUCKET_NAME" --query 'Parameter.Value' --output text)
S3_BRANDBOOK_BUCKET_NAME=$(aws ssm get-parameter --name "/company/${ENVIRONMENT,,}/S3_BRANDBOOK_BUCKET_NAME" --query 'Parameter.Value' --output text)
S3_STORYPORTAL_BUCKET_NAME=$(aws ssm get-parameter --name "/company/${ENVIRONMENT,,}/S3_STORYPORTAL_BUCKET_NAME" --query 'Parameter.Value' --output text)
GEMINI_API_KEY=$(aws ssm get-parameter --name "/company/global/GEMINI_API_KEY" --with-decryption --query 'Parameter.Value' --output text)
VECTOR_DB_DIR=$(aws ssm get-parameter --name "/company/global/VECTOR_DB_DIR" --query 'Parameter.Value' --output text)

LINKEDIN_CLIENT_ID=$(aws ssm get-parameter --name "/company/global/LINKEDIN_CLIENT_ID" --with-decryption --query 'Parameter.Value' --output text)
LINKEDIN_CLIENT_SECRET=$(aws ssm get-parameter --name "/company/global/LINKEDIN_CLIENT_SECRET" --with-decryption --query 'Parameter.Value' --output text)
LINKEDIN_REDIRECT_URI=$(aws ssm get-parameter --name "/company/${ENVIRONMENT,,}/LINKEDIN_REDIRECT_URI" --query 'Parameter.Value' --output text)
LINKEDIN_SCOPES=$(aws ssm get-parameter --name "/company/global/LINKEDIN_SCOPES" --query 'Parameter.Value' --output text)
LINKEDIN_BASE_URL=$(aws ssm get-parameter --name "/company/global/LINKEDIN_BASE_URL" --query 'Parameter.Value' --output text)
LINKEDIN_API_BASE_URL=$(aws ssm get-parameter --name "/company/global/LINKEDIN_API_BASE_URL" --query 'Parameter.Value' --output text)
LINKEDIN_API_VERSION=$(aws ssm get-parameter --name "/company/global/LINKEDIN_API_VERSION" --query 'Parameter.Value' --output text)
LINKEDIN_RESTLI_PROTOCOL_VERSION=$(aws ssm get-parameter --name "/company/global/LINKEDIN_RESTLI_PROTOCOL_VERSION" --query 'Parameter.Value' --output text)

[[ -z "$MONGODB_URL" ]] && { log "❌ MONGODB_URL missing"; exit 1; }
[[ -z "$OPENAI_API_KEY" ]] && { log "❌ OPENAI_API_KEY missing"; exit 1; }
[[ -z "$FERNET_KEY" ]] && { log "❌ FERNET_KEY missing"; exit 1; }
[[ -z "$GEMINI_API_KEY" ]] && { log "❌ GEMINI_API_KEY missing"; exit 1; }

exec 3>&1 4>&2
exec >/dev/null 2>&1
{
  echo "MONGODB_URL=${MONGODB_URL}"
  echo "MONGODB_NAME=${MONGODB_NAME}"
  echo "DATABASE_NAME=${DATABASE_NAME}"
  echo "OPENAI_API_KEY=${OPENAI_API_KEY}"
  echo "FERNET_KEY=${FERNET_KEY}"

  echo "AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}"
  echo "AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}"
  echo "AWS_REGION=${AWS_REGION}"
  echo "S3_LOCAL_FOLDER_BUCKET_NAME=${S3_LOCAL_FOLDER_BUCKET_NAME}"
  echo "S3_STORYPORTAL_BUCKET_NAME=${S3_STORYPORTAL_BUCKET_NAME}"
  echo "S3_BRANDBOOK_BUCKET_NAME=${S3_BRANDBOOK_BUCKET_NAME}"
  echo "GEMINI_API_KEY=${GEMINI_API_KEY}"
  echo "VECTOR_DB_DIR=${VECTOR_DB_DIR}"

  echo "LINKEDIN_CLIENT_ID=${LINKEDIN_CLIENT_ID}"
  echo "LINKEDIN_CLIENT_SECRET=${LINKEDIN_CLIENT_SECRET}"
  echo "LINKEDIN_REDIRECT_URI=${LINKEDIN_REDIRECT_URI}"
  echo "LINKEDIN_SCOPES=${LINKEDIN_SCOPES}"
  echo "LINKEDIN_BASE_URL=${LINKEDIN_BASE_URL}"
  echo "LINKEDIN_API_BASE_URL=${LINKEDIN_API_BASE_URL}"
  echo "LINKEDIN_API_VERSION=${LINKEDIN_API_VERSION}"
  echo "LINKEDIN_RESTLI_PROTOCOL_VERSION=${LINKEDIN_RESTLI_PROTOCOL_VERSION}"
} > "$ENV_FILE"

exec >&3 2>&4

if aws ssm get-parameter --name '/company/global/CORS_ORIGINS' >/dev/null 2>&1; then
  echo "CORS_ORIGINS=$(aws ssm get-parameter --name '/company/global/CORS_ORIGINS' --query 'Parameter.Value' --output text)" >> "$ENV_FILE"
fi

log "📄 Env file ready"

# ---------------------------------------------------
# 3) Docker build
# ---------------------------------------------------
GITHUB_TOKEN=$(aws ssm get-parameter --name "$GITHUB_TOKEN_PARAM" --with-decryption --query 'Parameter.Value' --output text)

docker build \
  --build-arg GITHUB_TOKEN="$GITHUB_TOKEN" \
  -t "$IMAGE_TAG" .

# ---------------------------------------------------
# 4) Restart container
# ---------------------------------------------------
docker stop "$CONTAINER_NAME" || true
docker rm "$CONTAINER_NAME" || true

docker run -d \
  --name "$CONTAINER_NAME" \
  --restart unless-stopped \
  --env-file "$ENV_FILE" \
  -p 8000:8000 \
  -v /mnt/vector-data:/app/vector_db \
  "$IMAGE_TAG"

log "✅ Deploy completed for $ENVIRONMENT"

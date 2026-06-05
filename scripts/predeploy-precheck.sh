#!/usr/bin/env bash

set -u

RUN_SETUP=1
RUN_API=1
RUN_OLLAMA=1

usage() {
  cat <<'EOF'
Usage: ./scripts/predeploy-precheck.sh [--setup-only | --api-only | --ollama-only | --help]

Environment overrides:
  ENV_FILE             Path to the .env file. Default: <repo>/.env
  BACKEND_URL          Default: http://localhost:${BACKEND_PORT:-8003}
  FRONTEND_URL         Default: http://localhost:${FRONTEND_PORT:-4200}
  OLLAMA_URL           Default: OLLAMA_HOST or OLLAMA_BASE_URL or http://localhost:11434
  PRECHECK_USERNAME    Optional username for token + /me checks
  PRECHECK_PASSWORD    Optional password for token + /me checks
  OLLAMA_CHAT_MODEL    Optional override for the chat model test
  OLLAMA_EMBED_MODEL   Optional override for the embeddings model test

Examples:
  ./scripts/predeploy-precheck.sh
  ./scripts/predeploy-precheck.sh --setup-only
  PRECHECK_USERNAME=admin PRECHECK_PASSWORD=admin ./scripts/predeploy-precheck.sh --api-only
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --setup-only)
      RUN_SETUP=1
      RUN_API=0
      RUN_OLLAMA=0
      ;;
    --api-only)
      RUN_SETUP=0
      RUN_API=1
      RUN_OLLAMA=0
      ;;
    --ollama-only)
      RUN_SETUP=0
      RUN_API=0
      RUN_OLLAMA=1
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 2
      ;;
  esac
  shift
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT_DIR/.env}"
COMPOSE_FILE="$ROOT_DIR/docker-compose.yml"
BACKEND_DOCKERFILE="$ROOT_DIR/gen2kgbot/Dockerfile"
FRONTEND_DOCKERFILE="$ROOT_DIR/q2forge/Dockerfile"

FAILURES=0
WARNINGS=0
PASSES=0

pass() {
  printf '[PASS] %s\n' "$1"
  PASSES=$((PASSES + 1))
}

warn() {
  printf '[WARN] %s\n' "$1"
  WARNINGS=$((WARNINGS + 1))
}

fail() {
  printf '[FAIL] %s\n' "$1"
  FAILURES=$((FAILURES + 1))
}

check_file() {
  local file_path="$1"
  local label="$2"
  if [[ -f "$file_path" ]]; then
    pass "$label exists: $file_path"
  else
    fail "$label is missing: $file_path"
  fi
}

check_command() {
  local command_name="$1"
  if command -v "$command_name" >/dev/null 2>&1; then
    pass "Command available: $command_name"
  else
    fail "Required command not found: $command_name"
  fi
}

source_env_file() {
  if [[ -f "$ENV_FILE" ]]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
    pass "Loaded environment file: $ENV_FILE"
  else
    fail "Environment file not found: $ENV_FILE"
  fi
}

check_non_empty_var() {
  local var_name="$1"
  local value="${!var_name:-}"
  if [[ -n "$value" ]]; then
    pass "Required variable is set: $var_name"
  else
    fail "Required variable is empty or unset: $var_name"
  fi
}

http_get_ok() {
  local url="$1"
  curl -fsS "$url" >/dev/null 2>&1
}

check_contains() {
  local haystack="$1"
  local needle="$2"
  if grep -F "$needle" >/dev/null 2>&1 <<<"$haystack"; then
    return 0
  fi
  return 1
}

source_env_file

BACKEND_URL="${BACKEND_URL:-http://localhost:${BACKEND_PORT:-8003}}"
FRONTEND_URL="${FRONTEND_URL:-http://localhost:${FRONTEND_PORT:-4200}}"
OLLAMA_URL="${OLLAMA_URL:-${OLLAMA_HOST:-${OLLAMA_BASE_URL:-http://localhost:11434}}}"
PRECHECK_USERNAME="${PRECHECK_USERNAME:-}"
PRECHECK_PASSWORD="${PRECHECK_PASSWORD:-}"
OLLAMA_CHAT_MODEL="${OLLAMA_CHAT_MODEL:-${OLLAMA_MODEL:-${LLM_MODEL:-llama3.2:1b}}}"
OLLAMA_EMBED_MODEL="${OLLAMA_EMBED_MODEL:-${EMBEDDING_MODEL:-nomic-embed-text:latest}}"

if [[ $RUN_SETUP -eq 1 ]]; then
  printf '\n== Setup checks ==\n'
  check_command docker
  check_command curl

  if docker compose version >/dev/null 2>&1; then
    pass "docker compose is available"
  else
    fail "docker compose is not available"
  fi

  if docker info >/dev/null 2>&1; then
    pass "Docker daemon is reachable"
  else
    fail "Docker daemon is not reachable"
  fi

  check_file "$COMPOSE_FILE" "Compose file"
  check_file "$BACKEND_DOCKERFILE" "Backend Dockerfile"
  check_file "$FRONTEND_DOCKERFILE" "Frontend Dockerfile"

  check_non_empty_var Q2FORGE_SECRET_KEY
  check_non_empty_var MONGODB_CONNECTION_STRING

  if [[ "${Q2FORGE_SECRET_KEY:-}" == "d7655ea104320f61fc49ac859501609b959501609b9595b994472d473ad736dc0ec657d512" ]]; then
    warn "Q2FORGE_SECRET_KEY still matches the example value"
  fi

  if docker compose -f "$COMPOSE_FILE" config -q >/dev/null 2>&1; then
    pass "docker compose configuration validates successfully"
  else
    fail "docker compose configuration validation failed"
  fi
fi

if [[ $RUN_API -eq 1 ]]; then
  printf '\n== API checks ==\n'
  if http_get_ok "$BACKEND_URL/api/q2forge/openapi.json"; then
    pass "Backend OpenAPI is reachable at $BACKEND_URL/api/q2forge/openapi.json"
  else
    fail "Backend OpenAPI is not reachable at $BACKEND_URL/api/q2forge/openapi.json"
  fi

  if http_get_ok "$BACKEND_URL/api/q2forge/docs"; then
    pass "Backend docs are reachable at $BACKEND_URL/api/q2forge/docs"
  else
    fail "Backend docs are not reachable at $BACKEND_URL/api/q2forge/docs"
  fi

  if [[ -n "$PRECHECK_USERNAME" || -n "$PRECHECK_PASSWORD" ]]; then
    if [[ -z "$PRECHECK_USERNAME" || -z "$PRECHECK_PASSWORD" ]]; then
      fail "PRECHECK_USERNAME and PRECHECK_PASSWORD must either both be set or both be empty"
    else
      auth_body_file="$(mktemp)"
      auth_status="$(
        curl -sS \
          -o "$auth_body_file" \
          -w '%{http_code}' \
          -X POST "$BACKEND_URL/api/q2forge/token" \
          -H 'Content-Type: application/x-www-form-urlencoded' \
          --data-urlencode "username=$PRECHECK_USERNAME" \
          --data-urlencode "password=$PRECHECK_PASSWORD" || true
      )"

      if [[ "$auth_status" == "200" ]]; then
        pass "Token endpoint accepted the provided credentials"
        ACCESS_TOKEN="$(
          sed -nE 's/.*"access_token"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/p' "$auth_body_file" | head -n 1
        )"
        if [[ -n "$ACCESS_TOKEN" ]]; then
          pass "Access token extracted from login response"
          if curl -fsS "$BACKEND_URL/api/q2forge/me" -H "Authorization: Bearer $ACCESS_TOKEN" >/dev/null 2>&1; then
            pass "Protected endpoint /api/q2forge/me is reachable with bearer token"
          else
            fail "Protected endpoint /api/q2forge/me failed with bearer token"
          fi
        else
          fail "Could not extract access token from login response"
        fi
      else
        fail "Token endpoint failed for the provided credentials (HTTP $auth_status)"
      fi

      rm -f "$auth_body_file"
    fi
  else
    warn "Skipping authenticated API checks because PRECHECK_USERNAME/PRECHECK_PASSWORD are not set"
  fi

  if http_get_ok "$FRONTEND_URL/api/q2forge/docs"; then
    pass "Frontend-hosted API docs proxy is reachable at $FRONTEND_URL/api/q2forge/docs"
  else
    warn "Frontend-hosted API docs proxy is not reachable at $FRONTEND_URL/api/q2forge/docs"
  fi
fi

if [[ $RUN_OLLAMA -eq 1 ]]; then
  printf '\n== Ollama checks ==\n'
  tags_body_file="$(mktemp)"
  tags_status="$(
    curl -sS -o "$tags_body_file" -w '%{http_code}' "$OLLAMA_URL/api/tags" || true
  )"

  if [[ "$tags_status" == "200" ]]; then
    pass "Ollama tags endpoint is reachable at $OLLAMA_URL/api/tags"
    OLLAMA_TAGS_RESPONSE="$(cat "$tags_body_file")"

    if check_contains "$OLLAMA_TAGS_RESPONSE" "$OLLAMA_CHAT_MODEL"; then
      pass "Configured chat model is present in Ollama: $OLLAMA_CHAT_MODEL"
    else
      fail "Configured chat model is missing from Ollama: $OLLAMA_CHAT_MODEL"
    fi

    if check_contains "$OLLAMA_TAGS_RESPONSE" "$OLLAMA_EMBED_MODEL"; then
      pass "Configured embedding model is present in Ollama: $OLLAMA_EMBED_MODEL"
    else
      fail "Configured embedding model is missing from Ollama: $OLLAMA_EMBED_MODEL"
    fi
  else
    fail "Ollama tags endpoint is not reachable at $OLLAMA_URL/api/tags (HTTP $tags_status)"
  fi

  rm -f "$tags_body_file"

  chat_body_file="$(mktemp)"
  chat_status="$(
    curl -sS \
      -o "$chat_body_file" \
      -w '%{http_code}' \
      -X POST "$OLLAMA_URL/api/chat" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$OLLAMA_CHAT_MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"hello\"}],\"stream\":false}" || true
  )"

  if [[ "$chat_status" == "200" ]]; then
    if check_contains "$(cat "$chat_body_file")" '"message"'; then
      pass "Ollama chat request succeeded for model $OLLAMA_CHAT_MODEL"
    else
      fail "Ollama chat request returned HTTP 200 but no message payload was detected"
    fi
  else
    fail "Ollama chat request failed for model $OLLAMA_CHAT_MODEL (HTTP $chat_status)"
  fi

  rm -f "$chat_body_file"

  embed_body_file="$(mktemp)"
  embed_status="$(
    curl -sS \
      -o "$embed_body_file" \
      -w '%{http_code}' \
      -X POST "$OLLAMA_URL/api/embeddings" \
      -H 'Content-Type: application/json' \
      -d "{\"model\":\"$OLLAMA_EMBED_MODEL\",\"prompt\":\"hello\"}" || true
  )"

  if [[ "$embed_status" == "200" ]]; then
    if check_contains "$(cat "$embed_body_file")" '"embedding"'; then
      pass "Ollama embeddings request succeeded for model $OLLAMA_EMBED_MODEL"
    else
      fail "Ollama embeddings request returned HTTP 200 but no embedding payload was detected"
    fi
  else
    fail "Ollama embeddings request failed for model $OLLAMA_EMBED_MODEL (HTTP $embed_status)"
  fi

  rm -f "$embed_body_file"
fi

printf '\nSummary: %s passed, %s warnings, %s failed\n' "$PASSES" "$WARNINGS" "$FAILURES"

if [[ $FAILURES -gt 0 ]]; then
  exit 1
fi

exit 0

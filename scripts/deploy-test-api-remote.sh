#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  deploy-test-api-remote.sh --check
  deploy-test-api-remote.sh --image-tag <tag> --ghcr-username <username> --public-host <ip-or-host>

The deploy mode reads the GHCR pull token from standard input. It creates or
preserves a private .env at DEPLOY_PATH and starts PostgreSQL, API and Caddy.
EOF
}

deploy_path="${DEPLOY_PATH:-/opt/recycling-logistics/test}"
image_tag=""
ghcr_username=""
public_host=""
check_only=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)
      check_only=true
      shift
      ;;
    --image-tag)
      image_tag="${2:?Missing value for --image-tag}"
      shift 2
      ;;
    --ghcr-username)
      ghcr_username="${2:?Missing value for --ghcr-username}"
      shift 2
      ;;
    --public-host)
      public_host="${2:?Missing value for --public-host}"
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

command -v docker >/dev/null || {
  printf 'Docker is not installed.\n' >&2
  exit 1
}

docker compose version >/dev/null
test -d "$deploy_path"

if "$check_only"; then
  printf 'Deployment host preflight passed for %s.\n' "$deploy_path"
  exit 0
fi

[[ "$image_tag" =~ ^[A-Za-z0-9._-]+$ ]] || {
  printf 'Invalid image tag.\n' >&2
  exit 2
}
[[ "$ghcr_username" =~ ^[A-Za-z0-9-]+$ ]] || {
  printf 'Invalid GHCR username.\n' >&2
  exit 2
}
[[ "$public_host" =~ ^[A-Za-z0-9.-]+$ ]] || {
  printf 'Invalid public host.\n' >&2
  exit 2
}

read -r ghcr_pull_token
[[ -n "$ghcr_pull_token" ]] || {
  printf 'A GHCR pull token is required.\n' >&2
  exit 1
}

cd "$deploy_path"
test -f docker-compose.test.yml
test -f Caddyfile.test

if [[ ! -f .env ]]; then
  umask 077
  cat >.env <<EOF
API_IMAGE=ghcr.io/dungeoneaters/recycling-backend
POSTGRES_USER=recycling
POSTGRES_PASSWORD=$(openssl rand -hex 32)
POSTGRES_DB=recycling
JWT_SECRET=$(openssl rand -hex 32)
CORS_ORIGINS=http://${public_host}
EOF
fi

chmod 600 .env

if grep -q '^IMAGE_TAG=' .env; then
  sed -i "s/^IMAGE_TAG=.*/IMAGE_TAG=${image_tag}/" .env
else
  printf '\nIMAGE_TAG=%s\n' "$image_tag" >>.env
fi

printf '%s' "$ghcr_pull_token" | docker login ghcr.io --username "$ghcr_username" --password-stdin
unset ghcr_pull_token

docker compose --env-file .env -f docker-compose.test.yml pull
docker compose --env-file .env -f docker-compose.test.yml up -d --remove-orphans

attempt=1
while ((attempt <= 20)); do
  if curl --fail --silent --show-error http://localhost/health >/dev/null; then
    docker compose --env-file .env -f docker-compose.test.yml ps
    exit 0
  fi
  ((attempt += 1))
  sleep 3
done

docker compose --env-file .env -f docker-compose.test.yml ps
docker compose --env-file .env -f docker-compose.test.yml logs --tail=100 >&2
printf 'The API did not become healthy.\n' >&2
exit 1

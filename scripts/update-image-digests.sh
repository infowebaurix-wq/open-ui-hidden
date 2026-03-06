#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/update-image-digests.sh [--check|--dry-run]

Resolves the current manifest digest for the mutable upstream tags pinned in this
repository and either updates them in place, checks for drift, or prints the
planned changes without editing files.
EOF
}

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

mode="update"
case "${1:-}" in
  "")
    ;;
  --check)
    mode="check"
    ;;
  --dry-run)
    mode="dry-run"
    ;;
  -h|--help)
    usage
    exit 0
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

if ! command -v docker >/dev/null 2>&1; then
  fail "docker is required"
fi

if ! docker buildx version >/dev/null 2>&1; then
  fail "docker buildx is required"
fi

declare -a targets=(
  "docker/webui/Dockerfile|ghcr.io/open-webui/open-webui:0.8.8-ollama|ghcr.io/open-webui/open-webui:0.8.8-ollama@sha256:"
  "docker/ollama-proxy/Dockerfile|nginx:1.28-alpine|nginx:1.28-alpine@sha256:"
  "tests/docker-compose.smoke.override.yml|python:3.12-slim|python:3.12-slim@sha256:"
)

resolve_digest() {
  local image="$1"
  local digest

  digest="$(
    docker buildx imagetools inspect "$image" 2>/dev/null \
      | sed -n 's/^Digest:[[:space:]]*//p' \
      | head -n1
  )"

  if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
    fail "unable to resolve a manifest digest for $image"
  fi

  printf '%s\n' "$digest"
}

extract_current_digest() {
  local file="$1"
  local prefix="$2"
  local digest

  digest="$(
    DIGEST_PREFIX="$prefix" perl -ne '
      if (/\Q$ENV{DIGEST_PREFIX}\E([0-9a-f]{64})/) {
        print $1;
        exit 0;
      }
      END { exit 1 if $. == 0 }
    ' "$file" 2>/dev/null || true
  )"

  if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
    fail "unable to locate pinned digest in $file for prefix $prefix"
  fi

  printf '%s\n' "$digest"
}

replace_digest() {
  local file="$1"
  local prefix="$2"
  local digest_without_prefix="$3"

  DIGEST_PREFIX="$prefix" DIGEST_VALUE="$digest_without_prefix" perl -0pi -e '
    my $count = s/\Q$ENV{DIGEST_PREFIX}\E[0-9a-f]{64}/$ENV{DIGEST_PREFIX}.$ENV{DIGEST_VALUE}/ge;
    exit 1 if !$count;
  ' "$file"
}

stale_count=0
updated_count=0

for target in "${targets[@]}"; do
  IFS='|' read -r rel_file image prefix <<<"$target"
  file="$ROOT_DIR/$rel_file"

  [[ -f "$file" ]] || fail "missing file: $file"

  resolved_digest="$(resolve_digest "$image")"
  current_digest="$(extract_current_digest "$file" "$prefix")"
  resolved_without_prefix="${resolved_digest#sha256:}"

  if [[ "$current_digest" == "$resolved_without_prefix" ]]; then
    echo "[digests] up-to-date: $rel_file -> $resolved_digest"
    continue
  fi

  stale_count=$((stale_count + 1))
  echo "[digests] stale: $rel_file"
  echo "           current: sha256:$current_digest"
  echo "           latest:  $resolved_digest"

  if [[ "$mode" == "update" ]]; then
    replace_digest "$file" "$prefix" "$resolved_without_prefix"
    updated_count=$((updated_count + 1))
  fi
done

case "$mode" in
  update)
    if (( updated_count == 0 )); then
      echo "[digests] no updates were required"
    else
      echo "[digests] updated $updated_count file(s)"
    fi
    ;;
  dry-run)
    if (( stale_count == 0 )); then
      echo "[digests] no updates would be required"
    else
      echo "[digests] $stale_count file(s) would change"
    fi
    ;;
  check)
    if (( stale_count == 0 )); then
      echo "[digests] all pinned digests are current"
    else
      fail "$stale_count pinned digest set(s) are stale"
    fi
    ;;
esac

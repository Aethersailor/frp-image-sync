#!/usr/bin/env bash
# Exercise failure boundaries without contacting GitHub, registries, or Docker.
set -euo pipefail
cd "$(dirname "$0")/.."
source scripts/sync.sh
scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
export GITHUB_REPOSITORY=example/frp-image-sync
export EVIDENCE_DIR="$scratch/evidence"
export GITHUB_STEP_SUMMARY="$scratch/summary"
mkdir -p "$EVIDENCE_DIR"
index='{"manifests":[{"platform":{"os":"linux","architecture":"amd64"}},{"platform":{"os":"linux","architecture":"arm64"}}]}'
good="sha256:$(printf '%s' "$index" | sha256sum | cut -d ' ' -f 1)"
bad="sha256:$(printf '0%.0s' {1..64})"

gh() {
  if [[ "$scenario" == prerelease ]]; then
    echo '{"tag_name":"v1.2.3","draft":false,"prerelease":true}'
  else
    echo '{"tag_name":"v1.2.3","draft":false,"prerelease":false}'
  fi
}
regctl() {
  if [[ "$1 $2" == 'image digest' ]]; then
    if [[ "$scenario" == source_missing && "$3" == ghcr.io/fatedier/frps:* ]]; then
      return 1
    fi
    if [[ "$scenario" == retagged && "$3" == ghcr.io/example/frpc:v* ]]; then
      echo "$bad"
    elif [[ "$scenario" == corrupt && "$3" == ghcr.io/example/frps@* ]]; then
      echo "$bad"
    else
      echo "$good"
    fi
  elif [[ "$1 $2" == 'manifest get' ]]; then
    printf '%s' "$index"
  elif [[ "$1 $2" == 'tag ls' ]]; then
    [[ "$scenario" != tag_list_failed ]] || return 1
    [[ "$scenario" != retagged ]] || echo v1.2.3
  elif [[ "$1 $2" == 'image copy' ]]; then
    echo "$*" >> "$scratch/copies"
  else
    echo "Unexpected regctl: $*" >&2
    return 1
  fi
}
# The graph verifier has separate real-registry coverage; retain raw-body comparison.
verify_tree() { printf '%s' "$index" > "$EVIDENCE_DIR/${1##*/}-${2#sha256:}.json"; }
docker() {
  if [[ "$1" == run ]]; then
    [[ "$scenario" != smoke_failed ]] || return 1
    echo 1.2.3
  fi
}

for scenario in prerelease source_missing retagged corrupt tag_list_failed smoke_failed success; do
  : > "$scratch/copies"
  set +e
  (set -e; sync_images) > "$scratch/log" 2>&1
  result=$?
  set -e
  if [[ "$scenario" == success ]]; then
    [[ "$result" == 0 ]] || { cat "$scratch/log"; exit 1; }
    [[ $(grep -c ':latest$' "$scratch/copies") == 2 ]]
    [[ $(grep -c ':v1.2.3$' "$scratch/copies") == 2 ]]
  else
    [[ "$result" != 0 ]] || { echo "Expected failure: $scenario"; exit 1; }
    if grep -Eq ':(latest|v1.2.3)$' "$scratch/copies"; then
      echo "Premature promotion: $scenario"; exit 1
    fi
  fi
  echo "PASS $scenario"
done

#!/usr/bin/env bash
set -euo pipefail

check_digest() {
  local actual
  actual=$(regctl image digest "$1")
  if [[ "$actual" != "$2" ]]; then
    echo "Copy digest mismatch: $1 expected $2, got $actual" >&2
    exit 1
  fi
}

: "${GITHUB_REPOSITORY:?}"
: "${EVIDENCE_DIR:?}"
mkdir -p "$EVIDENCE_DIR"
owner=${GITHUB_REPOSITORY%%/*}
owner=${owner,,}
components=(frpc frps)
declare -A digests

gh api repos/fatedier/frp/releases/latest > "$EVIDENCE_DIR/release.json"
version=$(jq -er 'select(.draft == false and .prerelease == false).tag_name' "$EVIDENCE_DIR/release.json")
[[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]

# Resolve both official images before copying. Trust all official image contents.
for component in "${components[@]}"; do
  digests[$component]=$(regctl image digest "ghcr.io/fatedier/$component:$version")
  [[ "${digests[$component]}" =~ ^sha256:[0-9a-f]{64}$ ]]
  echo "SOURCE ghcr.io/fatedier/$component:$version@${digests[$component]}"
done

# No platform selection or manifest conversion: copy the complete image index.
for component in "${components[@]}"; do
  target="ghcr.io/$owner/$component"
  regctl image copy --force-recursive \
    "ghcr.io/fatedier/$component@${digests[$component]}" "$target:$version"
  check_digest "$target:$version" "${digests[$component]}"
done

# Both copies must match their sources before either latest tag is published.
for component in "${components[@]}"; do
  target="ghcr.io/$owner/$component"
  regctl image copy "$target@${digests[$component]}" "$target:latest"
  check_digest "$target:latest" "${digests[$component]}"
  echo "PUBLISHED $target:$version = $target:latest = ${digests[$component]}"
  jq -n --arg version "$version" --arg source "ghcr.io/fatedier/$component" \
    --arg target "$target" --arg digest "${digests[$component]}" \
    '{version:$version,source:$source,target:$target,source_digest:$digest,version_digest:$digest,latest_digest:$digest}' \
    > "$EVIDENCE_DIR/$component.json"
done

{
  echo "## Official FRP image copies: $version"
  echo
  echo 'Official builds copied unchanged; latest is maintained by this repository.'
  echo
  echo '| Image | Source, version tag, and latest digest |'
  echo '| --- | --- |'
  for component in "${components[@]}"; do
    echo "| ghcr.io/$owner/$component | ${digests[$component]} |"
  done
  echo
  echo "Upstream release: https://github.com/fatedier/frp/releases/tag/$version"
} >> "${GITHUB_STEP_SUMMARY:-/dev/null}"

#!/usr/bin/env bash
set -euo pipefail

fail() { echo "ERROR: $*" >&2; exit 1; }

assert_digest() {
  local actual
  actual=$(regctl image digest "$1")
  [[ "$actual" == "$2" ]] || fail "Digest mismatch: $1 expected $2, got $actual"
}

# Fetch every nested manifest, and check that every referenced blob is available.
# The raw index and child manifests are never rewritten.
verify_tree() {
  local repository=$1 digest=$2 file child
  file="$EVIDENCE_DIR/${repository##*/}-${digest#sha256:}.json"
  regctl manifest get "$repository@$digest" --format raw-body > "$file"
  [[ "sha256:$(sha256sum "$file" | cut -d ' ' -f 1)" == "$digest" ]] || fail "Raw manifest hash mismatch: $repository@$digest"
  if jq -e 'has("manifests")' "$file" > /dev/null; then
    while IFS= read -r child; do
      verify_tree "$repository" "$child"
    done < <(jq -r '.manifests[].digest' "$file")
  else
    jq -e '.config.digest and (.layers | type == "array")' "$file" > /dev/null
    while IFS= read -r child; do
      regctl blob head "$repository" "$child" > /dev/null
    done < <(jq -r '.config.digest, .layers[].digest' "$file")
  fi
}

sync_images() {
  : "${GITHUB_REPOSITORY:?Run in the owning GitHub repository}"
  : "${EVIDENCE_DIR:?Set an evidence directory}"
  mkdir -p "$EVIDENCE_DIR"
  local release version owner component source target digest tags existing output
  local -a components=(frpc frps)
  local -A digests=()
  owner=${GITHUB_REPOSITORY%%/*}
  owner=${owner,,}

  release=$(gh api repos/fatedier/frp/releases/latest)
  jq -e '.draft == false and .prerelease == false' <<< "$release" > /dev/null
  version=$(jq -er '.tag_name' <<< "$release")
  [[ "$version" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Not a stable version: $version"
  jq '{tag_name, html_url, published_at, target_commitish}' <<< "$release" > "$EVIDENCE_DIR/release.json"

  # Resolve BOTH source tags before performing any registry writes.
  for component in "${components[@]}"; do
    source="ghcr.io/fatedier/$component"
    digest=$(regctl image digest "$source:$version")
    [[ "$digest" =~ ^sha256:[0-9a-f]{64}$ ]] || fail "Invalid source digest: $digest"
    digests[$component]=$digest
    regctl manifest get "$source@$digest" --format raw-body > "$EVIDENCE_DIR/$component-source-index.json"
    jq -e '(.manifests | type == "array") and ([.manifests[] | select(.platform.os == "linux")] | length > 1)' \
      "$EVIDENCE_DIR/$component-source-index.json" > /dev/null
    echo "SOURCE $source:$version@$digest"
  done

  # Stage by digest: no version tag or latest is changed here.
  for component in "${components[@]}"; do
    source="ghcr.io/fatedier/$component"
    target="ghcr.io/$owner/$component"
    digest=${digests[$component]}
    regctl image copy --force-recursive "$source@$digest" "$target@$digest"
    assert_digest "$target@$digest" "$digest"
    verify_tree "$target" "$digest"
    cmp "$EVIDENCE_DIR/$component-source-index.json" "$EVIDENCE_DIR/$component-${digest#sha256:}.json"

    # Failure to list tags is fatal; only a successful list establishes absence.
    tags=$(regctl tag ls "$target")
    if grep -Fxq "$version" <<< "$tags"; then
      existing=$(regctl image digest "$target:$version")
      [[ "$existing" == "$digest" ]] || fail "Refusing to overwrite $target:$version: $existing != $digest"
    fi
    # Smoke-test the copied image before promotion. No service or config is used.
    docker pull "$target@$digest"
    output=$(docker run --rm --network none --read-only --cap-drop ALL \
      --security-opt no-new-privileges "$target@$digest" --version)
    [[ "$output" == "${version#v}" ]] || fail "$component version mismatch: $output"
    jq -n --arg component "$component" --arg version "$version" --arg source "$source" \
      --arg target "$target" --arg digest "$digest" --arg output "$output" \
      '{component:$component,version:$version,source:$source,target:$target,digest:$digest,binary_version:$output}' \
      > "$EVIDENCE_DIR/$component.json"
  done

  # Publish version tags only after BOTH staged images pass every check.
  for component in "${components[@]}"; do
    target="ghcr.io/$owner/$component"
    regctl image copy "$target@${digests[$component]}" "$target:$version"
    assert_digest "$target:$version" "${digests[$component]}"
  done

  # Recheck upstream tags before promotion, so an in-flight upstream retag fails closed.
  for component in "${components[@]}"; do
    assert_digest "ghcr.io/fatedier/$component:$version" "${digests[$component]}"
  done
  for component in "${components[@]}"; do
    target="ghcr.io/$owner/$component"
    regctl image copy "$target@${digests[$component]}" "$target:latest"
    assert_digest "$target:latest" "${digests[$component]}"
    echo "VERIFIED $target:$version = $target:latest = ${digests[$component]}"
  done

  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    {
      echo "version=$version"
      echo "frpc=${digests[frpc]}"
      echo "frps=${digests[frps]}"
    } >> "$GITHUB_OUTPUT"
  fi
  if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    {
      echo "## Official FRP image copies: $version"
      echo
      echo "Official builds copied unchanged; latest is maintained by this repository."
      echo
      echo '| Image | Source, version tag, and latest digest |'
      echo '| --- | --- |'
      for component in "${components[@]}"; do
        echo "| ghcr.io/$owner/$component | ${digests[$component]} |"
      done
      echo
      echo 'Both image graphs and binary versions verified before latest promotion.'
      echo "Upstream release: https://github.com/fatedier/frp/releases/tag/$version"
    } >> "$GITHUB_STEP_SUMMARY"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  sync_images
fi

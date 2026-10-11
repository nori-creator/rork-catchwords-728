#!/usr/bin/env bash
# Puts files on the ci-previews branch (where Claude reads CI results), retrying from a fresh clone when another
# workflow pushed in between. Usage: push_ci_previews.sh REPO_URL DEST_DIR "commit message" FILE...
set -uo pipefail
url="$1"; dest="$2"; msg="$3"; shift 3
for attempt in 1 2 3 4 5; do
  work="$(mktemp -d)"
  if git clone --quiet --depth 1 --branch ci-previews "$url" "$work" 2>/dev/null; then
    mkdir -p "$work/$dest"
    cp "$@" "$work/$dest/"
    cd "$work"
    git add -A
    if git -c user.name="ci-previews" -c user.email="ci-previews@users.noreply.github.com" commit --quiet -m "$msg"; then
      git push --quiet origin ci-previews && { cd - >/dev/null; rm -rf "$work"; exit 0; }
    else
      cd - >/dev/null; rm -rf "$work"; exit 0   # nothing changed
    fi
    cd - >/dev/null
  fi
  rm -rf "$work"
  echo "ci-previews: attempt $attempt failed, retrying"
  sleep $(( attempt * 4 + RANDOM % 5 ))
done
echo "::warning::ci-previews に置けませんでした（他のワークフローと重なった可能性）。結果は実行の Summary にあります。"
exit 0

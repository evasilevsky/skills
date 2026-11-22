#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script, intended for use by maintainers of this repo.
# It is not a supported installer. Modifications to it, or requests for
# modifications, will not be approved.
#
# Links all skills in the repository into the local skill directories used by
# each agent harness:
#   - ~/.claude/skills: Claude Code
#   - ~/.agents/skills: Codex and other Agent Skills-compatible harnesses
# Each entry is a symlink into this repo, so a `git pull` is all that's needed
# to keep installed skills up to date.

DRY_RUN=0
for arg in "$@"; do
  case "$arg" in
    --dry-run)
      DRY_RUN=1
      ;;
    -h|--help)
      echo "Usage: $0 [--dry-run]"
      exit 0
      ;;
    *)
      echo "error: unknown argument: $arg" >&2
      echo "Usage: $0 [--dry-run]" >&2
      exit 1
      ;;
  esac
done

canonicalize_path() {
  local p="$1"
  if realpath -m -- "$p" >/dev/null 2>&1; then
    realpath -m -- "$p"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.realpath(sys.argv[1]))' "$p"
  else
    local dir base
    dir="$(dirname -- "$p")"
    base="$(basename -- "$p")"
    if [ -d "$dir" ]; then
      printf '%s/%s\n' "$(cd -P -- "$dir" && pwd -P)" "$base"
    else
      printf '%s\n' "$p"
    fi
  fi
}

canonicalize_lexical() {
  local p="$1"
  if realpath -m -s -- "$p" >/dev/null 2>&1; then
    realpath -m -s -- "$p"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -c 'import os, sys; print(os.path.normpath(os.path.abspath(sys.argv[1])))' "$p"
  else
    printf '%s\n' "$p"
  fi
}

validate_skill_name() {
  local name="$1"
  if [ -z "$name" ] || [ "$name" = "." ] || [ "$name" = ".." ]; then
    echo "error: refusing unsafe skill name: '$name'" >&2
    exit 1
  fi
  case "$name" in
    */*|*\\*)
      echo "error: refusing unsafe skill name containing path separator: '$name'" >&2
      exit 1
      ;;
  esac
}

assert_strictly_inside() {
  local dest_real="$1"
  local candidate="$2"
  if [ -z "$dest_real" ] || [ "$dest_real" = "/" ]; then
    echo "error: refusing unsafe destination directory: '$dest_real'" >&2
    exit 1
  fi
  case "$candidate" in
    "$dest_real"/*)
      if [ "$candidate" = "$dest_real" ]; then
        echo "error: target resolves to destination root: $candidate" >&2
        exit 1
      fi
      ;;
    *)
      echo "error: refusing target outside destination ($dest_real): $candidate" >&2
      exit 1
      ;;
  esac
}

REPO="$(cd -P "$(dirname "$0")/.." && pwd -P)"
DESTS=("$HOME/.claude/skills" "$HOME/.agents/skills")

# Collect the repo's skills once, link into every destination. `deprecated/`
# is retired, and `misc/` is kept around but rarely used and not promoted (see
# each bucket's own README): neither belongs in a daily-driver skill
# directory, so both are skipped here, same as everywhere else non-promoted
# skills are kept out. `in-progress/` IS still linked: it's public on purpose,
# feedback wanted, and this local install is exactly where that feedback loop
# runs.
names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  name="$(basename "$src")"
  validate_skill_name "$name"
  names+=("$name")
  srcs+=("$src")
done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -not -path '*/deprecated/*' -not -path '*/misc/*' -print0)

for DEST in "${DESTS[@]}"; do
  # If $DEST is a symlink that resolves into this repo, we'd end up writing the
  # per-skill symlinks back into the repo's own skills/ tree. Detect and bail
  # out instead of polluting the working copy.
  if [ -L "$DEST" ]; then
    resolved="$(canonicalize_path "$DEST")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $DEST is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$DEST\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  dest_real="$(canonicalize_path "$DEST")"
  dest_real="${dest_real%/}"
  if [ -z "$dest_real" ] || [ "$dest_real" = "/" ]; then
    echo "error: refusing unsafe destination path: $DEST" >&2
    exit 1
  fi

  if [ "$DRY_RUN" -eq 1 ]; then
    if [ ! -d "$DEST" ]; then
      echo "[dry-run] mkdir -p $dest_real"
    fi
  else
    mkdir -p "$DEST"
    dest_real="$(canonicalize_path "$DEST")"
    dest_real="${dest_real%/}"
  fi

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    validate_skill_name "$name"

    target="$dest_real/$name"
    target_lexical="$(canonicalize_lexical "$target")"
    assert_strictly_inside "$dest_real" "$target_lexical"

    if [ -d "$target" ] && [ ! -L "$target" ]; then
      target_real="$(canonicalize_path "$target")"
      assert_strictly_inside "$dest_real" "$target_real"
      file_count="$(find "$target_real" -type f | wc -l | tr -d ' ')"
      echo "WARNING: replacing real directory $target_real ($file_count files) with a symlink into $REPO; local edits inside $target_real will be permanently deleted." >&2
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] would replace real directory $target_real ($file_count files) and link $name -> $src"
        continue
      fi
      rm -rf -- "$target_real"
    elif [ -e "$target" ] && [ ! -L "$target" ]; then
      target_real="$(canonicalize_path "$target")"
      assert_strictly_inside "$dest_real" "$target_real"
      echo "WARNING: replacing real file $target_real with a symlink into $REPO; local edits to $target_real will be permanently deleted." >&2
      if [ "$DRY_RUN" -eq 1 ]; then
        echo "[dry-run] would replace real file $target_real and link $name -> $src"
        continue
      fi
      rm -f -- "$target_real"
    elif [ "$DRY_RUN" -eq 1 ]; then
      echo "[dry-run] would link $target -> $src"
      continue
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($dest_real)"
  done
done

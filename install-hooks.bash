#!/bin/bash
set -euo pipefail

# Install git hooks by symlinking from scripts/git-hooks to .git/hooks
# This allows hooks to be version controlled while being active in the repository

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$SCRIPT_DIR"
readonly HOOKS_SOURCE_DIR="$SCRIPT_DIR/git-hooks"
readonly HOOKS_TARGET_DIR="$REPO_ROOT/.git/hooks"

install_hook() {
  local hook_name="$1"
  local source_hook="$HOOKS_SOURCE_DIR/$hook_name"
  local target_hook="$HOOKS_TARGET_DIR/$hook_name"

  if [[ ! -f "$source_hook" ]]; then
    echo "ERROR: Source hook not found: $source_hook"
    return 1
  fi

  # Remove existing hook or symlink
  if [[ -e "$target_hook" ]] || [[ -L "$target_hook" ]]; then
    echo "Removing existing $hook_name hook..."
    rm "$target_hook"
  fi

  # Create symlink
  ln -s "$source_hook" "$target_hook"
  echo "✓ Installed $hook_name hook"
}

main() {
  echo "======================================"
  echo "Installing Git Hooks"
  echo "======================================"
  echo ""

  if [[ ! -d "$HOOKS_TARGET_DIR" ]]; then
    echo "ERROR: .git/hooks directory not found"
    echo "Are you in a git repository?"
    exit 1
  fi

  install_hook "pre-commit"

  echo ""
  echo "======================================"
  echo "Git hooks installed successfully!"
  echo "======================================"
}

main "$@"

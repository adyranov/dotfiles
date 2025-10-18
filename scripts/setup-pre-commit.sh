#!/usr/bin/env sh
set -eu

# Bootstraps pre-commit in a repo-local virtualenv and installs the Git hook.

script_dir=$(
  cd "$(dirname "$0")" >/dev/null 2>&1 && pwd
)
repo_root=$(
  cd "$script_dir/.." >/dev/null 2>&1 && pwd
)

venv_dir=${VENV_DIR:-"$repo_root/.venv"}

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required but not found on PATH." >&2
  exit 1
fi

if [ ! -d "$repo_root/.git" ]; then
  echo "No Git repository found under $repo_root" >&2
  exit 1
fi

if [ ! -d "$venv_dir" ]; then
  python3 -m venv "$venv_dir"
fi

"$venv_dir/bin/python" -m pip install --upgrade pip pre-commit

cd "$repo_root"
"$venv_dir/bin/pre-commit" install --install-hooks --hook-type pre-commit

echo "pre-commit installed using virtualenv at $venv_dir"

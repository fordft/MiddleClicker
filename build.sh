#!/bin/zsh
set -eu
task_repo_dir="$(cd "$(dirname "$0")" && pwd)"
exec /usr/bin/python3 "$task_repo_dir/scripts/build.py"

#!/usr/bin/env bash
# DocGraph 開発コマンドランナー (make 不要)
# 使い方:
#   bash dev.sh install
#   bash dev.sh check
#   bash dev.sh lint
#   bash dev.sh fix
#   bash dev.sh test

set -e

CMD="${1:-help}"

case "$CMD" in
    install)
        uv sync --all-extras
        ;;
    lint)
        uv run ruff check src tests
        ;;
    fix)
        uv run ruff check --fix src tests
        uv run ruff format src tests
        ;;
    format)
        uv run ruff format src tests
        ;;
    type)
        uv run mypy src
        ;;
    security)
        uv run bandit -c bandit.yaml -r src
        ;;
    dead)
        uv run vulture src .vulture_whitelist.py --min-confidence 80
        ;;
    complexity)
        uv run radon cc src -a -nc
        uv run radon mi src -nc
        ;;
    deps)
        uv run deptry src
        ;;
    test)
        uv run pytest
        ;;
    check)
        bash scripts/check.sh
        ;;
    hooks)
        uv run pre-commit install
        uv run pre-commit run --all-files
        ;;
    help|*)
        cat <<'HELP'
DocGraph dev commands

  bash dev.sh install     - uv sync (--all-extras)
  bash dev.sh lint        - Ruff lint (no fix)
  bash dev.sh fix         - Ruff lint --fix + format
  bash dev.sh format      - Ruff format only
  bash dev.sh type        - mypy strict
  bash dev.sh security    - bandit
  bash dev.sh dead        - vulture (dead code)
  bash dev.sh complexity  - radon (CC + MI)
  bash dev.sh deps        - deptry
  bash dev.sh test        - pytest
  bash dev.sh check       - すべて実行 (scripts/check.sh)
  bash dev.sh hooks       - pre-commit install + run all files
HELP
        ;;
esac

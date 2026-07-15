#!/usr/bin/env bash
# DocGraph 品質チェック一括実行
# ローカル / CI どちらでも使える

set -e

C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_RED='\033[31m'
C_OFF='\033[0m'

run() {
    local name="$1"; shift
    printf "\n${C_CYAN}▶ %s${C_OFF}\n" "$name"
    if "$@"; then
        printf "${C_GREEN}✔ %s passed${C_OFF}\n" "$name"
    else
        printf "${C_RED}✘ %s failed${C_OFF}\n" "$name"
        exit 1
    fi
}

run "Ruff lint"       uv run ruff check src tests
run "Ruff format"     uv run ruff format --check src tests
run "mypy"            uv run mypy src
run "bandit"          uv run bandit -c bandit.yaml -r src
run "vulture"         uv run vulture src .vulture_whitelist.py --min-confidence 80
run "radon (CC)"      uv run radon cc src -a -nc
run "radon (MI)"      uv run radon mi src -nc
run "deptry"          uv run deptry src
run "pytest"          uv run pytest

printf "\n${C_GREEN}All checks passed.${C_OFF}\n"

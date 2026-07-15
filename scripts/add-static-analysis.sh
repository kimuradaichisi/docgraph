#!/usr/bin/env bash
# ============================================================
# DocGraph 静的解析ツール追加スクリプト
#
# 追加するもの:
#   - bandit    : セキュリティ静的解析
#   - vulture   : デッドコード検出
#   - radon     : 循環的複雑度計測
#   - deptry    : 依存関係診断
#   - pre-commit: フック管理
#   - .pre-commit-config.yaml
#   - bandit.yaml
#   - scripts/check.sh (全チェックを一発実行)
#   - Makefile
#
# 使い方:
#   bash add-static-analysis.sh
#   bash add-static-analysis.sh -f          # 既存を上書き
# ============================================================

set -euo pipefail

ROOT="$(pwd)"
FORCE=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--root) ROOT="$2"; shift 2 ;;
        -f|--force) FORCE=1; shift ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
done

C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_OFF='\033[0m'

section() { printf "\n${C_CYAN}=== %s ===${C_OFF}\n" "$1"; }
ok()      { printf "${C_GREEN}[OK]${C_OFF} %s\n" "$1"; }
skip()    { printf "${C_YELLOW}[SKIP]${C_OFF} %s\n" "$1"; }

write_file() {
    local path="$1"
    if [[ -e "$path" && $FORCE -eq 0 ]]; then
        skip "exists $path"
        cat >/dev/null
        return 0
    fi
    mkdir -p "$(dirname "$path")"
    cat > "$path"
    ok "write $path"
}

cd "$ROOT"

# ------------------------------------------------------------
# uv で dev deps 追加
# ------------------------------------------------------------
section "静的解析ツールを dev 依存として追加"

if command -v uv >/dev/null 2>&1; then
    uv add --dev bandit vulture radon deptry pre-commit
    ok "uv add --dev bandit vulture radon deptry pre-commit"
else
    echo "uv が見つかりません。pyproject.toml に手動で追加してください:"
    echo '  bandit>=1.7, vulture>=2.11, radon>=6.0, deptry>=0.16, pre-commit>=3.7'
fi

# ------------------------------------------------------------
# bandit 設定
# ------------------------------------------------------------
section "bandit 設定"

write_file "$ROOT/bandit.yaml" <<'EOF'
# bandit 設定
# 参考: https://bandit.readthedocs.io/

# 除外するテスト ID
skips:
  - B101  # assert 使用（テストで使うので許容）

# 対象外パス
exclude_dirs:
  - tests
  - .venv
  - .git

# 深刻度の下限
# LOW / MEDIUM / HIGH のいずれか
# LOW を指定すると全ての警告を出力
EOF

# ------------------------------------------------------------
# vulture 設定 (pyproject.toml に追記する形式のガイド)
# ------------------------------------------------------------
section "vulture 用ホワイトリスト雛形"

write_file "$ROOT/.vulture_whitelist.py" <<'EOF'
# vulture が誤検出する項目のホワイトリスト
# 使い方: vulture src/ .vulture_whitelist.py
#
# 例:
# _.upsert_many  # Protocol 定義で未使用と誤検出される
# _.find_by_source
EOF

# ------------------------------------------------------------
# pre-commit 設定
# ------------------------------------------------------------
section "pre-commit 設定"

write_file "$ROOT/.pre-commit-config.yaml" <<'EOF'
# pre-commit 設定
# 有効化: uv run pre-commit install
# 手動実行: uv run pre-commit run --all-files

repos:
  # 汎用フック
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.6.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-toml
      - id: check-added-large-files
        args: ['--maxkb=1000']
      - id: check-merge-conflict
      - id: mixed-line-ending
        args: ['--fix=lf']

  # Ruff (Lint + Format)
  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.5.0
    hooks:
      - id: ruff
        args: [--fix]
      - id: ruff-format

  # mypy
  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.10.0
    hooks:
      - id: mypy
        additional_dependencies:
          - pydantic>=2.0
          - typer>=0.12
        args: [--config-file=mypy.ini]
        files: ^src/

  # bandit (セキュリティ)
  - repo: https://github.com/PyCQA/bandit
    rev: 1.7.9
    hooks:
      - id: bandit
        args: [-c, bandit.yaml, -r, src]
        pass_filenames: false

  # ローカルフック (uv run 経由)
  - repo: local
    hooks:
      - id: vulture
        name: vulture (dead code)
        entry: uv run vulture src .vulture_whitelist.py --min-confidence 80
        language: system
        pass_filenames: false
        types: [python]

      - id: radon
        name: radon (complexity CC>=C fails)
        entry: uv run radon cc src -a -nc
        language: system
        pass_filenames: false
        types: [python]

      - id: deptry
        name: deptry (dependency check)
        entry: uv run deptry src
        language: system
        pass_filenames: false
        types: [python]
EOF

# ------------------------------------------------------------
# scripts/check.sh (全チェック一括実行)
# ------------------------------------------------------------
section "scripts/check.sh (全チェック一括実行)"

write_file "$ROOT/scripts/check.sh" <<'EOF'
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
EOF
chmod +x "$ROOT/scripts/check.sh"

# ------------------------------------------------------------
# Makefile
# ------------------------------------------------------------
section "Makefile"

write_file "$ROOT/Makefile" <<'EOF'
.PHONY: help install lint format type security dead complexity deps test check all

help:
	@echo "Available targets:"
	@echo "  install    - uv sync (--all-extras)"
	@echo "  lint       - ruff check"
	@echo "  format     - ruff format"
	@echo "  type       - mypy strict"
	@echo "  security   - bandit"
	@echo "  dead       - vulture (dead code)"
	@echo "  complexity - radon (cyclomatic complexity)"
	@echo "  deps       - deptry (dependency hygiene)"
	@echo "  test       - pytest"
	@echo "  check      - run all quality gates"
	@echo "  hooks      - install pre-commit hooks"

install:
	uv sync --all-extras

lint:
	uv run ruff check src tests

format:
	uv run ruff format src tests

type:
	uv run mypy src

security:
	uv run bandit -c bandit.yaml -r src

dead:
	uv run vulture src .vulture_whitelist.py --min-confidence 80

complexity:
	uv run radon cc src -a -nc
	uv run radon mi src -nc

deps:
	uv run deptry src

test:
	uv run pytest

check:
	bash scripts/check.sh

hooks:
	uv run pre-commit install
	uv run pre-commit run --all-files
EOF

# ------------------------------------------------------------
# ruff.toml に PLR2004 系の追記 (300 行制約は radon で見るが、Ruff でも複雑度は見る)
# ------------------------------------------------------------
section "ruff.toml 拡張 (複雑度・行数の一部を Ruff で担保)"

write_file "$ROOT/ruff.toml" <<'EOF'
line-length = 100
target-version = "py312"

[lint]
select = [
    "E",     # pycodestyle errors
    "W",     # pycodestyle warnings
    "F",     # pyflakes
    "I",     # isort
    "N",     # pep8-naming
    "UP",    # pyupgrade
    "B",     # flake8-bugbear
    "SIM",   # flake8-simplify
    "PLR",   # pylint refactor (複雑度・引数数)
    "PLW",   # pylint warning
    "S",     # flake8-bandit (Ruff 内蔵の軽量セキュリティチェック)
    "C90",   # mccabe 複雑度
    "RUF",   # Ruff 固有ルール
    "ANN",   # 型注釈
    "D",     # pydocstyle
]
ignore = [
    "E501",   # line-length は formatter に委譲
    "D100",   # missing docstring in public module (段階導入)
    "D104",   # missing docstring in public package
    "ANN101", # missing type annotation for self
    "ANN102", # missing type annotation for cls
]

# mccabe 複雑度の閾値
[lint.mccabe]
max-complexity = 10

# pylint 系の閾値
[lint.pylint]
max-args = 6
max-branches = 12
max-returns = 6
max-statements = 30

[lint.pydocstyle]
convention = "google"

[lint.per-file-ignores]
"tests/**/*.py" = ["PLR2004", "S101", "ANN", "D"]
"scripts/**/*.py" = ["ANN", "D"]

[format]
quote-style = "double"
indent-style = "space"
EOF

# ------------------------------------------------------------
# pre-commit のインストール
# ------------------------------------------------------------
section "pre-commit フックをインストール"

if command -v uv >/dev/null 2>&1; then
    if uv run pre-commit install >/dev/null 2>&1; then
        ok "pre-commit install"
    else
        skip "pre-commit install (later: uv run pre-commit install)"
    fi
fi

# ------------------------------------------------------------
# 完了
# ------------------------------------------------------------
section "完了"
echo
echo "追加された静的解析ツール:"
echo "  - bandit    (セキュリティ)"
echo "  - vulture   (デッドコード)"
echo "  - radon     (循環的複雑度・保守性指数)"
echo "  - deptry    (依存関係診断)"
echo "  - pre-commit (フック管理)"
echo
echo "追加された設定ファイル:"
echo "  - bandit.yaml"
echo "  - .vulture_whitelist.py"
echo "  - .pre-commit-config.yaml"
echo "  - scripts/check.sh"
echo "  - Makefile"
echo "  - ruff.toml (拡張)"
echo
echo "使い方:"
echo "  make check                        # 全チェック一括実行"
echo "  make lint / format / type / etc.  # 個別実行"
echo "  bash scripts/check.sh             # CI と同一のチェック"
echo "  uv run pre-commit run --all-files # 全ファイルにフック適用"
echo

#!/usr/bin/env bash
# ============================================================
# DocGraph Lint 設定緩和 + スケルトン修正 + Windows 対応
#
# 対応内容:
#   - ruff.toml をスケルトン段階向けに緩和 (D/ANN を段階導入化)
#   - スケルトンファイルの個別エラー修正
#     * Heading.MAX_LEVEL 定数化 (PLR2004)
#     * Reason を StrEnum に (UP042)
#     * StopwordsService の loop 変数 (PLW2901)
#     * formatters.py の typing.Any 除去 (ANN401)
#   - .gitignore の増強 (uv/cache/OS/エディタ/tmp)
#   - dev.sh (Makefile 代替、make 不要)
#   - scripts/check.sh を dev.sh から呼ぶ形に統一
#
# 使い方: bash fix-lint-and-tools.sh
# ============================================================

set -euo pipefail

ROOT="$(pwd)"
FORCE=1  # 既存を上書き前提

C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_OFF='\033[0m'

section() { printf "\n${C_CYAN}=== %s ===${C_OFF}\n" "$1"; }
ok()      { printf "${C_GREEN}[OK]${C_OFF} %s\n" "$1"; }

write_file() {
    local path="$1"
    mkdir -p "$(dirname "$path")"
    cat > "$path"
    ok "write $path"
}

cd "$ROOT"

# ------------------------------------------------------------
# ruff.toml (スケルトン向け緩和版)
# ------------------------------------------------------------
section "ruff.toml (段階導入版)"

write_file "$ROOT/ruff.toml" <<'EOF'
# DocGraph Ruff 設定 (段階導入型)
# スケルトン段階: 実装エラーの検出に集中
# 実装が進んだ段階で D (pydocstyle) / ANN (型注釈) を段階的に有効化する

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
    "PLR",   # pylint refactor
    "PLW",   # pylint warning
    "S",     # flake8-bandit (軽量セキュリティ)
    "C90",   # mccabe 複雑度
    "RUF",   # Ruff 固有
    # 将来有効化予定:
    # "D",   # pydocstyle (実装がある程度進んでから)
    # "ANN", # 型注釈厳格 (Any 許容箇所を整理してから)
]
ignore = [
    "E501",   # line-length は formatter に委譲
]

[lint.mccabe]
max-complexity = 10

[lint.pylint]
max-args = 6
max-branches = 12
max-returns = 6
max-statements = 30

[lint.per-file-ignores]
"tests/**/*.py" = ["PLR2004", "S101"]
"scripts/**/*.py" = []

[format]
quote-style = "double"
indent-style = "space"
EOF

# ------------------------------------------------------------
# Domain 層の修正
# ------------------------------------------------------------
section "Domain 層スケルトン修正"

# Heading: MAX_LEVEL / MIN_LEVEL を定数化
write_file "$ROOT/src/docgraph/domain/heading.py" <<'EOF'
"""Heading value object."""
from dataclasses import dataclass

MIN_HEADING_LEVEL = 1
MAX_HEADING_LEVEL = 6


@dataclass(frozen=True)
class Heading:
    """Markdown heading. level range: MIN_HEADING_LEVEL..MAX_HEADING_LEVEL."""

    level: int
    text: str
    line: int

    def __post_init__(self) -> None:
        if not MIN_HEADING_LEVEL <= self.level <= MAX_HEADING_LEVEL:
            raise ValueError(
                f"Heading level must be {MIN_HEADING_LEVEL}-{MAX_HEADING_LEVEL}, "
                f"got {self.level}"
            )
EOF

# Confidence: min/max 定数化 (追随)
write_file "$ROOT/src/docgraph/domain/confidence.py" <<'EOF'
"""Confidence value object."""
from dataclasses import dataclass

MIN_CONFIDENCE = 0.0
MAX_CONFIDENCE = 1.0


@dataclass(frozen=True)
class Confidence:
    """Confidence score constrained to [MIN_CONFIDENCE, MAX_CONFIDENCE]."""

    value: float

    def __post_init__(self) -> None:
        if not MIN_CONFIDENCE <= self.value <= MAX_CONFIDENCE:
            raise ValueError(
                f"Confidence must be in [{MIN_CONFIDENCE}, {MAX_CONFIDENCE}], "
                f"got {self.value}"
            )
EOF

# Reason: StrEnum に変更 (UP042 対応)
write_file "$ROOT/src/docgraph/domain/relation.py" <<'EOF'
"""Relation entity and Reason enum."""
from dataclasses import dataclass
from enum import StrEnum

from docgraph.domain.confidence import Confidence


class Reason(StrEnum):
    """Edge origin category."""

    EXPLICIT_LINK = "explicit_link"
    NAME_MENTION = "name_mention"
    HEADING_MENTION = "heading_mention"


@dataclass(frozen=True)
class Relation:
    """Directed relation between two documents."""

    source_id: str
    target_id: str
    reason: Reason
    confidence: Confidence
    evidence_line: int
EOF

# ------------------------------------------------------------
# Application 層の修正
# ------------------------------------------------------------
section "Application 層スケルトン修正"

# StopwordsService: loop 変数の上書き解消 (PLW2901)
write_file "$ROOT/src/docgraph/application/stopwords_service.py" <<'EOF'
"""StopwordsService - loads and provides stopword sets."""
from pathlib import Path


class StopwordsService:
    """Loads stopwords from one or more text files and answers containment queries."""

    def __init__(self, paths: list[str]) -> None:
        self._words: set[str] = set()
        for p in paths:
            self._load(Path(p))

    def _load(self, path: Path) -> None:
        if not path.exists():
            return
        for raw_line in path.read_text(encoding="utf-8").splitlines():
            word = raw_line.strip()
            if not word or word.startswith("#"):
                continue
            self._words.add(word)

    def contains(self, word: str) -> bool:
        return word in self._words

    def as_set(self) -> set[str]:
        return set(self._words)
EOF

# ------------------------------------------------------------
# Interface 層の修正
# ------------------------------------------------------------
section "Interface 層スケルトン修正"

# formatters.py: typing.Any を object に (ANN401 対応)
write_file "$ROOT/src/docgraph/interface/formatters.py" <<'EOF'
"""Output formatters (JSON / text)."""
import json


def to_json(data: object) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2, default=str)


def to_text(data: object) -> str:
    # TODO: implement human-readable formatting
    return str(data)
EOF

# ------------------------------------------------------------
# config_loader.py の tomllib 分岐で ruff の複雑分岐警告が出やすいので整理
# ------------------------------------------------------------
section "config_loader.py 微調整"

write_file "$ROOT/src/docgraph/infrastructure/config_loader.py" <<'EOF'
"""ConfigLoader - loads docgraph.toml."""
import sys
from dataclasses import dataclass, field
from pathlib import Path

if sys.version_info >= (3, 11):
    import tomllib
else:  # pragma: no cover
    import tomli as tomllib  # type: ignore[no-redef]


@dataclass
class ScanConfig:
    include: list[str] = field(default_factory=lambda: ["**/*.md"])
    exclude: list[str] = field(default_factory=list)


@dataclass
class StopwordsConfig:
    files: list[str] = field(default_factory=list)


@dataclass
class RelationConfig:
    name_mention_min_length: int = 3
    heading_mention_min_length: int = 3
    name_mention_confidence: float = 0.7
    heading_mention_confidence: float = 0.6


@dataclass
class Config:
    project_name: str = ""
    root: str = "."
    scan: ScanConfig = field(default_factory=ScanConfig)
    stopwords: StopwordsConfig = field(default_factory=StopwordsConfig)
    relation: RelationConfig = field(default_factory=RelationConfig)


def load_config(path: Path) -> Config:
    if not path.exists():
        return Config()
    _ = tomllib.loads(path.read_text(encoding="utf-8"))
    # TODO: proper mapping from parsed dict to Config
    return Config()
EOF

# ------------------------------------------------------------
# .gitignore 増強
# ------------------------------------------------------------
section ".gitignore 増強"

write_file "$ROOT/.gitignore" <<'EOF'
# ============================================================
# Python
# ============================================================
__pycache__/
*.py[cod]
*$py.class
*.so
*.egg
*.egg-info/
dist/
build/
wheels/
pip-wheel-metadata/
.eggs/
MANIFEST

# ============================================================
# Testing / Coverage
# ============================================================
.pytest_cache/
.mypy_cache/
.ruff_cache/
.dmypy.json
dmypy.json
.coverage
.coverage.*
htmlcov/
.tox/
.nox/
.hypothesis/
coverage.xml
*.cover

# ============================================================
# Type checking
# ============================================================
.pyre/
.pytype/
.pyright/

# ============================================================
# uv / venv / pyenv
# ============================================================
.venv/
venv/
env/
ENV/
.python-version
uv.lock.bak

# ============================================================
# DocGraph runtime
# ============================================================
.docgraph/graph.db
.docgraph/graph.db-journal
.docgraph/graph.db-wal
.docgraph/graph.db-shm
.docgraph/*.log
.docgraph/tmp/

# ============================================================
# IDE / エディタ
# ============================================================
.vscode/
!.vscode/settings.json.example
.idea/
*.swp
*.swo
*~
.project
.pydevproject
.spyderproject
.spyproject

# ============================================================
# OS
# ============================================================
.DS_Store
.DS_Store?
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db
Desktop.ini
$RECYCLE.BIN/

# ============================================================
# tmp / logs / secrets
# ============================================================
tmp/
temp/
*.tmp
*.log
*.pid
*.seed
*.pid.lock
.env
.env.local
.env.*.local
secrets/
*.pem
*.key

# ============================================================
# Node (docs / 補助ツール導入時のため予防)
# ============================================================
node_modules/
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# ============================================================
# Pre-commit
# ============================================================
.pre-commit-config.local.yaml
EOF

# ------------------------------------------------------------
# dev.sh (Makefile 代替、Windows Git Bash でも動く)
# ------------------------------------------------------------
section "dev.sh (Makefile 代替)"

write_file "$ROOT/dev.sh" <<'EOF'
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
EOF
chmod +x "$ROOT/dev.sh"

# ------------------------------------------------------------
# scripts/check.sh の再配置確認 (既にあれば触らない)
# ------------------------------------------------------------
section "scripts/check.sh 確認"

if [[ ! -f "$ROOT/scripts/check.sh" ]]; then
    mkdir -p "$ROOT/scripts"
    write_file "$ROOT/scripts/check.sh" <<'EOF'
#!/usr/bin/env bash
# DocGraph 品質チェック一括実行
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
else
    ok "scripts/check.sh already exists"
fi

# ------------------------------------------------------------
# 完了メッセージ
# ------------------------------------------------------------
section "完了"
echo
echo "変更内容:"
echo "  - ruff.toml を段階導入版に緩和 (D/ANN は将来有効化)"
echo "  - スケルトンの個別エラー修正 (PLR2004 / UP042 / PLW2901 / ANN401)"
echo "  - .gitignore を大幅増強"
echo "  - dev.sh を追加 (make 不要)"
echo
echo "動作確認:"
echo "  bash dev.sh lint       # Ruff エラー 0 になるはず"
echo "  bash dev.sh fix        # 自動修正可能なものを修正"
echo "  bash dev.sh test       # pytest 実行"
echo "  bash dev.sh check      # 全品質ゲート実行"
echo

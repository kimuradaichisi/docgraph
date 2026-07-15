#!/usr/bin/env bash
# ============================================================
# DocGraph プロジェクトスケルトン生成スクリプト (Git Bash / Linux / macOS)
#
# 使い方:
#   bash init-docgraph.sh                # カレントディレクトリに配置
#   bash init-docgraph.sh -r /path       # 指定ディレクトリに配置
#   bash init-docgraph.sh -f             # 既存ファイルを上書き
#   bash init-docgraph.sh --skip-uv      # uv sync をスキップ
#   bash init-docgraph.sh --skip-git     # git init をスキップ
# ============================================================

set -euo pipefail

# ------------------------------------------------------------
# 引数パース
# ------------------------------------------------------------
ROOT="$(pwd)"
FORCE=0
SKIP_UV=0
SKIP_GIT=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        -r|--root)
            ROOT="$2"
            shift 2
            ;;
        -f|--force)
            FORCE=1
            shift
            ;;
        --skip-uv)
            SKIP_UV=1
            shift
            ;;
        --skip-git)
            SKIP_GIT=1
            shift
            ;;
        -h|--help)
            grep '^#' "$0" | head -n 15
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# ------------------------------------------------------------
# ユーティリティ
# ------------------------------------------------------------
C_CYAN='\033[36m'
C_GREEN='\033[32m'
C_YELLOW='\033[33m'
C_GRAY='\033[90m'
C_RED='\033[31m'
C_OFF='\033[0m'

section() { printf "\n${C_CYAN}=== %s ===${C_OFF}\n" "$1"; }
ok()      { printf "${C_GREEN}[OK]${C_OFF} %s\n" "$1"; }
skip()    { printf "${C_YELLOW}[SKIP]${C_OFF} %s\n" "$1"; }
info()    { printf "${C_GRAY}[INFO]${C_OFF} %s\n" "$1"; }
warn()    { printf "${C_YELLOW}[WARN]${C_OFF} %s\n" "$1"; }
err()     { printf "${C_RED}[ERR]${C_OFF} %s\n" "$1" >&2; }

has_cmd() { command -v "$1" >/dev/null 2>&1; }

mkdir_safe() {
    local d="$1"
    if [[ -d "$d" ]]; then
        skip "exists $d"
    else
        mkdir -p "$d"
        ok "mkdir $d"
    fi
}

# ヒアドキュメントで受け取った内容をファイルへ書く
# 使い方: write_file "path" <<'EOF'
#         ...content...
#         EOF
write_file() {
    local path="$1"
    if [[ -e "$path" && $FORCE -eq 0 ]]; then
        skip "exists $path"
        # 入力を捨てる
        cat >/dev/null
        return 0
    fi
    mkdir -p "$(dirname "$path")"
    cat > "$path"
    ok "write $path"
}

# ------------------------------------------------------------
# 前提チェック
# ------------------------------------------------------------
section "前提チェック"

if [[ ! -d "$ROOT" ]]; then
    err "指定されたルートが存在しません: $ROOT"
    exit 1
fi

cd "$ROOT"
info "プロジェクトルート: $ROOT"

if has_cmd uv; then
    info "uv: $(uv --version)"
else
    warn "uv が見つかりません。https://docs.astral.sh/uv/ を参照してインストールしてください。"
    if [[ $SKIP_UV -eq 0 ]]; then
        warn "uv sync はスキップされます。"
        SKIP_UV=1
    fi
fi

if [[ $SKIP_GIT -eq 0 ]] && ! has_cmd git; then
    warn "git が見つかりません。git init はスキップされます。"
    SKIP_GIT=1
fi

# ------------------------------------------------------------
# ディレクトリ構造
# ------------------------------------------------------------
section "ディレクトリ構造の作成"

DIRS=(
    "src/docgraph"
    "src/docgraph/domain"
    "src/docgraph/application"
    "src/docgraph/infrastructure"
    "src/docgraph/interface"
    "tests"
    "tests/domain"
    "tests/application"
    "tests/infrastructure"
    "tests/e2e"
    "tests/fixtures"
    "config"
    "docs"
    ".github"
    ".github/workflows"
)

for d in "${DIRS[@]}"; do
    mkdir_safe "$ROOT/$d"
done

# ------------------------------------------------------------
# __init__.py
# ------------------------------------------------------------
section "__init__.py の配置"

write_file "$ROOT/src/docgraph/__init__.py" <<'EOF'
"""DocGraph - Documentation relationship analysis engine."""

__version__ = "0.1.0"
EOF

INIT_FILES=(
    "src/docgraph/domain/__init__.py"
    "src/docgraph/application/__init__.py"
    "src/docgraph/infrastructure/__init__.py"
    "src/docgraph/interface/__init__.py"
    "tests/__init__.py"
    "tests/domain/__init__.py"
    "tests/application/__init__.py"
    "tests/infrastructure/__init__.py"
    "tests/e2e/__init__.py"
)

for f in "${INIT_FILES[@]}"; do
    write_file "$ROOT/$f" </dev/null
done

# ------------------------------------------------------------
# Domain 層
# ------------------------------------------------------------
section "Domain 層スケルトン"

write_file "$ROOT/src/docgraph/domain/confidence.py" <<'EOF'
"""Confidence value object."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Confidence:
    """0.0 から 1.0 の範囲に制約された信頼度スコア。"""

    value: float

    def __post_init__(self) -> None:
        if not 0.0 <= self.value <= 1.0:
            raise ValueError(f"Confidence must be in [0.0, 1.0], got {self.value}")
EOF

write_file "$ROOT/src/docgraph/domain/heading.py" <<'EOF'
"""Heading value object."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Heading:
    """Markdown 見出し。level は 1〜6。"""

    level: int
    text: str
    line: int

    def __post_init__(self) -> None:
        if not 1 <= self.level <= 6:
            raise ValueError(f"Heading level must be 1-6, got {self.level}")
EOF

write_file "$ROOT/src/docgraph/domain/link.py" <<'EOF'
"""Link value object."""
from dataclasses import dataclass


@dataclass(frozen=True)
class Link:
    """Markdown 明示リンク or Wiki リンク。"""

    target_path: str
    text: str
    line: int
EOF

write_file "$ROOT/src/docgraph/domain/document.py" <<'EOF'
"""Document entity."""
from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True)
class Document:
    """ドキュメントエンティティ。id はパスから決定的に生成する。"""

    id: str
    path: str
    hash: str
    updated_at: datetime
EOF

write_file "$ROOT/src/docgraph/domain/relation.py" <<'EOF'
"""Relation entity and Reason enum."""
from dataclasses import dataclass
from enum import Enum

from docgraph.domain.confidence import Confidence


class Reason(str, Enum):
    EXPLICIT_LINK = "explicit_link"
    NAME_MENTION = "name_mention"
    HEADING_MENTION = "heading_mention"


@dataclass(frozen=True)
class Relation:
    """ドキュメント間の関係。"""

    source_id: str
    target_id: str
    reason: Reason
    confidence: Confidence
    evidence_line: int
EOF

# ------------------------------------------------------------
# Application 層
# ------------------------------------------------------------
section "Application 層スケルトン"

write_file "$ROOT/src/docgraph/application/ports.py" <<'EOF'
"""Ports (interfaces) for Infrastructure layer."""
from __future__ import annotations

from typing import Protocol

from docgraph.domain.document import Document
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Relation


class FileScannerPort(Protocol):
    def scan(self, root: str) -> list[str]: ...


class MarkdownParserPort(Protocol):
    def parse(self, path: str) -> tuple[list[Heading], list[Link], str]: ...


class DocumentRepository(Protocol):
    def upsert(self, document: Document) -> None: ...

    def find_by_path(self, path: str) -> Document | None: ...

    def find_all(self) -> list[Document]: ...


class RelationRepository(Protocol):
    def upsert_many(self, relations: list[Relation]) -> None: ...

    def find_by_source(self, source_id: str) -> list[Relation]: ...


class SearchRepository(Protocol):
    def index_body(self, doc_id: str, body: str) -> None: ...

    def search(self, keyword: str) -> list[tuple[str, float, str]]: ...
EOF

write_file "$ROOT/src/docgraph/application/index_usecase.py" <<'EOF'
"""IndexUseCase - orchestrates scanning, parsing, and relation building."""
from dataclasses import dataclass

from docgraph.application.ports import (
    DocumentRepository,
    FileScannerPort,
    MarkdownParserPort,
    RelationRepository,
    SearchRepository,
)
from docgraph.application.stopwords_service import StopwordsService


@dataclass
class IndexResult:
    indexed_files: int
    skipped_files: int
    explicit_links: int
    name_mentions: int
    heading_mentions: int
    elapsed_ms: int


class IndexUseCase:
    def __init__(
        self,
        scanner: FileScannerPort,
        parser: MarkdownParserPort,
        document_repo: DocumentRepository,
        relation_repo: RelationRepository,
        search_repo: SearchRepository,
        stopwords: StopwordsService,
    ) -> None:
        self._scanner = scanner
        self._parser = parser
        self._document_repo = document_repo
        self._relation_repo = relation_repo
        self._search_repo = search_repo
        self._stopwords = stopwords

    def execute(self, root: str) -> IndexResult:
        # TODO: implement
        raise NotImplementedError
EOF

write_file "$ROOT/src/docgraph/application/query_usecase.py" <<'EOF'
"""QueryUseCase - handles related and search queries."""
from dataclasses import dataclass

from docgraph.application.ports import (
    DocumentRepository,
    RelationRepository,
    SearchRepository,
)


@dataclass
class RelatedItem:
    path: str
    reason: str
    confidence: float
    evidence_line: int


@dataclass
class SearchItem:
    path: str
    score: float
    snippet: str


class QueryUseCase:
    def __init__(
        self,
        document_repo: DocumentRepository,
        relation_repo: RelationRepository,
        search_repo: SearchRepository,
    ) -> None:
        self._document_repo = document_repo
        self._relation_repo = relation_repo
        self._search_repo = search_repo

    def related(self, path: str, min_confidence: float = 0.0) -> list[RelatedItem]:
        # TODO: implement
        raise NotImplementedError

    def search(self, keyword: str) -> list[SearchItem]:
        # TODO: implement
        raise NotImplementedError
EOF

write_file "$ROOT/src/docgraph/application/stopwords_service.py" <<'EOF'
"""StopwordsService - loads and provides stopword sets."""
from pathlib import Path


class StopwordsService:
    def __init__(self, paths: list[str]) -> None:
        self._words: set[str] = set()
        for p in paths:
            self._load(Path(p))

    def _load(self, path: Path) -> None:
        if not path.exists():
            return
        for line in path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            self._words.add(line)

    def contains(self, word: str) -> bool:
        return word in self._words

    def as_set(self) -> set[str]:
        return set(self._words)
EOF

# ------------------------------------------------------------
# Infrastructure 層
# ------------------------------------------------------------
section "Infrastructure 層スケルトン"

write_file "$ROOT/src/docgraph/infrastructure/schema.sql" <<'EOF'
-- DocGraph SQLite schema v1
CREATE TABLE IF NOT EXISTS schema_version (
    version    INTEGER PRIMARY KEY,
    applied_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS documents (
    id         TEXT PRIMARY KEY,
    path       TEXT NOT NULL UNIQUE,
    hash       TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    indexed_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_documents_hash ON documents(hash);

CREATE TABLE IF NOT EXISTS headings (
    id     INTEGER PRIMARY KEY AUTOINCREMENT,
    doc_id TEXT NOT NULL,
    level  INTEGER NOT NULL,
    text   TEXT NOT NULL,
    line   INTEGER NOT NULL,
    FOREIGN KEY (doc_id) REFERENCES documents(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_headings_doc_id ON headings(doc_id);

CREATE TABLE IF NOT EXISTS links (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    doc_id      TEXT NOT NULL,
    target_path TEXT NOT NULL,
    text        TEXT NOT NULL,
    line        INTEGER NOT NULL,
    FOREIGN KEY (doc_id) REFERENCES documents(id) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_links_doc_id ON links(doc_id);

CREATE TABLE IF NOT EXISTS relations (
    id            INTEGER PRIMARY KEY AUTOINCREMENT,
    source_id     TEXT NOT NULL,
    target_id     TEXT NOT NULL,
    reason        TEXT NOT NULL,
    confidence    REAL NOT NULL,
    evidence_line INTEGER NOT NULL,
    FOREIGN KEY (source_id) REFERENCES documents(id) ON DELETE CASCADE,
    FOREIGN KEY (target_id) REFERENCES documents(id) ON DELETE CASCADE,
    UNIQUE (source_id, target_id, reason)
);
CREATE INDEX IF NOT EXISTS idx_relations_source ON relations(source_id);
CREATE INDEX IF NOT EXISTS idx_relations_target ON relations(target_id);

CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
    doc_id UNINDEXED,
    body,
    tokenize = 'unicode61 remove_diacritics 2'
);
EOF

write_file "$ROOT/src/docgraph/infrastructure/sqlite_store.py" <<'EOF'
"""SqliteStore - implements repositories on top of SQLite."""
import sqlite3
from pathlib import Path


class SqliteStore:
    def __init__(self, db_path: Path) -> None:
        self._db_path = db_path
        self._conn = sqlite3.connect(str(db_path))
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._apply_schema()

    def _apply_schema(self) -> None:
        schema_path = Path(__file__).parent / "schema.sql"
        with self._conn:
            self._conn.executescript(schema_path.read_text(encoding="utf-8"))

    # TODO: implement DocumentRepository / RelationRepository / SearchRepository
EOF

write_file "$ROOT/src/docgraph/infrastructure/markdown_parser.py" <<'EOF'
"""MarkdownParser - wraps markdown-it-py."""
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link


class MarkdownParser:
    def parse(self, path: str) -> tuple[list[Heading], list[Link], str]:
        # TODO: implement with markdown-it-py
        raise NotImplementedError
EOF

write_file "$ROOT/src/docgraph/infrastructure/file_scanner.py" <<'EOF'
"""FileScanner - lists .md files respecting .gitignore and include/exclude globs."""


class FileScanner:
    def __init__(
        self,
        include: list[str] | None = None,
        exclude: list[str] | None = None,
        respect_gitignore: bool = True,
    ) -> None:
        self._include = include or ["**/*.md"]
        self._exclude = exclude or []
        self._respect_gitignore = respect_gitignore

    def scan(self, root: str) -> list[str]:
        # TODO: implement with pathspec
        raise NotImplementedError
EOF

write_file "$ROOT/src/docgraph/infrastructure/config_loader.py" <<'EOF'
"""ConfigLoader - loads docgraph.toml."""
from dataclasses import dataclass, field
from pathlib import Path

try:
    import tomllib  # Python 3.11+
except ImportError:
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
    # TODO: proper mapping
    return Config()
EOF

# ------------------------------------------------------------
# Interface 層
# ------------------------------------------------------------
section "Interface 層スケルトン"

write_file "$ROOT/src/docgraph/interface/cli.py" <<'EOF'
"""CLI entry point using Typer."""
from __future__ import annotations

import typer

app = typer.Typer(help="DocGraph - Documentation relationship analysis engine")


@app.command()
def index(
    root: str = typer.Option(".", "--root", help="Project root directory"),
    config: str = typer.Option("docgraph.toml", "--config", help="Config file path"),
) -> None:
    """Build or update the knowledge graph."""
    typer.echo(f"index root={root} config={config}")
    # TODO: wire up IndexUseCase


@app.command()
def related(
    path: str = typer.Argument(..., help="Target file path"),
    min_confidence: float = typer.Option(0.0, "--min-confidence"),
    output_format: str = typer.Option("json", "--format"),
) -> None:
    """Show related documents for a file."""
    typer.echo(f"related path={path}")
    # TODO: wire up QueryUseCase


@app.command()
def search(
    keyword: str = typer.Argument(..., help="Search keyword"),
    output_format: str = typer.Option("json", "--format"),
) -> None:
    """Full-text search across documents."""
    typer.echo(f"search keyword={keyword}")
    # TODO: wire up QueryUseCase


if __name__ == "__main__":
    app()
EOF

write_file "$ROOT/src/docgraph/interface/formatters.py" <<'EOF'
"""Output formatters (JSON / text)."""
import json
from typing import Any


def to_json(data: Any) -> str:
    return json.dumps(data, ensure_ascii=False, indent=2)


def to_text(data: Any) -> str:
    # TODO: implement human-readable formatting
    return str(data)
EOF

# ------------------------------------------------------------
# 設定・辞書
# ------------------------------------------------------------
section "設定ファイル・辞書"

write_file "$ROOT/config/docgraph.example.toml" <<'EOF'
[project]
name = "your-project"
root = "."

[scan]
include = ["docs/**/*.md"]
exclude = [
    ".git/**",
    "node_modules/**",
    "**/archive/**",
    "**/*_bak.md",
    "**/*_old.md",
]

[stopwords]
files = [
    ".docgraph/stopwords_default.txt",
]

[relation]
name_mention_min_length = 3
heading_mention_min_length = 3
name_mention_confidence = 0.7
heading_mention_confidence = 0.6

[search]
fts_tokenizer = "unicode61 remove_diacritics 2"
EOF

write_file "$ROOT/config/stopwords_default.txt" <<'EOF'
# DocGraph 汎用ストップワード辞書
# 本ファイルはプレースホルダ。運用時は配布版で置き換えてください。
EOF

# ------------------------------------------------------------
# pyproject.toml
# ------------------------------------------------------------
section "pyproject.toml"

write_file "$ROOT/pyproject.toml" <<'EOF'
[project]
name = "docgraph"
version = "0.1.0"
description = "Documentation relationship analysis and knowledge graph engine"
readme = "README.md"
requires-python = ">=3.12"
authors = [
    { name = "Kimura Daichi" }
]
dependencies = [
    "typer>=0.12",
    "markdown-it-py>=3.0",
    "pydantic>=2.0",
    "pathspec>=0.12",
    "tomli>=2.0; python_version<'3.11'",
]

[project.scripts]
docgraph = "docgraph.interface.cli:app"

[dependency-groups]
dev = [
    "pytest>=8.0",
    "pytest-cov>=5.0",
    "mypy>=1.10",
    "ruff>=0.5",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"

[tool.hatch.build.targets.wheel]
packages = ["src/docgraph"]

[tool.pytest.ini_options]
testpaths = ["tests"]
addopts = "-ra --cov=docgraph --cov-report=term-missing"
EOF

# ------------------------------------------------------------
# Lint / Type check
# ------------------------------------------------------------
section "Lint / Type check 設定"

write_file "$ROOT/ruff.toml" <<'EOF'
line-length = 100
target-version = "py312"

[lint]
select = [
    "E",
    "F",
    "I",
    "N",
    "UP",
    "B",
    "SIM",
    "PLR",
]
ignore = [
    "E501",
]

[lint.per-file-ignores]
"tests/**/*.py" = ["PLR2004"]

[format]
quote-style = "double"
indent-style = "space"
EOF

write_file "$ROOT/mypy.ini" <<'EOF'
[mypy]
python_version = 3.12
strict = True
warn_return_any = True
warn_unused_configs = True
disallow_untyped_defs = True
disallow_any_generics = True
mypy_path = src
namespace_packages = True
explicit_package_bases = True

[mypy-tests.*]
disallow_untyped_defs = False
EOF

# ------------------------------------------------------------
# .gitignore
# ------------------------------------------------------------
section ".gitignore"

write_file "$ROOT/.gitignore" <<'EOF'
# Python
__pycache__/
*.py[cod]
*.egg-info/
.pytest_cache/
.mypy_cache/
.ruff_cache/
.coverage
htmlcov/

# uv / venv
.venv/
.python-version

# DocGraph
.docgraph/graph.db
.docgraph/graph.db-journal
.docgraph/graph.db-wal
.docgraph/graph.db-shm

# IDE
.vscode/
.idea/
*.swp

# OS
.DS_Store
Thumbs.db
EOF

# ------------------------------------------------------------
# メタドキュメント
# ------------------------------------------------------------
section "メタドキュメント (AGENTS.md / CLAUDE.md)"

write_file "$ROOT/AGENTS.md" <<'EOF'
# AGENTS.md

## プロジェクト概要
DocGraph はドキュメント関係性解析エンジン。DDD レイヤードアーキテクチャで構築。

## 開発制約
- Python 3.12+
- mypy strict 準拠
- Ruff によるリンティング
- 1 ファイル 300 行以内 / 1 メソッド 15 行以内
- ドメイン層は環境依存インポート禁止（sqlite3 / open / requests など）
- 依存方向: Domain <- Application <- Infrastructure / Interface
- テストなしのコード追加禁止

## 実装優先順位
1. Domain 層（純粋ロジック）
2. Infrastructure 層（SQLite / パーサ / スキャナ）
3. Application 層（ユースケース）
4. Interface 層（CLI）

## 禁止事項
- 外部 API 呼び出しコード
- ドキュメント本文の外部送信
- 非決定的な処理（乱数・時刻依存を隠すこと）
- 未使用の import / 未使用の変数
EOF

write_file "$ROOT/CLAUDE.md" <<'EOF'
# CLAUDE.md

## Claude Code 向け実装ガイド

### 全般
- AGENTS.md の制約を厳守する
- 実装前に対応する要件 ID を明示する
- テストとセットで実装する
- 実装後は必ず ruff / mypy / pytest を実行

### 実装順序（MVP-0）
1. Domain 層の各エンティティ・値オブジェクト + ユニットテスト
2. Infrastructure 層: SqliteStore + MarkdownParser + FileScanner
3. Application 層: StopwordsService + IndexUseCase + QueryUseCase
4. Interface 層: cli.py の実配線
5. E2E テストで CLI を通した動作確認

### 型ヒントの注意
- Python 3.12 の新しい型構文を使う（list[str] / dict[str, int] / X | None）
- Protocol は application/ports.py に集約
- docstring と型注釈の間には必ず空行を入れる（構文破損防止）

### 定数
- マジックナンバー禁止。値オブジェクト側 or モジュール定数として定義する

### テスト
- Domain 層: pure unit test
- Application 層: モック注入
- Infrastructure 層: tmp_path fixture
- E2E: typer.testing.CliRunner
EOF

# ------------------------------------------------------------
# docs 雛形
# ------------------------------------------------------------
section "docs 雛形"

write_file "$ROOT/docs/USAGE.md" <<'EOF'
# USAGE

## ジュニアメンバー向け運用手順

### 詳細設計に着手する時
1. `docgraph related <path>` で関連ドキュメントを確認
2. AI に相談する前に CodePrep でパッキング

### キーワードで探したい時
- `docgraph search "受発注"`

### 新規ドキュメント追加時
- `docgraph index` で再インデックス
EOF

write_file "$ROOT/docs/CONFIG.md" <<'EOF'
# CONFIG

## docgraph.toml リファレンス

（TODO: 各セクションの詳細を追記）
EOF

write_file "$ROOT/docs/ROADMAP.md" <<'EOF'
# ROADMAP

| Phase | スコープ |
|---|---|
| MVP-0 | Markdown / 明示リンク / 逆引き / キーワード検索 |
| Phase 1 | docx / xlsx / pptx / pdf / 意味類似 / 5 軸評価器 |
| Phase 2 | タグ埋め込み / DB プロジェクション |
| Phase 3 | スナップショット差分 / 可視化 / HTTP API |
EOF

write_file "$ROOT/docs/ARCHITECTURE.md" <<'EOF'
# ARCHITECTURE

（ARCHITECTURE 本体は別途配布版で上書きしてください）
EOF

write_file "$ROOT/README.md" <<'EOF'
# DocGraph

Documentation relationship analysis and knowledge graph engine.

（README 本体は別途配布版で上書きしてください）

- クイックスタート: docs/USAGE.md
- 設定: docs/CONFIG.md
- ロードマップ: docs/ROADMAP.md
- アーキテクチャ: docs/ARCHITECTURE.md
EOF

# ------------------------------------------------------------
# テスト雛形
# ------------------------------------------------------------
section "テスト雛形"

write_file "$ROOT/tests/domain/test_confidence.py" <<'EOF'
"""Confidence value object tests."""
import pytest

from docgraph.domain.confidence import Confidence


def test_valid_value() -> None:
    c = Confidence(0.5)
    assert c.value == 0.5


def test_lower_bound() -> None:
    assert Confidence(0.0).value == 0.0


def test_upper_bound() -> None:
    assert Confidence(1.0).value == 1.0


def test_out_of_range_raises() -> None:
    with pytest.raises(ValueError):
        Confidence(1.5)
    with pytest.raises(ValueError):
        Confidence(-0.1)
EOF

write_file "$ROOT/tests/domain/test_heading.py" <<'EOF'
"""Heading value object tests."""
import pytest

from docgraph.domain.heading import Heading


def test_valid_level() -> None:
    h = Heading(level=1, text="Intro", line=1)
    assert h.level == 1


def test_invalid_level_raises() -> None:
    with pytest.raises(ValueError):
        Heading(level=0, text="X", line=1)
    with pytest.raises(ValueError):
        Heading(level=7, text="X", line=1)
EOF

# ------------------------------------------------------------
# CI 雛形
# ------------------------------------------------------------
section "CI 雛形"

write_file "$ROOT/.github/workflows/ci.yml" <<'EOF'
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install uv
        uses: astral-sh/setup-uv@v3
      - name: Set up Python
        run: uv python install 3.12
      - name: Sync
        run: uv sync --all-extras
      - name: Lint
        run: uv run ruff check src tests
      - name: Format check
        run: uv run ruff format --check src tests
      - name: Type check
        run: uv run mypy src
      - name: Test
        run: uv run pytest
EOF

# ------------------------------------------------------------
# Git 初期化
# ------------------------------------------------------------
if [[ $SKIP_GIT -eq 0 ]]; then
    section "Git 初期化"
    if [[ -d "$ROOT/.git" ]]; then
        skip ".git already exists"
    else
        (cd "$ROOT" && git init -b main >/dev/null 2>&1)
        ok "git init -b main"
    fi
else
    section "Git 初期化"
    skip "Git init skipped"
fi

# ------------------------------------------------------------
# uv sync
# ------------------------------------------------------------
if [[ $SKIP_UV -eq 0 ]]; then
    section "uv sync"
    if (cd "$ROOT" && uv sync); then
        ok "uv sync completed"
    else
        warn "uv sync に失敗しました。手動で確認してください。"
    fi
else
    section "uv sync"
    skip "uv sync skipped"
fi

# ------------------------------------------------------------
# 完了
# ------------------------------------------------------------
section "完了"
echo
printf "${C_GREEN}DocGraph スケルトンを %s に配置しました。${C_OFF}\n" "$ROOT"
echo
printf "${C_CYAN}次のステップ:${C_OFF}\n"
echo "  1. README.md と docs/ARCHITECTURE.md を配布版で上書き"
echo "  2. config/stopwords_default.txt を配布版で上書き"
echo "  3. uv run pytest でテスト骨格が動くことを確認"
echo "  4. Claude Code で AGENTS.md / CLAUDE.md を読ませて実装開始"
echo

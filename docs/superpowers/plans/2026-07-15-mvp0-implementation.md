# DocGraph MVP-0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Markdown ドキュメント間の関係（明示リンク / ファイル名逆引き / 見出し語逆引き）を SQLite に永続化し、`docgraph index / related / search` CLI で取得できる MVP-0 を完成させる。

**Architecture:** DDD レイヤード（Domain ← Application ← Infrastructure / Interface）。Domain は純粋ロジックのみ、Application は Protocol ポート越しに Infrastructure を利用、Interface は Typer CLI。関係エッジは index 実行のたびに DB 内の永続データから全再構築する（差分検知はファイル単位のパース省略に使う）。

**Tech Stack:** Python 3.12+ / Typer / markdown-it-py / pathspec / SQLite(FTS5 trigram) / pytest / mypy strict / ruff / uv

---

## 現状と設計判断（実装者は必読）

### 現状
- スケルトン配置済み。Domain 層（Confidence / Heading / Link / Document / Relation / Reason）は実装済み、テストは Confidence / Heading のみ。
- 以下はすべて `NotImplementedError` または TODO スタブ: `IndexUseCase.execute` / `QueryUseCase` / `MarkdownParser` / `FileScanner.scan` / `SqliteStore`（リポジトリ未実装）/ `config_loader.load_config`（マッピング未実装）/ `cli.py`（echo のみ）。
- git は **未コミット**（main にコミットゼロ）。Task 1 でベースラインコミットを作る。
- 実行環境: `uv`（`uv run pytest` 等。Makefile に `make lint / type / test / check` あり）。

### 設計判断（このプランで確定させたもの）
1. **FTS5 トークナイザは `trigram` に変更**（schema.sql は現在 `unicode61`）。unicode61 は日本語の連続文字列を 1 トークンに固めるため「受発注」のような部分一致検索（D-03 / F6-07）が不可能。trigram は 3 文字以上の部分一致が可能（検索キーワードは 3 文字以上を要求し、短い場合は明示エラー）。
2. **Config dataclass 群は `application/config.py` へ移動**。RelationBuilder（application 層）が設定値を参照するため、infrastructure/config_loader.py に置いたままだと依存方向違反（Application → Infrastructure）になる。config_loader はマッピング処理のみ持つ。
3. **関係エッジは毎回全再構築**。パース結果（headings / links / FTS body）は DB に永続化されるので、未変更ファイルはパースをスキップしても DB 内データから relation を再構築できる。`relations` テーブルは `DELETE` → 一括 INSERT。
4. **コードブロック除外は「行ブランク化」で実現**。パーサがコードブロックの行番号集合を返し、FTS へ格納する body はその行を空行に置換（行番号は保存される）。これで F3-05（メンション除外）と検索ノイズ除去を同時に満たす。
5. **ポート集約 Protocol `GraphStore`** を導入（DocumentRepository + RelationRepository + SearchRepository + TransactionPort の合成）。SqliteStore が単一クラスで全実装し、UseCase のコンストラクタ引数を減らす（ruff PLR0913 対策）。
6. **doc id はパスから決定的に生成**: `sha256(posix相対パス)[:16]`（AGENTS.md の非決定性禁止に適合）。
7. **`related` の出力**は同一ターゲットでも reason が異なれば別エントリ（要件 4-1 のサンプル通り reason ごとに 1 行）。同一 (source, target, reason) は evidence_line 最小の 1 件にマージ。
8. **ScannedFile / ParsedDocument / SearchHit** DTO を `application/ports.py` に定義。パーサは「テキスト → 構造」の純関数的 API（`parse(text)`) とし、ファイル読み込みは IndexUseCase が行う（Domain 以外は IO 可）。

### 要件カバレッジ対応表

| 要件 | 実装タスク |
|---|---|
| F1-01〜06（収集） | Task 8 (FileScanner) |
| F2-01〜05（パース） | Task 7 (MarkdownParser) |
| F3-01〜06（関係抽出） | Task 3, 4, 11 (resolve_link_target / MentionScanner / RelationBuilder) |
| F4-01〜08（永続化） | Task 6 (schema.sql + SqliteStore) |
| F6-01〜07（CLI） | Task 13, 14, 15 (QueryUseCase / formatters / cli) |
| F10-01〜03（CodePrep 連携） | Task 14, 15（JSON stdout / ルート相対パス） |
| N-05（依存最小） | 既存 pyproject のまま追加依存なし |
| D-01〜05（完了判定） | Task 17 後にユーザーが実データで実施（チェックリスト §7〜11） |

### 全タスク共通ルール
- コミットメッセージ末尾に `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` を付ける。
- 各タスク完了時に `uv run ruff check src tests` と `uv run mypy src` を実行し、エラーゼロを確認してからコミット。
- CLAUDE.md の規約: docstring と後続コードの間に空行 / マジックナンバー禁止（モジュール定数化）/ 1 メソッド 15 行以内 / 1 ファイル 300 行以内。
- テストコマンドはすべて `uv run pytest <path> -v` 形式（`--cov` は pyproject で自動付与される）。

---

### Task 1: ベースライン確認と初回コミット

**Files:** 変更なし（確認とコミットのみ）

- [ ] **Step 1: 依存同期とテスト実行**

Run: `uv sync --all-extras && uv run pytest`
Expected: 既存 6 テストすべて PASS（tests/domain/test_confidence.py, test_heading.py）

- [ ] **Step 2: lint / type 確認**

Run: `uv run ruff check src tests && uv run mypy src`
Expected: エラーなし（スタブ状態でも通る想定。通らない場合は最小修正してから進む）

- [ ] **Step 3: 初回コミット**

```bash
git add -A
git commit -m "chore: initial project skeleton for MVP-0"
```

---

### Task 2: Domain — `make_document_id` と残りのユニットテスト

**Files:**
- Modify: `src/docgraph/domain/document.py`
- Test: `tests/domain/test_document.py`, `tests/domain/test_link.py`, `tests/domain/test_relation.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/domain/test_document.py`:

```python
"""Document entity tests."""
from datetime import UTC, datetime

from docgraph.domain.document import DOC_ID_LENGTH, Document, make_document_id


def test_make_document_id_is_deterministic() -> None:
    assert make_document_id("docs/a.md") == make_document_id("docs/a.md")


def test_make_document_id_differs_by_path() -> None:
    assert make_document_id("docs/a.md") != make_document_id("docs/b.md")


def test_make_document_id_length() -> None:
    assert len(make_document_id("docs/a.md")) == DOC_ID_LENGTH


def test_document_fields() -> None:
    doc = Document(
        id="abc", path="docs/a.md", hash="h",
        updated_at=datetime(2026, 7, 15, tzinfo=UTC),
    )
    assert doc.path == "docs/a.md"
```

`tests/domain/test_relation.py`:

```python
"""Relation entity and Reason enum tests."""
from docgraph.domain.confidence import Confidence
from docgraph.domain.relation import Reason, Relation


def test_reason_values() -> None:
    assert Reason.EXPLICIT_LINK.value == "explicit_link"
    assert Reason.NAME_MENTION.value == "name_mention"
    assert Reason.HEADING_MENTION.value == "heading_mention"


def test_relation_fields() -> None:
    rel = Relation("src", "dst", Reason.NAME_MENTION, Confidence(0.7), 12)
    assert rel.source_id == "src"
    assert rel.target_id == "dst"
    assert rel.confidence.value == 0.7
    assert rel.evidence_line == 12
```

`tests/domain/test_link.py`（resolve_link_target のテストは Task 3 で追加。ここではエンティティのみ）:

```python
"""Link value object tests."""
from docgraph.domain.link import Link


def test_link_fields() -> None:
    link = Link(target_path="./b.md", text="B", line=3)
    assert link.target_path == "./b.md"
    assert link.text == "B"
    assert link.line == 3
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/domain -v`
Expected: test_document.py が `ImportError: cannot import name 'make_document_id'` で FAIL、他は PASS

- [ ] **Step 3: 実装**

`src/docgraph/domain/document.py` の末尾に追加（既存の Document dataclass は変更しない）:

```python
import hashlib  # ファイル先頭の import 群に追加

DOC_ID_LENGTH = 16


def make_document_id(path: str) -> str:
    """ルート相対 POSIX パスから決定的なドキュメント ID を生成する。"""

    return hashlib.sha256(path.encode("utf-8")).hexdigest()[:DOC_ID_LENGTH]
```

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/domain -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/domain/document.py tests/domain/
git commit -m "feat(domain): add make_document_id and remaining domain unit tests"
```

---

### Task 3: Domain — リンク解決 `resolve_link_target`

**Files:**
- Modify: `src/docgraph/domain/link.py`
- Test: `tests/domain/test_link.py`（追記）

- [ ] **Step 1: 失敗するテストを追記**

`tests/domain/test_link.py` に追加:

```python
from docgraph.domain.link import resolve_link_target


def test_resolve_same_dir() -> None:
    assert resolve_link_target("docs/a.md", "b.md") == "docs/b.md"


def test_resolve_dot_slash() -> None:
    assert resolve_link_target("docs/design/order.md", "./customer.md") == "docs/design/customer.md"


def test_resolve_parent_dir() -> None:
    assert resolve_link_target("docs/design/order.md", "../req/sales.md") == "docs/req/sales.md"


def test_resolve_strips_anchor() -> None:
    assert resolve_link_target("docs/a.md", "b.md#section-1") == "docs/b.md"


def test_resolve_url_returns_none() -> None:
    assert resolve_link_target("docs/a.md", "https://example.com/x") is None


def test_resolve_mailto_returns_none() -> None:
    assert resolve_link_target("docs/a.md", "mailto:x@example.com") is None


def test_resolve_empty_returns_none() -> None:
    assert resolve_link_target("docs/a.md", "#section-only") is None


def test_resolve_escaping_root_returns_none() -> None:
    assert resolve_link_target("a.md", "../../etc/passwd") is None
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/domain/test_link.py -v`
Expected: `ImportError: cannot import name 'resolve_link_target'` で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/domain/link.py` に追加（`import posixpath` を先頭 import 群へ。posixpath は純粋なパス演算であり Domain 層の環境依存禁止に抵触しない）:

```python
import posixpath

URL_SCHEME_MARKER = "://"
MAILTO_PREFIX = "mailto:"
PARENT_SEGMENT = ".."


def resolve_link_target(source_path: str, target: str) -> str | None:
    """リンク先をルート相対 POSIX パスに解決する。外部 URL 等は None。"""

    cleaned = target.split("#", 1)[0].strip()
    if not cleaned or URL_SCHEME_MARKER in cleaned or cleaned.startswith(MAILTO_PREFIX):
        return None
    base = posixpath.dirname(source_path)
    normalized = posixpath.normpath(posixpath.join(base, cleaned))
    if normalized.startswith(PARENT_SEGMENT):
        return None
    return normalized
```

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/domain/test_link.py -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/domain/link.py tests/domain/test_link.py
git commit -m "feat(domain): add resolve_link_target for root-relative link resolution"
```

---

### Task 4: Domain — `MentionScanner` と `sanitize_body`

**Files:**
- Create: `src/docgraph/domain/mention.py`
- Test: `tests/domain/test_mention.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/domain/test_mention.py`:

```python
"""MentionScanner and sanitize_body tests."""
from docgraph.domain.mention import MentionScanner, sanitize_body


def test_scan_finds_first_occurrence_line() -> None:
    scanner = MentionScanner({"受発注"})
    body = "概要\n受発注の説明\nまた受発注"
    assert scanner.scan(body) == {"受発注": 2}


def test_scan_multiple_terms() -> None:
    scanner = MentionScanner({"customer", "payment"})
    body = "see customer\nsee payment"
    assert scanner.scan(body) == {"customer": 1, "payment": 2}


def test_scan_missing_term_returns_empty() -> None:
    assert MentionScanner({"absent"}).scan("nothing here") == {}


def test_scan_empty_terms() -> None:
    assert MentionScanner(set()).scan("anything") == {}


def test_sanitize_body_blanks_code_lines() -> None:
    body = "a\ncode\nb"
    assert sanitize_body(body, frozenset({2})) == "a\n\nb"


def test_sanitize_body_preserves_line_numbers() -> None:
    body = "l1\nl2\nl3\nl4"
    result = sanitize_body(body, frozenset({2, 3}))
    assert result.splitlines() == ["l1", "", "", "l4"]


def test_sanitize_body_ignores_out_of_range() -> None:
    assert sanitize_body("only", frozenset({99})) == "only"
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/domain/test_mention.py -v`
Expected: `ModuleNotFoundError: No module named 'docgraph.domain.mention'` で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/domain/mention.py`:

```python
"""MentionScanner - 逆引き用の純粋な部分文字列スキャン。"""

FIRST_LINE = 1


class MentionScanner:
    """候補語集合を本文から探し、初出行番号（1 始まり）を返す。"""

    def __init__(self, terms: set[str]) -> None:
        self._terms = terms

    def scan(self, body: str) -> dict[str, int]:
        """本文に含まれる語 -> 初出行番号の辞書を返す。"""

        found: dict[str, int] = {}
        for term in self._terms:
            index = body.find(term)
            if index >= 0:
                found[term] = body.count("\n", 0, index) + FIRST_LINE
        return found


def sanitize_body(body: str, code_block_lines: frozenset[int]) -> str:
    """コードブロック行を空行化する（行番号は保存される）。"""

    lines = body.splitlines()
    for line_no in code_block_lines:
        if FIRST_LINE <= line_no <= len(lines):
            lines[line_no - 1] = ""
    return "\n".join(lines)
```

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/domain/test_mention.py -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/domain/mention.py tests/domain/test_mention.py
git commit -m "feat(domain): add MentionScanner and sanitize_body"
```

---

### Task 5: Application — `config.py` 新設と `ports.py` 拡張

依存方向違反の解消(設計判断 2)とポート/DTO の確定(設計判断 5, 8)。挙動追加はないため専用テストはなし(既存テスト green + mypy が合格基準)。

**Files:**
- Create: `src/docgraph/application/config.py`
- Modify: `src/docgraph/application/ports.py`(全面書き換え)
- Modify: `src/docgraph/__init__.py`(`__version__` 追加)

- [ ] **Step 1: `application/config.py` を作成**

```python
"""設定 dataclass 群(infrastructure.config_loader が値を詰める)。"""
from dataclasses import dataclass, field

DEFAULT_INCLUDE = "**/*.md"
DEFAULT_MENTION_MIN_LENGTH = 3
DEFAULT_NAME_MENTION_CONFIDENCE = 0.7
DEFAULT_HEADING_MENTION_CONFIDENCE = 0.6


@dataclass(frozen=True)
class ScanConfig:
    include: list[str] = field(default_factory=lambda: [DEFAULT_INCLUDE])
    exclude: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class StopwordsConfig:
    files: list[str] = field(default_factory=list)


@dataclass(frozen=True)
class RelationConfig:
    name_mention_min_length: int = DEFAULT_MENTION_MIN_LENGTH
    heading_mention_min_length: int = DEFAULT_MENTION_MIN_LENGTH
    name_mention_confidence: float = DEFAULT_NAME_MENTION_CONFIDENCE
    heading_mention_confidence: float = DEFAULT_HEADING_MENTION_CONFIDENCE


@dataclass(frozen=True)
class Config:
    project_name: str = ""
    root: str = "."
    scan: ScanConfig = field(default_factory=ScanConfig)
    stopwords: StopwordsConfig = field(default_factory=StopwordsConfig)
    relation: RelationConfig = field(default_factory=RelationConfig)
```

- [ ] **Step 2: `application/ports.py` を全面書き換え**

```python
"""Ports (Protocol) と Application/Infrastructure 間で共有する DTO。"""
from __future__ import annotations

from contextlib import AbstractContextManager
from dataclasses import dataclass
from datetime import datetime
from typing import Protocol

from docgraph.domain.document import Document
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Relation


@dataclass(frozen=True)
class ScannedFile:
    """スキャン結果 1 ファイル分。path はルート相対 POSIX 形式。"""

    path: str
    absolute_path: str
    hash: str
    updated_at: datetime


@dataclass(frozen=True)
class ParsedDocument:
    """Markdown テキスト 1 件のパース結果。"""

    headings: list[Heading]
    links: list[Link]
    body: str
    code_block_lines: frozenset[int]


@dataclass(frozen=True)
class SearchHit:
    """全文検索ヒット 1 件。score は大きいほど良い。"""

    doc_id: str
    score: float
    snippet: str


class FileScannerPort(Protocol):
    def scan(self, root: str) -> list[ScannedFile]: ...


class MarkdownParserPort(Protocol):
    def parse(self, text: str) -> ParsedDocument: ...


class DocumentRepository(Protocol):
    def upsert(self, document: Document) -> None: ...

    def delete(self, doc_id: str) -> None: ...

    def find_by_path(self, path: str) -> Document | None: ...

    def find_by_id(self, doc_id: str) -> Document | None: ...

    def find_all(self) -> list[Document]: ...

    def save_headings(self, doc_id: str, headings: list[Heading]) -> None: ...

    def find_headings(self, doc_id: str) -> list[Heading]: ...

    def save_links(self, doc_id: str, links: list[Link]) -> None: ...

    def find_links(self, doc_id: str) -> list[Link]: ...


class RelationRepository(Protocol):
    def replace_all(self, relations: list[Relation]) -> None: ...

    def find_by_source(self, source_id: str) -> list[Relation]: ...


class SearchRepository(Protocol):
    def index_body(self, doc_id: str, body: str) -> None: ...

    def get_body(self, doc_id: str) -> str | None: ...

    def search(self, keyword: str) -> list[SearchHit]: ...


class TransactionPort(Protocol):
    def transaction(self) -> AbstractContextManager[object]: ...


class GraphStore(
    DocumentRepository,
    RelationRepository,
    SearchRepository,
    TransactionPort,
    Protocol,
):
    """SQLite ストアが単一クラスで実装する集約ポート。"""
```

- [ ] **Step 3: `src/docgraph/__init__.py` にバージョン定義**

```python
"""DocGraph - Documentation relationship analysis engine."""

__version__ = "0.1.0"
```

- [ ] **Step 4: 既存スタブとの整合確認**

`index_usecase.py` の import(`SearchRepository` 等)は名前が存続しているため import エラーにはならない。確認:

Run: `uv run pytest && uv run mypy src && uv run ruff check src tests`
Expected: 全 PASS / エラーなし(`FileScannerPort.scan` の戻り値変更で `file_scanner.py` スタブが mypy エラーになる場合は、スタブの `scan` シグネチャを `def scan(self, root: str) -> list[ScannedFile]:` に合わせて修正して通す)

- [ ] **Step 5: コミット**

```bash
git add src/docgraph/application/config.py src/docgraph/application/ports.py src/docgraph/__init__.py src/docgraph/infrastructure/file_scanner.py
git commit -m "feat(application): add config dataclasses, DTOs, and GraphStore aggregate port"
```

---

### Task 6: Infrastructure — schema.sql 修正と SqliteStore 実装

**Files:**
- Modify: `src/docgraph/infrastructure/schema.sql`(トークナイザのみ変更)
- Modify: `src/docgraph/infrastructure/sqlite_store.py`(全面書き換え)
- Test: `tests/infrastructure/test_sqlite_store.py`

- [ ] **Step 1: schema.sql のトークナイザを trigram に変更**

`schema.sql` の最後の `CREATE VIRTUAL TABLE` ブロックを次に置き換え(他は変更しない):

```sql
CREATE VIRTUAL TABLE IF NOT EXISTS documents_fts USING fts5(
    doc_id UNINDEXED,
    body,
    tokenize = 'trigram'
);
```

- [ ] **Step 2: 失敗するテストを書く**

`tests/infrastructure/test_sqlite_store.py`:

```python
"""SqliteStore repository tests."""
from datetime import UTC, datetime
from pathlib import Path

import pytest

from docgraph.domain.confidence import Confidence
from docgraph.domain.document import Document, make_document_id
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Reason, Relation
from docgraph.infrastructure.sqlite_store import SqliteStore

UPDATED = datetime(2026, 7, 15, tzinfo=UTC)


@pytest.fixture()
def store(tmp_path: Path) -> SqliteStore:
    return SqliteStore(tmp_path / ".docgraph" / "graph.db")


def _doc(path: str = "docs/a.md", hash_: str = "h1") -> Document:
    return Document(id=make_document_id(path), path=path, hash=hash_, updated_at=UPDATED)


def test_creates_db_file_and_parent_dir(tmp_path: Path) -> None:
    SqliteStore(tmp_path / ".docgraph" / "graph.db")
    assert (tmp_path / ".docgraph" / "graph.db").exists()


def test_reopen_is_idempotent(tmp_path: Path) -> None:
    SqliteStore(tmp_path / "graph.db")
    SqliteStore(tmp_path / "graph.db")  # スキーマ再適用でもエラーにならない


def test_upsert_and_find_by_path(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    assert store.find_by_path("docs/a.md") == doc


def test_upsert_updates_existing(store: SqliteStore) -> None:
    store.upsert(_doc(hash_="h1"))
    store.upsert(_doc(hash_="h2"))
    found = store.find_by_path("docs/a.md")
    assert found is not None
    assert found.hash == "h2"
    assert len(store.find_all()) == 1


def test_find_by_id_and_find_all(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    store.upsert(_doc("docs/b.md"))
    assert store.find_by_id(doc.id) == doc
    assert store.find_by_path("missing.md") is None
    assert store.find_by_id("nope") is None
    assert len(store.find_all()) == 2


def test_save_and_find_headings_replaces(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    store.save_headings(doc.id, [Heading(level=1, text="旧", line=1)])
    store.save_headings(doc.id, [Heading(level=2, text="新", line=3)])
    assert store.find_headings(doc.id) == [Heading(level=2, text="新", line=3)]


def test_save_and_find_links_replaces(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    store.save_links(doc.id, [Link(target_path="./x.md", text="X", line=2)])
    store.save_links(doc.id, [Link(target_path="./y.md", text="Y", line=5)])
    assert store.find_links(doc.id) == [Link(target_path="./y.md", text="Y", line=5)]


def test_replace_all_and_find_by_source(store: SqliteStore) -> None:
    src, dst = _doc("s.md"), _doc("t.md")
    store.upsert(src)
    store.upsert(dst)
    rel = Relation(src.id, dst.id, Reason.EXPLICIT_LINK, Confidence(1.0), 4)
    store.replace_all([rel])
    assert store.find_by_source(src.id) == [rel]
    store.replace_all([])
    assert store.find_by_source(src.id) == []


def test_delete_removes_document_children_and_body(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    store.save_headings(doc.id, [Heading(level=1, text="T", line=1)])
    store.index_body(doc.id, "body text")
    store.delete(doc.id)
    assert store.find_by_id(doc.id) is None
    assert store.find_headings(doc.id) == []
    assert store.get_body(doc.id) is None


def test_index_body_and_get_body_replaces(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    store.index_body(doc.id, "old body")
    store.index_body(doc.id, "new body")
    assert store.get_body(doc.id) == "new body"
    assert store.get_body("nope") is None


def test_search_japanese_substring(store: SqliteStore) -> None:
    doc = _doc()
    store.upsert(doc)
    store.index_body(doc.id, "本文で受発注を扱う")
    hits = store.search("受発注")
    assert len(hits) == 1
    assert hits[0].doc_id == doc.id
    assert hits[0].score > 0


def test_search_no_hit_returns_empty(store: SqliteStore) -> None:
    assert store.search("該当なし") == []


def test_search_quote_in_keyword_is_safe(store: SqliteStore) -> None:
    assert store.search('abc"def') == []


def test_transaction_rolls_back_on_error(store: SqliteStore) -> None:
    with pytest.raises(RuntimeError), store.transaction():
        store.upsert(_doc())
        raise RuntimeError("boom")
    assert store.find_all() == []
```

- [ ] **Step 3: 失敗確認**

Run: `uv run pytest tests/infrastructure/test_sqlite_store.py -v`
Expected: `AttributeError`(upsert 等が未定義)で FAIL

- [ ] **Step 4: SqliteStore を実装**

`src/docgraph/infrastructure/sqlite_store.py` 全体を置き換え:

```python
"""SqliteStore - GraphStore の SQLite 実装。"""
from __future__ import annotations

import sqlite3
from contextlib import AbstractContextManager
from datetime import UTC, datetime
from pathlib import Path

from docgraph.application.ports import SearchHit
from docgraph.domain.confidence import Confidence
from docgraph.domain.document import Document
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Reason, Relation

SCHEMA_VERSION = 1
SNIPPET_TOKENS = 10


def _now() -> str:
    return datetime.now(UTC).isoformat()


class SqliteStore:
    """全リポジトリポートを単一クラスで実装する。"""

    def __init__(self, db_path: Path) -> None:
        db_path.parent.mkdir(parents=True, exist_ok=True)
        self._conn = sqlite3.connect(str(db_path))
        self._conn.row_factory = sqlite3.Row
        self._conn.execute("PRAGMA foreign_keys = ON")
        self._apply_schema()

    def _apply_schema(self) -> None:
        schema = (Path(__file__).parent / "schema.sql").read_text(encoding="utf-8")
        with self._conn:
            self._conn.executescript(schema)
            self._conn.execute(
                "INSERT OR IGNORE INTO schema_version (version, applied_at) VALUES (?, ?)",
                (SCHEMA_VERSION, _now()),
            )

    def transaction(self) -> AbstractContextManager[object]:
        """成功でコミット、例外でロールバックするコンテキストマネージャ。"""

        return self._conn

    # --- DocumentRepository ---

    def upsert(self, document: Document) -> None:
        self._conn.execute(
            """INSERT INTO documents (id, path, hash, updated_at, indexed_at)
               VALUES (?, ?, ?, ?, ?)
               ON CONFLICT(id) DO UPDATE SET
                 hash = excluded.hash,
                 updated_at = excluded.updated_at,
                 indexed_at = excluded.indexed_at""",
            (document.id, document.path, document.hash,
             document.updated_at.isoformat(), _now()),
        )

    def delete(self, doc_id: str) -> None:
        self._conn.execute("DELETE FROM documents WHERE id = ?", (doc_id,))
        self._conn.execute("DELETE FROM documents_fts WHERE doc_id = ?", (doc_id,))

    def find_by_path(self, path: str) -> Document | None:
        row = self._conn.execute(
            "SELECT id, path, hash, updated_at FROM documents WHERE path = ?", (path,)
        ).fetchone()
        return _to_document(row) if row else None

    def find_by_id(self, doc_id: str) -> Document | None:
        row = self._conn.execute(
            "SELECT id, path, hash, updated_at FROM documents WHERE id = ?", (doc_id,)
        ).fetchone()
        return _to_document(row) if row else None

    def find_all(self) -> list[Document]:
        rows = self._conn.execute(
            "SELECT id, path, hash, updated_at FROM documents ORDER BY path"
        ).fetchall()
        return [_to_document(row) for row in rows]

    def save_headings(self, doc_id: str, headings: list[Heading]) -> None:
        self._conn.execute("DELETE FROM headings WHERE doc_id = ?", (doc_id,))
        self._conn.executemany(
            "INSERT INTO headings (doc_id, level, text, line) VALUES (?, ?, ?, ?)",
            [(doc_id, h.level, h.text, h.line) for h in headings],
        )

    def find_headings(self, doc_id: str) -> list[Heading]:
        rows = self._conn.execute(
            "SELECT level, text, line FROM headings WHERE doc_id = ? ORDER BY line",
            (doc_id,),
        ).fetchall()
        return [Heading(level=r["level"], text=r["text"], line=r["line"]) for r in rows]

    def save_links(self, doc_id: str, links: list[Link]) -> None:
        self._conn.execute("DELETE FROM links WHERE doc_id = ?", (doc_id,))
        self._conn.executemany(
            "INSERT INTO links (doc_id, target_path, text, line) VALUES (?, ?, ?, ?)",
            [(doc_id, li.target_path, li.text, li.line) for li in links],
        )

    def find_links(self, doc_id: str) -> list[Link]:
        rows = self._conn.execute(
            "SELECT target_path, text, line FROM links WHERE doc_id = ? ORDER BY line",
            (doc_id,),
        ).fetchall()
        return [
            Link(target_path=r["target_path"], text=r["text"], line=r["line"]) for r in rows
        ]

    # --- RelationRepository ---

    def replace_all(self, relations: list[Relation]) -> None:
        self._conn.execute("DELETE FROM relations")
        self._conn.executemany(
            """INSERT INTO relations
               (source_id, target_id, reason, confidence, evidence_line)
               VALUES (?, ?, ?, ?, ?)""",
            [(r.source_id, r.target_id, r.reason.value, r.confidence.value, r.evidence_line)
             for r in relations],
        )

    def find_by_source(self, source_id: str) -> list[Relation]:
        rows = self._conn.execute(
            """SELECT source_id, target_id, reason, confidence, evidence_line
               FROM relations WHERE source_id = ?""",
            (source_id,),
        ).fetchall()
        return [_to_relation(row) for row in rows]

    # --- SearchRepository ---

    def index_body(self, doc_id: str, body: str) -> None:
        self._conn.execute("DELETE FROM documents_fts WHERE doc_id = ?", (doc_id,))
        self._conn.execute(
            "INSERT INTO documents_fts (doc_id, body) VALUES (?, ?)", (doc_id, body)
        )

    def get_body(self, doc_id: str) -> str | None:
        row = self._conn.execute(
            "SELECT body FROM documents_fts WHERE doc_id = ?", (doc_id,)
        ).fetchone()
        return str(row["body"]) if row else None

    def search(self, keyword: str) -> list[SearchHit]:
        quoted = '"' + keyword.replace('"', '""') + '"'
        rows = self._conn.execute(
            """SELECT doc_id, bm25(documents_fts) AS rank,
                      snippet(documents_fts, 1, '', '', '...', ?) AS snip
               FROM documents_fts WHERE documents_fts MATCH ?
               ORDER BY rank""",
            (SNIPPET_TOKENS, quoted),
        ).fetchall()
        return [SearchHit(doc_id=r["doc_id"], score=-r["rank"], snippet=r["snip"]) for r in rows]


def _to_document(row: sqlite3.Row) -> Document:
    return Document(
        id=row["id"], path=row["path"], hash=row["hash"],
        updated_at=datetime.fromisoformat(row["updated_at"]),
    )


def _to_relation(row: sqlite3.Row) -> Relation:
    return Relation(
        source_id=row["source_id"], target_id=row["target_id"],
        reason=Reason(row["reason"]), confidence=Confidence(row["confidence"]),
        evidence_line=row["evidence_line"],
    )
```

注意: `test_transaction_rolls_back_on_error` が失敗する場合は sqlite3 の isolation 挙動が原因。Python 3.12+ では `sqlite3.connect(..., autocommit=False)` を指定すると `with conn:` のロールバックが確実になる。まず素の実装で走らせ、失敗したら `connect` に `autocommit=False` を追加し、`_apply_schema` 呼び出し後に `self._conn.commit()` を追加して調整する。

- [ ] **Step 5: テスト成功確認**

Run: `uv run pytest tests/infrastructure/test_sqlite_store.py -v`
Expected: 全 PASS(bm25 はヒット時に負値を返すため `-rank` で正になる。`score > 0` が落ちる場合はアサーションを緩めず bm25 の符号を確認して実装側を直す)

- [ ] **Step 6: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/infrastructure/schema.sql src/docgraph/infrastructure/sqlite_store.py tests/infrastructure/test_sqlite_store.py
git commit -m "feat(infrastructure): implement SqliteStore with trigram FTS5"
```

---

### Task 7: Infrastructure — MarkdownParser 実装

**Files:**
- Modify: `src/docgraph/infrastructure/markdown_parser.py`(全面書き換え)
- Test: `tests/infrastructure/test_markdown_parser.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/infrastructure/test_markdown_parser.py`(サンプル md にコードフェンスを含むため、外側を 4 バッククォートで囲んだものをここに示す。実ファイルでは通常の Python 文字列):

````python
"""MarkdownParser tests."""
from docgraph.infrastructure.markdown_parser import MarkdownParser

SAMPLE = """# タイトル

本文 [顧客設計](./customer.md) 参照。

## 設計方針

[[order]] も見る。

```python
# コード内の見出しではない
[fake](./fake.md)
[[fake_wiki]]
```

### 補足
"""


def _parse(text: str = SAMPLE):  # noqa: ANN202
    return MarkdownParser().parse(text)


def test_extracts_headings_with_level_and_line() -> None:
    parsed = _parse()
    assert [(h.level, h.text, h.line) for h in parsed.headings] == [
        (1, "タイトル", 1),
        (2, "設計方針", 5),
        (3, "補足", 16),
    ]


def test_extracts_explicit_link_with_line() -> None:
    parsed = _parse()
    explicit = [li for li in parsed.links if li.target_path == "./customer.md"]
    assert len(explicit) == 1
    assert explicit[0].text == "顧客設計"
    assert explicit[0].line == 3


def test_extracts_wiki_link() -> None:
    parsed = _parse()
    wiki = [li for li in parsed.links if li.target_path == "order"]
    assert len(wiki) == 1
    assert wiki[0].line == 7


def test_code_block_lines_are_recorded() -> None:
    parsed = _parse()
    assert 11 in parsed.code_block_lines  # ```python 内
    assert 12 in parsed.code_block_lines
    assert 1 not in parsed.code_block_lines


def test_links_inside_code_block_are_not_extracted_as_wiki() -> None:
    parsed = _parse()
    assert all(li.target_path != "fake_wiki" for li in parsed.links)


def test_body_is_original_text() -> None:
    parsed = _parse()
    assert parsed.body == SAMPLE


def test_wiki_link_with_alias_and_anchor() -> None:
    parsed = _parse("[[design|表示名]] と [[spec#章]]")
    targets = {li.target_path for li in parsed.links}
    assert targets == {"design", "spec"}


def test_empty_text() -> None:
    parsed = _parse("")
    assert parsed.headings == []
    assert parsed.links == []
    assert parsed.code_block_lines == frozenset()
````

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/infrastructure/test_markdown_parser.py -v`
Expected: `NotImplementedError` で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/infrastructure/markdown_parser.py` 全体を置き換え:

```python
"""MarkdownParser - markdown-it-py ラッパ。"""
from __future__ import annotations

import re

from markdown_it import MarkdownIt
from markdown_it.token import Token

from docgraph.application.ports import ParsedDocument
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link

WIKI_LINK_PATTERN = re.compile(r"\[\[([^\]|#]+)(?:[|#][^\]]*)?\]\]")
HEADING_TAG_PREFIX_LENGTH = 1  # "h1" -> 1


class MarkdownParser:
    """Markdown テキストから見出し・リンク・コードブロック行を抽出する。"""

    def __init__(self) -> None:
        self._md = MarkdownIt("commonmark")

    def parse(self, text: str) -> ParsedDocument:
        """テキストを解析して ParsedDocument を返す。"""

        tokens = self._md.parse(text)
        code_lines = _code_block_lines(tokens)
        links = _extract_links(tokens) + _extract_wiki_links(text, code_lines)
        return ParsedDocument(
            headings=_extract_headings(tokens),
            links=links,
            body=text,
            code_block_lines=frozenset(code_lines),
        )


def _extract_headings(tokens: list[Token]) -> list[Heading]:
    headings: list[Heading] = []
    for i, token in enumerate(tokens):
        if token.type == "heading_open" and token.map is not None:
            level = int(token.tag[HEADING_TAG_PREFIX_LENGTH:])
            text = tokens[i + 1].content
            headings.append(Heading(level=level, text=text, line=token.map[0] + 1))
    return headings


def _code_block_lines(tokens: list[Token]) -> set[int]:
    lines: set[int] = set()
    for token in tokens:
        if token.type in ("fence", "code_block") and token.map is not None:
            lines.update(range(token.map[0] + 1, token.map[1] + 1))
    return lines


def _extract_links(tokens: list[Token]) -> list[Link]:
    links: list[Link] = []
    for token in tokens:
        if token.type != "inline" or token.map is None or token.children is None:
            continue
        links.extend(_links_in_children(token.children, token.map[0] + 1))
    return links


def _links_in_children(children: list[Token], line: int) -> list[Link]:
    links: list[Link] = []
    for i, child in enumerate(children):
        if child.type == "link_open":
            href = str(child.attrGet("href") or "")
            text = children[i + 1].content if i + 1 < len(children) else ""
            links.append(Link(target_path=href, text=text, line=line))
    return links


def _extract_wiki_links(text: str, code_lines: set[int]) -> list[Link]:
    links: list[Link] = []
    for line_no, line_text in enumerate(text.splitlines(), start=1):
        if line_no in code_lines:
            continue
        for match in WIKI_LINK_PATTERN.finditer(line_text):
            name = match.group(1).strip()
            links.append(Link(target_path=name, text=name, line=line_no))
    return links
```

既知の制約(許容): 複数行にまたがる段落内のインラインリンクは段落先頭行の行番号になる(F2-05 は「行番号を保持」であり近似で足りる)。テストの期待行番号が実際の markdown-it の `map` とずれた場合は、`uv run python -c "..."` でトークンを出力して期待値側を実挙動に合わせて修正すること(パーサの行番号は markdown-it の仕様が正)。

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/infrastructure/test_markdown_parser.py -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/infrastructure/markdown_parser.py tests/infrastructure/test_markdown_parser.py
git commit -m "feat(infrastructure): implement MarkdownParser with heading/link/code-block extraction"
```

---

### Task 8: Infrastructure — FileScanner 実装

**Files:**
- Modify: `src/docgraph/infrastructure/file_scanner.py`(全面書き換え)
- Test: `tests/infrastructure/test_file_scanner.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/infrastructure/test_file_scanner.py`:

```python
"""FileScanner tests."""
import hashlib
from pathlib import Path

from docgraph.infrastructure.file_scanner import FileScanner


def _write(root: Path, rel: str, content: str = "x") -> None:
    path = root / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def test_lists_md_files_sorted_with_posix_paths(tmp_path: Path) -> None:
    _write(tmp_path, "b.md")
    _write(tmp_path, "sub/a.md")
    _write(tmp_path, "note.txt")
    files = FileScanner().scan(str(tmp_path))
    assert [f.path for f in files] == ["b.md", "sub/a.md"]


def test_hash_is_sha256_of_content(tmp_path: Path) -> None:
    _write(tmp_path, "a.md", "hello")
    files = FileScanner().scan(str(tmp_path))
    assert files[0].hash == hashlib.sha256(b"hello").hexdigest()


def test_updated_at_is_timezone_aware(tmp_path: Path) -> None:
    _write(tmp_path, "a.md")
    files = FileScanner().scan(str(tmp_path))
    assert files[0].updated_at.tzinfo is not None


def test_absolute_path_points_to_file(tmp_path: Path) -> None:
    _write(tmp_path, "a.md", "content")
    files = FileScanner().scan(str(tmp_path))
    assert Path(files[0].absolute_path).read_text(encoding="utf-8") == "content"


def test_respects_gitignore(tmp_path: Path) -> None:
    _write(tmp_path, "keep.md")
    _write(tmp_path, "tmp/skip.md")
    (tmp_path / ".gitignore").write_text("tmp/\n", encoding="utf-8")
    files = FileScanner().scan(str(tmp_path))
    assert [f.path for f in files] == ["keep.md"]


def test_gitignore_disabled(tmp_path: Path) -> None:
    _write(tmp_path, "tmp/skip.md")
    (tmp_path / ".gitignore").write_text("tmp/\n", encoding="utf-8")
    files = FileScanner(respect_gitignore=False).scan(str(tmp_path))
    assert [f.path for f in files] == ["tmp/skip.md"]


def test_exclude_glob(tmp_path: Path) -> None:
    _write(tmp_path, "docs/keep.md")
    _write(tmp_path, "docs/archive/old.md")
    files = FileScanner(exclude=["docs/archive/**"]).scan(str(tmp_path))
    assert [f.path for f in files] == ["docs/keep.md"]


def test_include_filter(tmp_path: Path) -> None:
    _write(tmp_path, "docs/keep.md")
    _write(tmp_path, "root.md")
    files = FileScanner(include=["docs/**/*.md"]).scan(str(tmp_path))
    assert [f.path for f in files] == ["docs/keep.md"]
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/infrastructure/test_file_scanner.py -v`
Expected: `NotImplementedError` または `TypeError` で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/infrastructure/file_scanner.py` 全体を置き換え:

```python
"""FileScanner - .gitignore と include/exclude glob を尊重した .md 列挙。"""
from __future__ import annotations

import hashlib
from datetime import UTC, datetime
from pathlib import Path

import pathspec

from docgraph.application.ports import ScannedFile

MD_SUFFIX = ".md"
GITIGNORE_NAME = ".gitignore"
DEFAULT_INCLUDE = f"**/*{MD_SUFFIX}"
PATHSPEC_STYLE = "gitwildmatch"


class FileScanner:
    """ルート配下の Markdown ファイルを列挙する。"""

    def __init__(
        self,
        include: list[str] | None = None,
        exclude: list[str] | None = None,
        respect_gitignore: bool = True,
    ) -> None:
        self._include = include or [DEFAULT_INCLUDE]
        self._exclude = exclude or []
        self._respect_gitignore = respect_gitignore

    def scan(self, root: str) -> list[ScannedFile]:
        """対象となる全 .md ファイルのメタデータを path 昇順で返す。"""

        root_path = Path(root).resolve()
        include = pathspec.PathSpec.from_lines(PATHSPEC_STYLE, self._include)
        ignore = self._ignore_spec(root_path)
        results: list[ScannedFile] = []
        for file_path in sorted(root_path.rglob(f"*{MD_SUFFIX}")):
            rel = file_path.relative_to(root_path).as_posix()
            if include.match_file(rel) and not ignore.match_file(rel):
                results.append(_to_scanned_file(file_path, rel))
        return results

    def _ignore_spec(self, root_path: Path) -> pathspec.PathSpec:
        patterns = list(self._exclude)
        gitignore = root_path / GITIGNORE_NAME
        if self._respect_gitignore and gitignore.is_file():
            patterns += gitignore.read_text(encoding="utf-8").splitlines()
        return pathspec.PathSpec.from_lines(PATHSPEC_STYLE, patterns)


def _to_scanned_file(file_path: Path, rel: str) -> ScannedFile:
    digest = hashlib.sha256(file_path.read_bytes()).hexdigest()
    mtime = datetime.fromtimestamp(file_path.stat().st_mtime, tz=UTC)
    return ScannedFile(
        path=rel, absolute_path=str(file_path), hash=digest, updated_at=mtime
    )
```

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/infrastructure/test_file_scanner.py -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/infrastructure/file_scanner.py tests/infrastructure/test_file_scanner.py
git commit -m "feat(infrastructure): implement FileScanner with gitignore and glob filters"
```

---

### Task 9: Infrastructure — ConfigLoader 実装

**Files:**
- Modify: `src/docgraph/infrastructure/config_loader.py`(全面書き換え。dataclass 定義は Task 5 の `application/config.py` へ移動済みなのでここから削除)
- Test: `tests/infrastructure/test_config_loader.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/infrastructure/test_config_loader.py`:

```python
"""ConfigLoader tests."""
from pathlib import Path

from docgraph.infrastructure.config_loader import load_config

FULL_TOML = """
[project]
name = "kandy-house"
root = "."

[scan]
include = ["docs/**/*.md"]
exclude = ["**/archive/**"]

[stopwords]
files = [".docgraph/stopwords_default.txt"]

[relation]
name_mention_min_length = 4
heading_mention_min_length = 5
name_mention_confidence = 0.8
heading_mention_confidence = 0.5
"""


def test_missing_file_returns_defaults(tmp_path: Path) -> None:
    config = load_config(tmp_path / "none.toml")
    assert config.scan.include == ["**/*.md"]
    assert config.scan.exclude == []
    assert config.stopwords.files == []
    assert config.relation.name_mention_confidence == 0.7
    assert config.relation.heading_mention_confidence == 0.6
    assert config.relation.name_mention_min_length == 3


def test_full_file_is_mapped(tmp_path: Path) -> None:
    path = tmp_path / "docgraph.toml"
    path.write_text(FULL_TOML, encoding="utf-8")
    config = load_config(path)
    assert config.project_name == "kandy-house"
    assert config.root == "."
    assert config.scan.include == ["docs/**/*.md"]
    assert config.scan.exclude == ["**/archive/**"]
    assert config.stopwords.files == [".docgraph/stopwords_default.txt"]
    assert config.relation.name_mention_min_length == 4
    assert config.relation.heading_mention_min_length == 5
    assert config.relation.name_mention_confidence == 0.8
    assert config.relation.heading_mention_confidence == 0.5


def test_partial_file_falls_back_to_defaults(tmp_path: Path) -> None:
    path = tmp_path / "docgraph.toml"
    path.write_text('[scan]\ninclude = ["a/**/*.md"]\n', encoding="utf-8")
    config = load_config(path)
    assert config.scan.include == ["a/**/*.md"]
    assert config.relation.name_mention_confidence == 0.7
    assert config.stopwords.files == []
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/infrastructure/test_config_loader.py -v`
Expected: `test_full_file_is_mapped` が FAIL(現スタブは常にデフォルトを返す)

- [ ] **Step 3: 実装**

`src/docgraph/infrastructure/config_loader.py` 全体を置き換え:

```python
"""ConfigLoader - docgraph.toml を application.config.Config に読み込む。"""
from __future__ import annotations

import tomllib
from pathlib import Path
from typing import Any

from docgraph.application.config import (
    Config,
    RelationConfig,
    ScanConfig,
    StopwordsConfig,
)


def load_config(path: Path) -> Config:
    """docgraph.toml を読み込む。ファイル・キーが無ければデフォルト値。"""

    if not path.exists():
        return Config()
    data: dict[str, Any] = tomllib.loads(path.read_text(encoding="utf-8"))
    project = data.get("project", {})
    return Config(
        project_name=project.get("name", ""),
        root=project.get("root", "."),
        scan=_scan_config(data.get("scan", {})),
        stopwords=StopwordsConfig(files=list(data.get("stopwords", {}).get("files", []))),
        relation=_relation_config(data.get("relation", {})),
    )


def _scan_config(data: dict[str, Any]) -> ScanConfig:
    defaults = ScanConfig()
    return ScanConfig(
        include=list(data.get("include", defaults.include)),
        exclude=list(data.get("exclude", defaults.exclude)),
    )


def _relation_config(data: dict[str, Any]) -> RelationConfig:
    defaults = RelationConfig()
    return RelationConfig(
        name_mention_min_length=data.get(
            "name_mention_min_length", defaults.name_mention_min_length
        ),
        heading_mention_min_length=data.get(
            "heading_mention_min_length", defaults.heading_mention_min_length
        ),
        name_mention_confidence=data.get(
            "name_mention_confidence", defaults.name_mention_confidence
        ),
        heading_mention_confidence=data.get(
            "heading_mention_confidence", defaults.heading_mention_confidence
        ),
    )
```

注意: requires-python >=3.12 なので `tomllib` を直接 import する(旧スタブの `sys.version_info` 分岐と `tomli` フォールバックは削除)。

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/infrastructure/test_config_loader.py -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/infrastructure/config_loader.py tests/infrastructure/test_config_loader.py
git commit -m "feat(infrastructure): implement config_loader mapping to application Config"
```

---

### Task 10: Application — StopwordsService のテスト追加

StopwordsService は実装済みだがテストが無い(AGENTS.md「テストなしのコード追加禁止」違反状態の解消)。

**Files:**
- Test: `tests/application/test_stopwords_service.py`

- [ ] **Step 1: テストを書く**

`tests/application/test_stopwords_service.py`:

```python
"""StopwordsService tests."""
from pathlib import Path

from docgraph.application.stopwords_service import StopwordsService


def test_loads_words_ignoring_comments_and_blanks(tmp_path: Path) -> None:
    file = tmp_path / "stop.txt"
    file.write_text("# コメント\n\n概要\n設計  \n", encoding="utf-8")
    service = StopwordsService([str(file)])
    assert service.contains("概要")
    assert service.contains("設計")
    assert not service.contains("# コメント")


def test_merges_multiple_files(tmp_path: Path) -> None:
    a = tmp_path / "a.txt"
    b = tmp_path / "b.txt"
    a.write_text("alpha\n", encoding="utf-8")
    b.write_text("beta\n", encoding="utf-8")
    service = StopwordsService([str(a), str(b)])
    assert service.as_set() == {"alpha", "beta"}


def test_missing_file_is_ignored(tmp_path: Path) -> None:
    service = StopwordsService([str(tmp_path / "none.txt")])
    assert service.as_set() == set()


def test_empty_paths() -> None:
    service = StopwordsService([])
    assert not service.contains("anything")
```

- [ ] **Step 2: テスト成功確認**

Run: `uv run pytest tests/application/test_stopwords_service.py -v`
Expected: 全 PASS(実装済みのため。FAIL したら実装のバグなので実装を直す)

- [ ] **Step 3: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add tests/application/test_stopwords_service.py
git commit -m "test(application): add StopwordsService unit tests"
```

---

### Task 11: Application — InMemoryGraphStore フェイクと RelationBuilder

**Files:**
- Create: `src/docgraph/application/relation_builder.py`
- Create: `tests/application/fakes.py`(以降のタスクでも再利用)
- Test: `tests/application/test_relation_builder.py`

- [ ] **Step 1: フェイクを作成**

`tests/application/fakes.py`:

```python
"""Application 層テスト用の in-memory GraphStore フェイク。"""
from contextlib import AbstractContextManager, nullcontext
from datetime import UTC, datetime

from docgraph.application.ports import SearchHit
from docgraph.domain.document import Document, make_document_id
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Relation

NOW = datetime(2026, 7, 15, tzinfo=UTC)
SNIPPET_LENGTH = 20


class InMemoryGraphStore:
    """GraphStore Protocol を満たす辞書ベースのフェイク。"""

    def __init__(self) -> None:
        self.documents: dict[str, Document] = {}
        self.headings: dict[str, list[Heading]] = {}
        self.links: dict[str, list[Link]] = {}
        self.relations: list[Relation] = []
        self.bodies: dict[str, str] = {}

    def upsert(self, document: Document) -> None:
        self.documents[document.id] = document

    def delete(self, doc_id: str) -> None:
        self.documents.pop(doc_id, None)
        self.headings.pop(doc_id, None)
        self.links.pop(doc_id, None)
        self.bodies.pop(doc_id, None)

    def find_by_path(self, path: str) -> Document | None:
        return next((d for d in self.documents.values() if d.path == path), None)

    def find_by_id(self, doc_id: str) -> Document | None:
        return self.documents.get(doc_id)

    def find_all(self) -> list[Document]:
        return sorted(self.documents.values(), key=lambda d: d.path)

    def save_headings(self, doc_id: str, headings: list[Heading]) -> None:
        self.headings[doc_id] = list(headings)

    def find_headings(self, doc_id: str) -> list[Heading]:
        return list(self.headings.get(doc_id, []))

    def save_links(self, doc_id: str, links: list[Link]) -> None:
        self.links[doc_id] = list(links)

    def find_links(self, doc_id: str) -> list[Link]:
        return list(self.links.get(doc_id, []))

    def replace_all(self, relations: list[Relation]) -> None:
        self.relations = list(relations)

    def find_by_source(self, source_id: str) -> list[Relation]:
        return [r for r in self.relations if r.source_id == source_id]

    def index_body(self, doc_id: str, body: str) -> None:
        self.bodies[doc_id] = body

    def get_body(self, doc_id: str) -> str | None:
        return self.bodies.get(doc_id)

    def search(self, keyword: str) -> list[SearchHit]:
        return [
            SearchHit(doc_id=doc_id, score=1.0, snippet=body[:SNIPPET_LENGTH])
            for doc_id, body in self.bodies.items()
            if keyword in body
        ]

    def transaction(self) -> AbstractContextManager[object]:
        return nullcontext()


def seed(
    store: InMemoryGraphStore,
    path: str,
    body: str = "",
    headings: list[Heading] | None = None,
    links: list[Link] | None = None,
) -> str:
    """ドキュメント一式を格納して doc_id を返すテストヘルパ。"""

    doc_id = make_document_id(path)
    store.upsert(Document(id=doc_id, path=path, hash="h", updated_at=NOW))
    store.index_body(doc_id, body)
    store.save_headings(doc_id, headings or [])
    store.save_links(doc_id, links or [])
    return doc_id
```

- [ ] **Step 2: 失敗するテストを書く**

`tests/application/test_relation_builder.py`:

```python
"""RelationBuilder tests."""
from pathlib import Path

import pytest

from docgraph.application.config import RelationConfig
from docgraph.application.relation_builder import RelationBuilder
from docgraph.application.stopwords_service import StopwordsService
from docgraph.domain.heading import Heading
from docgraph.domain.link import Link
from docgraph.domain.relation import Reason
from tests.application.fakes import InMemoryGraphStore, seed


@pytest.fixture()
def store() -> InMemoryGraphStore:
    return InMemoryGraphStore()


def _builder(
    store: InMemoryGraphStore, stopwords: StopwordsService | None = None
) -> RelationBuilder:
    return RelationBuilder(store, stopwords or StopwordsService([]), RelationConfig())


def test_explicit_link_relation(store: InMemoryGraphStore) -> None:
    src = seed(store, "docs/order.md", links=[Link("./customer.md", "顧客", 4)])
    dst = seed(store, "docs/customer.md")
    relations = _builder(store).build()
    assert len(relations) == 1
    rel = relations[0]
    assert (rel.source_id, rel.target_id) == (src, dst)
    assert rel.reason is Reason.EXPLICIT_LINK
    assert rel.confidence.value == 1.0
    assert rel.evidence_line == 4


def test_wiki_link_resolves_by_stem(store: InMemoryGraphStore) -> None:
    src = seed(store, "docs/order.md", links=[Link("customer", "customer", 2)])
    dst = seed(store, "docs/sub/customer.md")
    relations = _builder(store).build()
    assert [(r.source_id, r.target_id, r.reason)] == [(src, dst, Reason.EXPLICIT_LINK)]


def test_dangling_link_is_ignored(store: InMemoryGraphStore) -> None:
    seed(store, "docs/order.md", links=[Link("./missing.md", "x", 1)])
    assert _builder(store).build() == []


def test_name_mention(store: InMemoryGraphStore) -> None:
    src = seed(store, "docs/order.md", body="概要\npayment を参照。")
    dst = seed(store, "docs/payment.md")
    relations = _builder(store).build()
    assert len(relations) == 1
    rel = relations[0]
    assert (rel.source_id, rel.target_id, rel.reason) == (src, dst, Reason.NAME_MENTION)
    assert rel.confidence.value == 0.7
    assert rel.evidence_line == 2


def test_heading_mention(store: InMemoryGraphStore) -> None:
    src = seed(store, "docs/order.md", body="支払仕様 に従う。")
    dst = seed(
        store, "docs/payment.md", headings=[Heading(level=2, text="支払仕様", line=3)]
    )
    relations = _builder(store).build()
    assert [(r.source_id, r.target_id, r.reason)] == [(src, dst, Reason.HEADING_MENTION)]
    assert relations[0].confidence.value == 0.6


def test_h4_heading_is_not_a_term(store: InMemoryGraphStore) -> None:
    seed(store, "docs/order.md", body="詳細仕様サブ を参照。")
    seed(store, "docs/payment.md", headings=[Heading(level=4, text="詳細仕様サブ", line=3)])
    assert _builder(store).build() == []


def test_stopword_excludes_mention(store: InMemoryGraphStore, tmp_path: Path) -> None:
    stopfile = tmp_path / "stop.txt"
    stopfile.write_text("payment\n", encoding="utf-8")
    seed(store, "docs/order.md", body="payment を参照。")
    seed(store, "docs/payment.md")
    assert _builder(store, StopwordsService([str(stopfile)])).build() == []


def test_short_stem_is_excluded(store: InMemoryGraphStore) -> None:
    seed(store, "docs/order.md", body="ab を参照。")
    seed(store, "docs/ab.md")
    assert _builder(store).build() == []


def test_self_reference_is_excluded(store: InMemoryGraphStore) -> None:
    seed(store, "docs/order.md", body="order 自身の説明。")
    assert _builder(store).build() == []


def test_duplicate_reason_keeps_lowest_line(store: InMemoryGraphStore) -> None:
    seed(
        store,
        "docs/order.md",
        links=[Link("./customer.md", "a", 9), Link("./customer.md", "b", 4)],
    )
    seed(store, "docs/customer.md")
    relations = _builder(store).build()
    assert len(relations) == 1
    assert relations[0].evidence_line == 4
```

- [ ] **Step 3: 失敗確認**

Run: `uv run pytest tests/application/test_relation_builder.py -v`
Expected: `ModuleNotFoundError: No module named 'docgraph.application.relation_builder'` で FAIL

- [ ] **Step 4: 実装**

`src/docgraph/application/relation_builder.py`:

```python
"""RelationBuilder - 永続化済みデータから 3 種の関係エッジを導出する。"""
from __future__ import annotations

from pathlib import PurePosixPath

from docgraph.application.config import RelationConfig
from docgraph.application.ports import GraphStore
from docgraph.application.stopwords_service import StopwordsService
from docgraph.domain.confidence import Confidence
from docgraph.domain.document import Document
from docgraph.domain.link import resolve_link_target
from docgraph.domain.mention import MentionScanner
from docgraph.domain.relation import Reason, Relation

EXPLICIT_LINK_CONFIDENCE = 1.0
MAX_MENTION_HEADING_LEVEL = 3
MD_SUFFIX = ".md"

RelationKey = tuple[str, str, Reason]


class RelationBuilder:
    """explicit_link / name_mention / heading_mention のエッジを構築する。"""

    def __init__(
        self, store: GraphStore, stopwords: StopwordsService, config: RelationConfig
    ) -> None:
        self._store = store
        self._stopwords = stopwords
        self._config = config

    def build(self) -> list[Relation]:
        """全ドキュメントの関係エッジを導出して返す。"""

        docs = self._store.find_all()
        path_to_id = {d.path: d.id for d in docs}
        stem_to_id = {PurePosixPath(d.path).stem: d.id for d in docs}
        name_terms = self._name_terms(docs)
        heading_terms = self._heading_terms(docs)
        merged: dict[RelationKey, Relation] = {}
        for doc in docs:
            found = self._explicit_relations(doc, path_to_id, stem_to_id)
            found += self._mention_relations(doc, name_terms, Reason.NAME_MENTION)
            found += self._mention_relations(doc, heading_terms, Reason.HEADING_MENTION)
            _merge(merged, found)
        return list(merged.values())

    def _explicit_relations(
        self, doc: Document, path_to_id: dict[str, str], stem_to_id: dict[str, str]
    ) -> list[Relation]:
        relations: list[Relation] = []
        for link in self._store.find_links(doc.id):
            target_id = _resolve(doc.path, link.target_path, path_to_id, stem_to_id)
            if target_id is None or target_id == doc.id:
                continue
            relations.append(
                Relation(
                    doc.id, target_id, Reason.EXPLICIT_LINK,
                    Confidence(EXPLICIT_LINK_CONFIDENCE), link.line,
                )
            )
        return relations

    def _mention_relations(
        self, doc: Document, terms: dict[str, str], reason: Reason
    ) -> list[Relation]:
        body = self._store.get_body(doc.id) or ""
        confidence = self._confidence_for(reason)
        relations: list[Relation] = []
        for term, line in MentionScanner(set(terms)).scan(body).items():
            target_id = terms[term]
            if target_id != doc.id:
                relations.append(Relation(doc.id, target_id, reason, confidence, line))
        return relations

    def _confidence_for(self, reason: Reason) -> Confidence:
        if reason is Reason.NAME_MENTION:
            return Confidence(self._config.name_mention_confidence)
        return Confidence(self._config.heading_mention_confidence)

    def _name_terms(self, docs: list[Document]) -> dict[str, str]:
        terms: dict[str, str] = {}
        for doc in docs:
            stem = PurePosixPath(doc.path).stem
            if self._is_valid_term(stem, self._config.name_mention_min_length):
                terms[stem] = doc.id
        return terms

    def _heading_terms(self, docs: list[Document]) -> dict[str, str]:
        terms: dict[str, str] = {}
        for doc in docs:
            for heading in self._store.find_headings(doc.id):
                text = heading.text.strip()
                if heading.level <= MAX_MENTION_HEADING_LEVEL and self._is_valid_term(
                    text, self._config.heading_mention_min_length
                ):
                    terms[text] = doc.id
        return terms

    def _is_valid_term(self, term: str, min_length: int) -> bool:
        return len(term) >= min_length and not self._stopwords.contains(term)


def _resolve(
    source_path: str,
    target: str,
    path_to_id: dict[str, str],
    stem_to_id: dict[str, str],
) -> str | None:
    resolved = resolve_link_target(source_path, target)
    if resolved is not None and resolved in path_to_id:
        return path_to_id[resolved]
    stem = target.strip().removesuffix(MD_SUFFIX)
    return stem_to_id.get(stem)


def _merge(merged: dict[RelationKey, Relation], found: list[Relation]) -> None:
    for relation in found:
        key = (relation.source_id, relation.target_id, relation.reason)
        if key not in merged or relation.evidence_line < merged[key].evidence_line:
            merged[key] = relation
```

- [ ] **Step 5: テスト成功確認**

Run: `uv run pytest tests/application -v`
Expected: 全 PASS

- [ ] **Step 6: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/application/relation_builder.py tests/application/
git commit -m "feat(application): implement RelationBuilder with 3 edge types"
```

---

### Task 12: Application — IndexUseCase 実装

**Files:**
- Modify: `src/docgraph/application/index_usecase.py`(全面書き換え)
- Test: `tests/application/test_index_usecase.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/application/test_index_usecase.py`:

```python
"""IndexUseCase tests."""
from datetime import UTC, datetime
from pathlib import Path

from docgraph.application.config import RelationConfig
from docgraph.application.index_usecase import IndexUseCase
from docgraph.application.ports import ParsedDocument, ScannedFile
from docgraph.application.relation_builder import RelationBuilder
from docgraph.application.stopwords_service import StopwordsService
from docgraph.domain.document import Document, make_document_id
from docgraph.domain.link import Link
from tests.application.fakes import InMemoryGraphStore

NOW = datetime(2026, 7, 15, tzinfo=UTC)
EMPTY_PARSED = ParsedDocument(
    headings=[], links=[], body="", code_block_lines=frozenset()
)


class FakeScanner:
    def __init__(self, files: list[ScannedFile]) -> None:
        self._files = files

    def scan(self, root: str) -> list[ScannedFile]:
        return self._files


class FakeParser:
    def __init__(self, parsed: ParsedDocument = EMPTY_PARSED) -> None:
        self.parsed = parsed
        self.calls: list[str] = []

    def parse(self, text: str) -> ParsedDocument:
        self.calls.append(text)
        return self.parsed


def _scanned(tmp_path: Path, rel: str, content: str, hash_: str = "h1") -> ScannedFile:
    file = tmp_path / rel
    file.parent.mkdir(parents=True, exist_ok=True)
    file.write_text(content, encoding="utf-8")
    return ScannedFile(
        path=rel, absolute_path=str(file), hash=hash_, updated_at=NOW
    )


def _usecase(
    scanner: FakeScanner, parser: FakeParser, store: InMemoryGraphStore
) -> IndexUseCase:
    builder = RelationBuilder(store, StopwordsService([]), RelationConfig())
    return IndexUseCase(scanner, parser, store, builder)


def test_indexes_new_file(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    parser = FakeParser()
    file = _scanned(tmp_path, "docs/a.md", "本文")
    result = _usecase(FakeScanner([file]), parser, store).execute(str(tmp_path))
    assert result.indexed_files == 1
    assert result.skipped_files == 0
    assert parser.calls == ["本文"]
    doc = store.find_by_path("docs/a.md")
    assert doc is not None
    assert doc.hash == "h1"


def test_skips_unchanged_file(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    parser = FakeParser()
    file = _scanned(tmp_path, "docs/a.md", "本文", hash_="same")
    doc_id = make_document_id("docs/a.md")
    store.upsert(Document(id=doc_id, path="docs/a.md", hash="same", updated_at=NOW))
    result = _usecase(FakeScanner([file]), parser, store).execute(str(tmp_path))
    assert result.indexed_files == 0
    assert result.skipped_files == 1
    assert parser.calls == []


def test_reindexes_changed_file(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    parser = FakeParser()
    file = _scanned(tmp_path, "docs/a.md", "新本文", hash_="new")
    doc_id = make_document_id("docs/a.md")
    store.upsert(Document(id=doc_id, path="docs/a.md", hash="old", updated_at=NOW))
    result = _usecase(FakeScanner([file]), parser, store).execute(str(tmp_path))
    assert result.indexed_files == 1
    assert parser.calls == ["新本文"]


def test_prunes_removed_document(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    gone_id = make_document_id("docs/gone.md")
    store.upsert(Document(id=gone_id, path="docs/gone.md", hash="h", updated_at=NOW))
    _usecase(FakeScanner([]), FakeParser(), store).execute(str(tmp_path))
    assert store.find_by_id(gone_id) is None


def test_body_is_sanitized_before_fts(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    parsed = ParsedDocument(
        headings=[], links=[], body="a\ncode\nb", code_block_lines=frozenset({2})
    )
    file = _scanned(tmp_path, "docs/a.md", "a\ncode\nb")
    _usecase(FakeScanner([file]), FakeParser(parsed), store).execute(str(tmp_path))
    assert store.get_body(make_document_id("docs/a.md")) == "a\n\nb"


def test_counts_relations_by_reason(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    parsed = ParsedDocument(
        headings=[], links=[Link("./b.md", "B", 1)],
        body="", code_block_lines=frozenset(),
    )
    file_a = _scanned(tmp_path, "docs/a.md", "x", hash_="ha")
    file_b = _scanned(tmp_path, "docs/b.md", "y", hash_="hb")
    result = _usecase(FakeScanner([file_a, file_b]), FakeParser(parsed), store).execute(
        str(tmp_path)
    )
    assert result.explicit_links == 1
    assert result.name_mentions == 0
    assert result.heading_mentions == 0
    assert result.elapsed_ms >= 0


def test_unreadable_file_counted_as_skipped(tmp_path: Path) -> None:
    store = InMemoryGraphStore()
    file = tmp_path / "bad.md"
    file.write_bytes(b"\x93\xfa\x96\x7b\x8c\xea")  # Shift-JIS バイト列(UTF-8 として不正)
    scanned = ScannedFile(
        path="bad.md", absolute_path=str(file), hash="h", updated_at=NOW
    )
    result = _usecase(FakeScanner([scanned]), FakeParser(), store).execute(str(tmp_path))
    assert result.indexed_files == 0
    assert result.skipped_files == 1
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/application/test_index_usecase.py -v`
Expected: `TypeError`(コンストラクタ引数不一致)または `NotImplementedError` で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/application/index_usecase.py` 全体を置き換え:

```python
"""IndexUseCase - スキャン・パース・関係構築のオーケストレーション。"""
from __future__ import annotations

import time
from dataclasses import dataclass
from pathlib import Path

from docgraph.application.ports import (
    FileScannerPort,
    GraphStore,
    MarkdownParserPort,
    ScannedFile,
)
from docgraph.application.relation_builder import RelationBuilder
from docgraph.domain.document import Document, make_document_id
from docgraph.domain.mention import sanitize_body
from docgraph.domain.relation import Reason, Relation

MS_PER_SECOND = 1000


@dataclass(frozen=True)
class IndexResult:
    """index 1 回分のサマリ(CLI の JSON 仕様 4-3 と一致)。"""

    indexed_files: int
    skipped_files: int
    explicit_links: int
    name_mentions: int
    heading_mentions: int
    elapsed_ms: int


class IndexUseCase:
    """Markdown 群からグラフ DB を構築・更新する。"""

    def __init__(
        self,
        scanner: FileScannerPort,
        parser: MarkdownParserPort,
        store: GraphStore,
        builder: RelationBuilder,
    ) -> None:
        self._scanner = scanner
        self._parser = parser
        self._store = store
        self._builder = builder

    def execute(self, root: str) -> IndexResult:
        """root をスキャンし、変更ファイルを同期して関係を全再構築する。"""

        started = time.perf_counter()
        files = self._scanner.scan(root)
        with self._store.transaction():
            indexed, skipped = self._sync_documents(files)
            self._prune_missing(files)
            relations = self._builder.build()
            self._store.replace_all(relations)
        elapsed_ms = int((time.perf_counter() - started) * MS_PER_SECOND)
        return _result(indexed, skipped, relations, elapsed_ms)

    def _sync_documents(self, files: list[ScannedFile]) -> tuple[int, int]:
        indexed = skipped = 0
        for file in files:
            existing = self._store.find_by_path(file.path)
            if existing is not None and existing.hash == file.hash:
                skipped += 1
            elif self._index_file(file):
                indexed += 1
            else:
                skipped += 1
        return indexed, skipped

    def _index_file(self, file: ScannedFile) -> bool:
        try:
            text = Path(file.absolute_path).read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            return False
        parsed = self._parser.parse(text)
        doc = Document(
            id=make_document_id(file.path), path=file.path,
            hash=file.hash, updated_at=file.updated_at,
        )
        self._store.upsert(doc)
        self._store.save_headings(doc.id, parsed.headings)
        self._store.save_links(doc.id, parsed.links)
        self._store.index_body(doc.id, sanitize_body(parsed.body, parsed.code_block_lines))
        return True

    def _prune_missing(self, files: list[ScannedFile]) -> None:
        scanned = {file.path for file in files}
        for doc in self._store.find_all():
            if doc.path not in scanned:
                self._store.delete(doc.id)


def _result(
    indexed: int, skipped: int, relations: list[Relation], elapsed_ms: int
) -> IndexResult:
    counts = dict.fromkeys(Reason, 0)
    for relation in relations:
        counts[relation.reason] += 1
    return IndexResult(
        indexed_files=indexed,
        skipped_files=skipped,
        explicit_links=counts[Reason.EXPLICIT_LINK],
        name_mentions=counts[Reason.NAME_MENTION],
        heading_mentions=counts[Reason.HEADING_MENTION],
        elapsed_ms=elapsed_ms,
    )
```

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/application -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/application/index_usecase.py tests/application/test_index_usecase.py
git commit -m "feat(application): implement IndexUseCase with incremental sync and pruning"
```

---

### Task 13: Application — QueryUseCase 実装

**Files:**
- Modify: `src/docgraph/application/query_usecase.py`(全面書き換え)
- Test: `tests/application/test_query_usecase.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/application/test_query_usecase.py`:

```python
"""QueryUseCase tests."""
import pytest

from docgraph.application.query_usecase import (
    DocumentNotFoundError,
    QueryUseCase,
    RelatedItem,
)
from docgraph.domain.confidence import Confidence
from docgraph.domain.relation import Reason, Relation
from tests.application.fakes import InMemoryGraphStore, seed


@pytest.fixture()
def store() -> InMemoryGraphStore:
    return InMemoryGraphStore()


def _seed_relations(store: InMemoryGraphStore) -> str:
    src = seed(store, "docs/order.md")
    customer = seed(store, "docs/customer.md")
    payment = seed(store, "docs/payment.md")
    store.replace_all([
        Relation(src, payment, Reason.NAME_MENTION, Confidence(0.7), 87),
        Relation(src, customer, Reason.EXPLICIT_LINK, Confidence(1.0), 42),
    ])
    return src


def test_related_sorted_by_confidence_desc(store: InMemoryGraphStore) -> None:
    _seed_relations(store)
    items = QueryUseCase(store).related("docs/order.md")
    assert items == [
        RelatedItem("docs/customer.md", "explicit_link", 1.0, 42),
        RelatedItem("docs/payment.md", "name_mention", 0.7, 87),
    ]


def test_related_min_confidence_filters(store: InMemoryGraphStore) -> None:
    _seed_relations(store)
    items = QueryUseCase(store).related("docs/order.md", min_confidence=0.9)
    assert [item.path for item in items] == ["docs/customer.md"]


def test_related_unknown_path_raises(store: InMemoryGraphStore) -> None:
    with pytest.raises(DocumentNotFoundError):
        QueryUseCase(store).related("docs/missing.md")


def test_related_no_relations_returns_empty(store: InMemoryGraphStore) -> None:
    seed(store, "docs/lonely.md")
    assert QueryUseCase(store).related("docs/lonely.md") == []


def test_search_maps_doc_id_to_path(store: InMemoryGraphStore) -> None:
    seed(store, "docs/order.md", body="受発注の説明")
    results = QueryUseCase(store).search("受発注")
    assert len(results) == 1
    assert results[0].path == "docs/order.md"
    assert results[0].snippet


def test_search_short_keyword_raises(store: InMemoryGraphStore) -> None:
    with pytest.raises(ValueError, match="3"):
        QueryUseCase(store).search("ab")
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/application/test_query_usecase.py -v`
Expected: `ImportError`(DocumentNotFoundError 未定義)で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/application/query_usecase.py` 全体を置き換え:

```python
"""QueryUseCase - related / search クエリ処理。"""
from __future__ import annotations

from dataclasses import dataclass

from docgraph.application.ports import GraphStore

MIN_SEARCH_KEYWORD_LENGTH = 3
SCORE_DECIMALS = 2


class DocumentNotFoundError(Exception):
    """クエリ対象パスがインデックスに存在しない。"""

    def __init__(self, path: str) -> None:
        super().__init__(f"document not found in index: {path}")


@dataclass(frozen=True)
class RelatedItem:
    path: str
    reason: str
    confidence: float
    evidence_line: int


@dataclass(frozen=True)
class SearchItem:
    path: str
    score: float
    snippet: str


class QueryUseCase:
    """グラフ DB への問い合わせを担う。"""

    def __init__(self, store: GraphStore) -> None:
        self._store = store

    def related(self, path: str, min_confidence: float = 0.0) -> list[RelatedItem]:
        """関連ドキュメントを信頼度降順で返す。"""

        doc = self._store.find_by_path(path)
        if doc is None:
            raise DocumentNotFoundError(path)
        items: list[RelatedItem] = []
        for relation in self._store.find_by_source(doc.id):
            if relation.confidence.value < min_confidence:
                continue
            target = self._store.find_by_id(relation.target_id)
            if target is not None:
                items.append(
                    RelatedItem(
                        target.path, relation.reason.value,
                        relation.confidence.value, relation.evidence_line,
                    )
                )
        return sorted(items, key=lambda item: (-item.confidence, item.path))

    def search(self, keyword: str) -> list[SearchItem]:
        """FTS5 全文検索を BM25 スコア降順で返す。"""

        if len(keyword) < MIN_SEARCH_KEYWORD_LENGTH:
            raise ValueError(
                f"keyword must be at least {MIN_SEARCH_KEYWORD_LENGTH} characters"
            )
        items: list[SearchItem] = []
        for hit in self._store.search(keyword):
            doc = self._store.find_by_id(hit.doc_id)
            if doc is not None:
                items.append(
                    SearchItem(doc.path, round(hit.score, SCORE_DECIMALS), hit.snippet)
                )
        return items
```

注意: `related` メソッドが 15 行制限を超える場合は、ループ内を `_to_related_item(relation)` プライベートメソッドへ切り出す。

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/application -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/application/query_usecase.py tests/application/test_query_usecase.py
git commit -m "feat(application): implement QueryUseCase for related and search"
```

---

### Task 14: Interface — formatters 実装

**Files:**
- Modify: `src/docgraph/interface/formatters.py`(全面書き換え)
- Test: `tests/interface/__init__.py`(空ファイル新規), `tests/interface/test_formatters.py`

- [ ] **Step 1: 失敗するテストを書く**

`tests/interface/__init__.py` を空で作成し、`tests/interface/test_formatters.py`:

```python
"""Formatter tests."""
import json

from docgraph.interface.formatters import format_output

PAYLOAD: dict[str, object] = {
    "query": "docs/order.md",
    "related": [
        {"path": "docs/customer.md", "reason": "explicit_link",
         "confidence": 1.0, "evidence_line": 42},
    ],
}


def test_json_is_default_and_preserves_unicode() -> None:
    data: dict[str, object] = {"query": "受発注"}
    output = format_output(data, "json")
    assert "受発注" in output
    assert json.loads(output) == data


def test_json_roundtrip_nested() -> None:
    assert json.loads(format_output(PAYLOAD, "json")) == PAYLOAD


def test_text_format_renders_rows() -> None:
    output = format_output(PAYLOAD, "text")
    assert "query: docs/order.md" in output
    assert "docs/customer.md" in output
    with_json = False
    try:
        json.loads(output)
        with_json = True
    except json.JSONDecodeError:
        pass
    assert not with_json  # text 形式は JSON ではない
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/interface/test_formatters.py -v`
Expected: `ImportError: cannot import name 'format_output'` で FAIL

- [ ] **Step 3: 実装**

`src/docgraph/interface/formatters.py` 全体を置き換え:

```python
"""出力フォーマッタ(JSON / text)。"""
from __future__ import annotations

import json

JSON_INDENT = 2
TEXT_ROW_PREFIX = "  "


def format_output(data: dict[str, object], output_format: str) -> str:
    """data を JSON(デフォルト)またはテキストで整形する。"""

    if output_format == "text":
        return _to_text(data)
    return to_json(data)


def to_json(data: object) -> str:
    return json.dumps(data, ensure_ascii=False, indent=JSON_INDENT, default=str)


def _to_text(data: dict[str, object]) -> str:
    lines: list[str] = []
    for key, value in data.items():
        if isinstance(value, list):
            lines.append(f"{key}:")
            lines.extend(_text_row(item) for item in value)
        else:
            lines.append(f"{key}: {value}")
    return "\n".join(lines)


def _text_row(item: object) -> str:
    if isinstance(item, dict):
        return TEXT_ROW_PREFIX + "\t".join(str(v) for v in item.values())
    return f"{TEXT_ROW_PREFIX}{item}"
```

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/interface -v`
Expected: 全 PASS

- [ ] **Step 5: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/interface/formatters.py tests/interface/
git commit -m "feat(interface): implement JSON and text output formatters"
```

---

### Task 15: Interface — CLI 実配線

**Files:**
- Modify: `src/docgraph/interface/cli.py`(全面書き換え)
- Test: `tests/interface/test_cli.py`(スモークのみ。網羅は Task 16 の E2E)

- [ ] **Step 1: 失敗するテストを書く**

`tests/interface/test_cli.py`:

```python
"""CLI smoke tests."""
from typer.testing import CliRunner

from docgraph import __version__
from docgraph.interface.cli import app

runner = CliRunner()


def test_version_option() -> None:
    result = runner.invoke(app, ["--version"])
    assert result.exit_code == 0
    assert __version__ in result.stdout


def test_help_lists_commands() -> None:
    result = runner.invoke(app, ["--help"])
    assert result.exit_code == 0
    for command in ("index", "related", "search"):
        assert command in result.stdout
```

- [ ] **Step 2: 失敗確認**

Run: `uv run pytest tests/interface/test_cli.py -v`
Expected: `--version` 未実装のため test_version_option が FAIL

- [ ] **Step 3: 実装**

`src/docgraph/interface/cli.py` 全体を置き換え:

```python
"""CLI entry point using Typer."""
from __future__ import annotations

from dataclasses import asdict
from pathlib import Path

import typer

from docgraph import __version__
from docgraph.application.config import Config
from docgraph.application.index_usecase import IndexUseCase
from docgraph.application.query_usecase import DocumentNotFoundError, QueryUseCase
from docgraph.application.relation_builder import RelationBuilder
from docgraph.application.stopwords_service import StopwordsService
from docgraph.infrastructure.config_loader import load_config
from docgraph.infrastructure.file_scanner import FileScanner
from docgraph.infrastructure.markdown_parser import MarkdownParser
from docgraph.infrastructure.sqlite_store import SqliteStore

from docgraph.interface.formatters import format_output

DB_DIR = ".docgraph"
DB_NAME = "graph.db"
CONFIG_FILE = "docgraph.toml"

app = typer.Typer(help="DocGraph - Documentation relationship analysis engine")


def _version_callback(value: bool) -> None:
    if value:
        typer.echo(__version__)
        raise typer.Exit()


@app.callback()
def main(
    version: bool = typer.Option(
        False, "--version", callback=_version_callback, is_eager=True,
        help="Show version and exit.",
    ),
) -> None:
    """DocGraph CLI。"""


def _open_store(root: str) -> tuple[Config, SqliteStore]:
    config = load_config(Path(root) / CONFIG_FILE)
    store = SqliteStore(Path(root) / DB_DIR / DB_NAME)
    return config, store


def _fail(message: str) -> None:
    typer.echo(f"error: {message}", err=True)
    raise typer.Exit(code=1)


@app.command()
def index(
    root: str = typer.Option(".", "--root", help="Project root directory"),
) -> None:
    """対象ディレクトリを解析して DB を構築・更新する。"""

    config, store = _open_store(root)
    stopwords = StopwordsService(
        [str(Path(root) / file) for file in config.stopwords.files]
    )
    builder = RelationBuilder(store, stopwords, config.relation)
    scanner = FileScanner(include=config.scan.include, exclude=config.scan.exclude)
    usecase = IndexUseCase(scanner, MarkdownParser(), store, builder)
    result = usecase.execute(root)
    typer.echo(format_output(asdict(result), "json"))


@app.command()
def related(
    path: str = typer.Argument(..., help="Target file path (root-relative)"),
    min_confidence: float = typer.Option(0.0, "--min-confidence"),
    output_format: str = typer.Option("json", "--format"),
    root: str = typer.Option(".", "--root", help="Project root directory"),
) -> None:
    """指定ファイルの関連ドキュメント一覧を返す。"""

    normalized = path.replace("\\", "/")
    _, store = _open_store(root)
    try:
        items = QueryUseCase(store).related(normalized, min_confidence)
    except DocumentNotFoundError as exc:
        _fail(str(exc))
        return
    payload: dict[str, object] = {
        "query": normalized, "related": [asdict(item) for item in items],
    }
    typer.echo(format_output(payload, output_format))


@app.command()
def search(
    keyword: str = typer.Argument(..., help="Search keyword"),
    output_format: str = typer.Option("json", "--format"),
    root: str = typer.Option(".", "--root", help="Project root directory"),
) -> None:
    """キーワードを含むドキュメントを全文検索する。"""

    _, store = _open_store(root)
    try:
        items = QueryUseCase(store).search(keyword)
    except ValueError as exc:
        _fail(str(exc))
        return
    payload: dict[str, object] = {
        "query": keyword, "results": [asdict(item) for item in items],
    }
    typer.echo(format_output(payload, output_format))


if __name__ == "__main__":
    app()
```

注意:
- 旧スタブにあった `index --config` オプションは削除(設定ファイル名は要件 §6 で `docgraph.toml` 固定)。
- `related` / `search` にも `--root` を付ける(E2E で tmp ディレクトリを指すために必須。実運用ではデフォルト `.`)。
- `index` コマンドが 15 行制限に触れる場合は、UseCase 組み立て部分を `_build_index_usecase(root, config, store) -> IndexUseCase` ヘルパ関数に切り出す。

- [ ] **Step 4: テスト成功確認**

Run: `uv run pytest tests/interface -v`
Expected: 全 PASS

- [ ] **Step 5: 手動スモーク(このリポジトリ自身を index)**

```bash
uv run docgraph index --root .
uv run docgraph search "要件定義" --root .
```

Expected: JSON が出力され、docs/ 配下のファイルがヒットする(`.docgraph/graph.db` が生成される。.gitignore に `.docgraph/` が含まれることを確認)

- [ ] **Step 6: lint / type / コミット**

```bash
uv run ruff check src tests && uv run mypy src
git add src/docgraph/interface/cli.py tests/interface/test_cli.py
git commit -m "feat(interface): wire CLI commands to use cases"
```

---

### Task 16: E2E テストスイート

**Files:**
- Test: `tests/e2e/test_cli_e2e.py`

- [ ] **Step 1: E2E テストを書く**

`tests/e2e/test_cli_e2e.py`(ORDER_MD にコードフェンスを含むため外側 4 バッククォートで示す):

````python
"""E2E tests: index -> related / search via CliRunner."""
import json
from pathlib import Path
from typing import Any

import pytest
from typer.testing import CliRunner

from docgraph.interface.cli import app

runner = CliRunner()

CONFIG_TOML = """
[project]
name = "e2e"
root = "."

[scan]
include = ["docs/**/*.md"]
exclude = ["docs/archive/**"]

[stopwords]
files = [".docgraph/stopwords.txt"]
"""

ORDER_MD = """# 受発注設計

[顧客設計](./customer.md) を参照。
[[customer]] も同じ対象。
payment を参照。
支払仕様 に従う。
readme を参照。

```text
shipment はコードブロック内なので無視される
```
"""


@pytest.fixture()
def project(tmp_path: Path) -> Path:
    (tmp_path / "docgraph.toml").write_text(CONFIG_TOML, encoding="utf-8")
    (tmp_path / ".gitignore").write_text("docs/tmp/\n", encoding="utf-8")
    dg = tmp_path / ".docgraph"
    dg.mkdir()
    (dg / "stopwords.txt").write_text("readme\n", encoding="utf-8")
    docs = tmp_path / "docs"
    docs.mkdir()
    (docs / "order.md").write_text(ORDER_MD, encoding="utf-8")
    (docs / "customer.md").write_text(
        "# 顧客管理\n\n受発注の顧客側仕様。\n", encoding="utf-8"
    )
    (docs / "payment.md").write_text(
        "# 支払\n\n## 支払仕様\n\n支払の詳細。\n", encoding="utf-8"
    )
    (docs / "shipment.md").write_text("# 配送\n\n配送の仕様。\n", encoding="utf-8")
    (docs / "readme.md").write_text("# readme\n\n説明ファイル。\n", encoding="utf-8")
    archive = docs / "archive"
    archive.mkdir()
    (archive / "old.md").write_text("# 旧資料\n", encoding="utf-8")
    tmp_dir = docs / "tmp"
    tmp_dir.mkdir()
    (tmp_dir / "draft.md").write_text("# 下書き\n", encoding="utf-8")
    return tmp_path


def _run(args: list[str]) -> dict[str, Any]:
    result = runner.invoke(app, args)
    assert result.exit_code == 0, result.output
    return json.loads(result.stdout)  # type: ignore[no-any-return]


def _index(project: Path) -> dict[str, Any]:
    return _run(["index", "--root", str(project)])


def test_index_counts_and_exclusions(project: Path) -> None:
    data = _index(project)
    assert data["indexed_files"] == 5  # archive/ と tmp/ は除外
    assert data["skipped_files"] == 0
    assert data["explicit_links"] >= 1
    assert set(data) == {
        "indexed_files", "skipped_files", "explicit_links",
        "name_mentions", "heading_mentions", "elapsed_ms",
    }
    assert (project / ".docgraph" / "graph.db").exists()


def test_related_returns_three_edge_types(project: Path) -> None:
    _index(project)
    data = _run(["related", "docs/order.md", "--root", str(project)])
    assert data["query"] == "docs/order.md"
    pairs = {(item["path"], item["reason"]) for item in data["related"]}
    assert ("docs/customer.md", "explicit_link") in pairs
    assert ("docs/payment.md", "name_mention") in pairs
    assert ("docs/payment.md", "heading_mention") in pairs
    paths = {item["path"] for item in data["related"]}
    assert "docs/shipment.md" not in paths  # コードブロック内のみの言及
    assert "docs/readme.md" not in paths  # stopword
    assert "docs/order.md" not in paths  # 自己参照
    confidences = [item["confidence"] for item in data["related"]]
    assert confidences == sorted(confidences, reverse=True)


def test_explicit_and_wiki_link_dedup(project: Path) -> None:
    _index(project)
    data = _run(["related", "docs/order.md", "--root", str(project)])
    explicit_customer = [
        item for item in data["related"]
        if item["path"] == "docs/customer.md" and item["reason"] == "explicit_link"
    ]
    assert len(explicit_customer) == 1  # [text](path) と [[wiki]] がマージされる


def test_related_min_confidence(project: Path) -> None:
    _index(project)
    data = _run([
        "related", "docs/order.md", "--min-confidence", "0.9", "--root", str(project),
    ])
    assert {item["reason"] for item in data["related"]} == {"explicit_link"}


def test_search_japanese(project: Path) -> None:
    _index(project)
    data = _run(["search", "受発注", "--root", str(project)])
    assert data["query"] == "受発注"
    paths = [item["path"] for item in data["results"]]
    assert "docs/order.md" in paths
    assert "docs/customer.md" in paths
    scores = [item["score"] for item in data["results"]]
    assert scores == sorted(scores, reverse=True)
    assert all(item["snippet"] for item in data["results"])


def test_incremental_index(project: Path) -> None:
    _index(project)
    second = _index(project)
    assert second["indexed_files"] == 0
    assert second["skipped_files"] == 5
    (project / "docs" / "payment.md").write_text(
        "# 支払\n\n## 支払仕様\n\n更新された詳細。\n", encoding="utf-8"
    )
    third = _index(project)
    assert third["indexed_files"] == 1
    assert third["skipped_files"] == 4


def test_removed_file_is_pruned(project: Path) -> None:
    _index(project)
    (project / "docs" / "shipment.md").unlink()
    data = _index(project)
    assert data["skipped_files"] == 4
    result = runner.invoke(app, ["related", "docs/shipment.md", "--root", str(project)])
    assert result.exit_code == 1


def test_text_format(project: Path) -> None:
    _index(project)
    result = runner.invoke(app, [
        "related", "docs/order.md", "--format", "text", "--root", str(project),
    ])
    assert result.exit_code == 0
    assert "docs/customer.md" in result.stdout
    with pytest.raises(json.JSONDecodeError):
        json.loads(result.stdout)


def test_related_unknown_path_exits_1(project: Path) -> None:
    _index(project)
    result = runner.invoke(app, ["related", "docs/nope.md", "--root", str(project)])
    assert result.exit_code == 1


def test_search_short_keyword_exits_1(project: Path) -> None:
    _index(project)
    result = runner.invoke(app, ["search", "ab", "--root", str(project)])
    assert result.exit_code == 1
````

- [ ] **Step 2: 実行して全 PASS を確認**

Run: `uv run pytest tests/e2e -v`
Expected: 全 PASS。落ちた場合はここまでの層のバグなので、E2E テスト側を安易に緩めず原因の層(スキャナ / パーサ / ビルダー / ストア / CLI)を特定して修正する(superpowers:systematic-debugging を使用)。

- [ ] **Step 3: 全体テスト + lint / type**

Run: `uv run pytest && uv run ruff check src tests && uv run mypy src`
Expected: 全 PASS / エラーなし

- [ ] **Step 4: コミット**

```bash
git add tests/e2e/
git commit -m "test(e2e): add CLI end-to-end suite covering index/related/search"
```

---

### Task 17: 仕上げ — 配布物・品質ゲート・ドキュメント整合

**Files:**
- Modify: `config/stopwords_default.txt`(プレースホルダを実辞書で置換)
- Create: `config/stopwords_kandy.txt`
- Modify: `config/docgraph.example.toml`(`[search]` セクション削除)
- Modify: `docs/USAGE.md` / `docs/CONFIG.md` / `README.md`(実装と齟齬があれば)

- [ ] **Step 1: stopwords 配布物を整備**

`docs/stopwords_default.txt`(188 語)と `docs/stopwords_kandy.txt`(125 語)が実体。config/ 配下のプレースホルダを置き換える:

```bash
cp docs/stopwords_default.txt config/stopwords_default.txt
cp docs/stopwords_kandy.txt config/stopwords_kandy.txt
```

- [ ] **Step 2: docgraph.example.toml から `[search]` セクションを削除**

FTS トークナイザは trigram 固定(schema.sql)にしたため、`fts_tokenizer` 設定は読まれない。誤解を防ぐため example から削除し、末尾行(`[search]` と `fts_tokenizer = ...` の 2 行 + 直前の空行)を消す。

- [ ] **Step 3: ドキュメント整合確認**

`docs/USAGE.md` / `docs/CONFIG.md` / `README.md` を読み、以下と齟齬がないか確認して必要箇所のみ修正:
- コマンド体系: `docgraph index --root PATH` / `docgraph related <path> [--min-confidence F] [--format json|text] [--root PATH]` / `docgraph search <keyword> [--format json|text] [--root PATH]` / `docgraph --version`
- 検索キーワードは 3 文字以上(trigram 制約)
- `[search]` 設定は存在しない(トークナイザ固定)
- `--config` オプションは存在しない(`docgraph.toml` 固定)

- [ ] **Step 4: 品質ゲート一括実行**

Run: `make check`(= ruff / mypy / bandit / vulture / radon / deptry / pytest)
Expected: すべて成功。vulture が Protocol メソッド等を誤検知する場合のみ `.vulture_whitelist.py` に追記(実際に未使用のコードは削除が正)。radon の複雑度警告が出たらメソッド分割で解消する。

- [ ] **Step 5: パフォーマンススモーク(N-01 の事前確認)**

```bash
uv run docgraph index --root .
```

このリポジトリ(数十ファイル)で elapsed_ms を確認し、明らかな異常(数千 ms 超)がないこと。1000 ファイル規模の本計測はカンディハウス PJ 実データでの検証(チェックリスト §7)で行う。

- [ ] **Step 6: 最終コミット**

```bash
git add -A
git commit -m "chore: finalize stopwords distribution, example config, and docs for MVP-0"
```

---

## プラン完了後にユーザー(木村さん)が行うこと

このプランの範囲外(実データ・人が必要な作業。チェックリスト v0.2 §0, 7〜11 に対応):

1. カンディハウス PJ リポジトリへ導入(`pip install -e .` → `docgraph.toml` / `.docgraph/stopwords_*.txt` 配置 → 初回 `docgraph index`)
2. 実データ検証: N-01(1000 ファイル 30 秒)計測、`related` の目視確認、偽陽性語の stopwords 追加
3. CodePrep 連携確認(D-04)
4. ジュニアメンバー展開・運用ルール明文化(D-05)

## Self-Review 済み事項

- スコープ: 単一サブシステム(1 CLI パッケージ)のためプラン分割は不要。
- 要件 F1/F2/F3/F4/F6/F10 はすべて対応タスクあり(冒頭のカバレッジ表参照)。F5/F7〜F9 という ID は MVP-0 要件定義書に存在しない(欠番)。
- 型整合: `GraphStore` のメソッド名(upsert / delete / find_by_path / find_by_id / find_all / save_headings / find_headings / save_links / find_links / replace_all / find_by_source / index_body / get_body / search / transaction)は Task 5(定義)・Task 6(SqliteStore)・Task 11(InMemoryGraphStore)で一致していることを確認済み。
- 既知の残リスク: (1) markdown-it の行番号 map がテスト期待値とずれる可能性 → Task 7 に調整手順記載。(2) sqlite3 のトランザクション分離挙動 → Task 6 に autocommit=False フォールバック記載。(3) trigram で 3 文字未満検索不可 → 明示エラーで対処、ドキュメントに記載。

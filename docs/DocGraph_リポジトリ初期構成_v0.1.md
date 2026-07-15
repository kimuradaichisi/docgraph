# DocGraph リポジトリ初期構成 v0.1

- 作成日: 2026-07-15
- 位置付け: カンディハウス PJ とは別リポジトリで新規作成
- 目的: 横展開（他 PJ での再利用）を見据えた独立プロジェクト化

---

## 1. リポジトリ命名

| 項目 | 値 |
|---|---|
| リポジトリ名 | `docgraph` |
| パッケージ名 | `docgraph` |
| コマンド名 | `docgraph` |
| 配置想定 | SCSK 北海道 GitHub Enterprise / Azure DevOps いずれか |
| ライセンス | 社内標準（要確認） |

---

## 2. ディレクトリ構造

```
docgraph/
├── src/
│   └── docgraph/
│       ├── __init__.py
│       ├── domain/                    # ドメイン層
│       │   ├── __init__.py
│       │   ├── document.py            # Document エンティティ
│       │   ├── heading.py             # Heading 値オブジェクト
│       │   ├── link.py                # Link 値オブジェクト
│       │   ├── relation.py            # Relation エンティティ
│       │   └── confidence.py          # Confidence 値オブジェクト
│       ├── application/               # アプリケーション層
│       │   ├── __init__.py
│       │   ├── ports.py               # インタフェース定義
│       │   ├── index_usecase.py       # docgraph index
│       │   ├── query_usecase.py       # docgraph related / search
│       │   └── stopwords_service.py   # 除外辞書管理
│       ├── infrastructure/            # インフラ層
│       │   ├── __init__.py
│       │   ├── sqlite_store.py        # SQLite リポジトリ
│       │   ├── schema.sql             # SQLite スキーマ
│       │   ├── markdown_parser.py     # markdown-it-py ラッパ
│       │   ├── file_scanner.py        # ファイル列挙 + .gitignore
│       │   └── config_loader.py       # docgraph.toml 読込
│       └── interface/                 # インタフェース層
│           ├── __init__.py
│           ├── cli.py                 # Typer CLI エントリ
│           └── formatters.py          # JSON / text 出力
├── tests/
│   ├── domain/
│   ├── application/
│   ├── infrastructure/
│   ├── e2e/
│   └── fixtures/                      # テスト用 md ファイル
├── config/
│   ├── stopwords_default.txt          # 汎用ストップワード
│   ├── stopwords_kandy.txt            # カンディハウス PJ 用
│   └── docgraph.example.toml          # 設定ファイル雛形
├── docs/
│   ├── README.md
│   ├── USAGE.md                       # ジュニア向け運用手順
│   ├── CONFIG.md                      # 設定リファレンス
│   ├── ARCHITECTURE.md                # DDD 構造説明
│   └── ROADMAP.md                     # Phase 1〜3 の展望
├── .github/                           # or .azure-pipelines/
│   └── workflows/
│       ├── ci.yml                     # test + lint + type check
│       └── release.yml
├── pyproject.toml
├── ruff.toml
├── mypy.ini
├── .gitignore
├── AGENTS.md                          # AI エージェント向け制約
├── CLAUDE.md                          # Claude Code 向け指示
├── LICENSE
└── README.md
```

---

## 3. pyproject.toml 雛形

```toml
[project]
name = "docgraph"
version = "0.1.0"
description = "Documentation relationship analysis and knowledge graph engine"
requires-python = ">=3.12"
readme = "README.md"
authors = [
    { name = "Kimura Daichi", email = "kimura@example.com" }
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

[project.optional-dependencies]
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
```

---

## 4. カンディハウス PJ 側の設定

カンディハウス PJ リポジトリのルートに以下を配置:

### `docgraph.toml`

```toml
[project]
name = "kandy-house"
root = "."

[scan]
include = ["docs/**/*.md", "外部設計/**/*.md", "詳細設計/**/*.md"]
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
    ".docgraph/stopwords_kandy.txt",
]

[relation]
name_mention_min_length = 3
heading_mention_min_length = 3
name_mention_confidence = 0.7
heading_mention_confidence = 0.6

[search]
fts_tokenizer = "unicode61 remove_diacritics 2"
```

### `.docgraph/`

```
.docgraph/
├── graph.db                       # SQLite 本体
├── stopwords_default.txt          # docgraph からコピー
└── stopwords_kandy.txt            # カンディハウス PJ 固有
```

### `.gitignore` への追記

```
.docgraph/graph.db
.docgraph/graph.db-journal
```

`stopwords_*.txt` は Git 管理する（チームで共有すべき資産のため）。

---

## 5. AGENTS.md（AI エージェント向け制約）雛形

```markdown
# AGENTS.md

## プロジェクト概要
DocGraph はドキュメント関係性解析エンジン。DDD レイヤードアーキテクチャで構築。

## 開発制約
- Python 3.12+
- mypy strict 準拠
- Ruff によるリンティング
- 1 ファイル 300 行以内
- ドメイン層は環境依存インポート禁止（fs / http / sqlite など）
- ドメイン層 → アプリケーション層 → インフラ層 の依存方向を厳守
- テストなしのコード追加禁止

## 実装優先順位
1. ドメイン層（純粋ロジック）
2. インフラ層（SQLite / パーサ）
3. アプリケーション層（ユースケース）
4. インタフェース層（CLI）

## 禁止事項
- 外部 API 呼び出しコード
- ドキュメント本文の外部送信
- 非決定的な処理（乱数・時刻依存）
```

---

## 6. カンディハウス PJ への導入手順

```bash
# 1. DocGraph を pip install（開発版）
cd /path/to/docgraph
pip install -e .

# 2. カンディハウス PJ のルートに移動
cd /path/to/kandy-house-project

# 3. 設定ファイル配置
cp /path/to/docgraph/config/docgraph.example.toml ./docgraph.toml
# エディタで docgraph.toml を編集

# 4. stopwords 配置
mkdir -p .docgraph
cp /path/to/docgraph/config/stopwords_default.txt .docgraph/
cp /path/to/docgraph/config/stopwords_kandy.txt .docgraph/

# 5. 初回インデックス
docgraph index

# 6. 動作確認
docgraph related docs/design/order.md
docgraph search 受発注
```

---

## 7. リリース戦略（初版）

| バージョン | 位置付け |
|---|---|
| 0.1.0 | MVP-0（カンディハウス PJ で運用開始） |
| 0.2.0 | Phase 1 の一部（docx / xlsx 対応） |
| 0.3.0 | Phase 1 完成（意味類似 / 5 軸評価器） |
| 1.0.0 | Phase 2 完成（タグ埋め込み・DB プロジェクション） |

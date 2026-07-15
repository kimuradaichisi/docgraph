# DocGraph

> ドキュメント関係性解析・ナレッジグラフエンジン

DocGraph はプロジェクト内のドキュメント群を静的に解析し、関係性を SQLite ベースのナレッジグラフとして構築するツールです。散在した設計書・仕様書から関連ドキュメントを機械的に発見し、AI へのコンテキスト投入や関連ファイル特定の効率を大幅に向上させます。

## 🎯 何ができるか

- **関連ドキュメント自動発見**: 指定ファイルに関連するドキュメントを 3 種のエッジ（明示リンク / ファイル名逆引き / 見出し語逆引き）から取得
- **キーワード検索**: FTS5 による高速な全文検索
- **CodePrep 連携**: 出力 JSON を CodePrep に渡して LLM 用パッキングを自動生成
- **ローカル完結**: 外部 API 送信なし、完全ローカル動作

## 🚀 クイックスタート

### 前提

- Python 3.12+
- [uv](https://github.com/astral-sh/uv) がインストール済み

### インストール

```bash
git clone <this-repo>
cd docgraph
uv sync
```

### 使い方（3 コマンド）

```bash
# 1. プロジェクトルートで初回インデックス構築
cd /path/to/your-project
docgraph index

# 2. 指定ファイルの関連ドキュメントを取得
docgraph related docs/design/order.md

# 3. キーワードで検索
docgraph search 受発注
```

### 出力例

```json
{
  "query": "docs/design/order.md",
  "related": [
    {
      "path": "docs/design/customer.md",
      "reason": "explicit_link",
      "confidence": 1.0,
      "evidence_line": 42
    },
    {
      "path": "docs/design/payment.md",
      "reason": "name_mention",
      "confidence": 0.7,
      "evidence_line": 87
    }
  ]
}
```

## 🧩 CodePrep との連携

```bash
# 関連ファイルを CodePrep でパッキング
docgraph related docs/design/order.md --format text | codeprep pack
```

## ⚙️ 設定

プロジェクトルートに `docgraph.toml` を配置します。

```toml
[project]
name = "my-project"
root = "."

[scan]
include = ["docs/**/*.md", "外部設計/**/*.md"]
exclude = [".git/**", "node_modules/**", "**/archive/**"]

[stopwords]
files = [
    ".docgraph/stopwords_default.txt",
    ".docgraph/stopwords_project.txt"
]

[relation]
name_mention_min_length = 3
heading_mention_min_length = 3
name_mention_confidence = 0.7
heading_mention_confidence = 0.6
```

詳細は [docs/CONFIG.md](docs/CONFIG.md) を参照。

## 📚 コマンドリファレンス

### `docgraph index`

対象ディレクトリを解析して DB を構築・更新します。

```bash
docgraph index [--root PATH] [--config PATH]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `--root` | `.` | スキャン対象のルートディレクトリ |
| `--config` | `./docgraph.toml` | 設定ファイルのパス |

### `docgraph related <path>`

指定ファイルの関連ドキュメントを信頼度降順で返します。

```bash
docgraph related <path> [--min-confidence FLOAT] [--format json|text]
```

| オプション | デフォルト | 説明 |
|---|---|---|
| `--min-confidence` | `0.0` | 信頼度の下限（0.0〜1.0） |
| `--format` | `json` | 出力形式 |

### `docgraph search <keyword>`

キーワードで全文検索し、BM25 スコア順に返します。

```bash
docgraph search <keyword> [--format json|text]
```

## 🏗️ アーキテクチャ

DocGraph は DDD レイヤードアーキテクチャで構築されています。

```
Domain（内） < Application < Infrastructure / Interface（外）
```

- **Domain**: 純粋なビジネスロジック（環境依存禁止）
- **Application**: ユースケースと Ports 定義
- **Infrastructure**: SQLite / パーサ / ファイル I/O
- **Interface**: CLI

詳細は [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) を参照。

## 🧪 開発

```bash
# 開発環境セットアップ
uv sync --all-extras

# テスト実行
uv run pytest

# 型検査
uv run mypy src

# リンティング
uv run ruff check src tests

# フォーマット
uv run ruff format src tests
```

## 🗺️ ロードマップ

| Phase | スコープ |
|---|---|
| **MVP-0**（現在） | Markdown / 明示リンク / 逆引き / キーワード検索 |
| Phase 1 | docx / xlsx / pptx / pdf / 意味類似 / 5 軸評価器 |
| Phase 2 | タグ埋め込み / DB プロジェクション / 承認フロー |
| Phase 3 | スナップショット差分 / 可視化 UI / HTTP API |

詳細は [docs/ROADMAP.md](docs/ROADMAP.md) を参照。

## 📖 ドキュメント

- [USAGE.md](docs/USAGE.md) - 運用手順（ジュニアメンバー向け）
- [CONFIG.md](docs/CONFIG.md) - 設定リファレンス
- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - アーキテクチャ詳細
- [ROADMAP.md](docs/ROADMAP.md) - 開発ロードマップ

## 🤝 コントリビュート

- 1 ファイル 300 行以内 / 1 メソッド 15 行以内
- Ruff / mypy strict 準拠
- テストなしのコード追加禁止
- ドメイン層は環境依存インポート禁止

詳細は [AGENTS.md](AGENTS.md) を参照。

## 📄 ライセンス

MIT

## 👤 作成者

Daichi Kimura

# DocGraph MVP-0 要件定義書 v0.2

- 作成日: 2026-07-15
- 作成者: 木村
- 対象: カンディハウス PJ 詳細設計・製造フェーズでの即時運用
- 位置付け: ジュニアメンバーの関連ドキュメント取りこぼし防止
- 実装目標: 1 日で立ち上げ、翌日から運用開始

---

## 0. MVP-0 の目的（一言）

**「詳細設計に着手するジュニアが、関連する外部設計書・要件定義書を取りこぼさないようにする」**

これ以外の目的は MVP-0 には含めない。

---

## 1. スコープ

### 1-1. インスコープ

- ローカルディスク上の Markdown ファイルの静的解析
- SQLite による関係性の永続化
- 3 種のエッジ生成: 明示リンク / ファイル名逆引き / 見出し語逆引き
- CLI による関連パス取得とキーワード検索
- CodePrep 連携用の JSON 出力

### 1-2. アウトオブスコープ（MVP-0 では作らない）

- docx / xlsx / pptx / pdf 対応
- Shift-JIS 対応
- 意味類似（埋め込みベース）
- Git 履歴解析
- 5 軸評価器
- タグ埋め込み・DB プロジェクション
- スナップショット・差分検知
- 可視化 UI
- HTTP API
- BusinessFlow ノード

これらは最終ゴール要件（別ファイル）に定義する。

---

## 2. 前提

| ID | 内容 |
|---|---|
| P-01 | 対象は Markdown（`.md`）のみ |
| P-02 | 文字コードは UTF-8 のみ |
| P-03 | 実行環境は Python 3.12+ |
| P-04 | `.gitignore` を尊重する |
| P-05 | ローカル完結、外部 API 通信なし |
| P-06 | 単一プロジェクト内で完結、マルチプロジェクト対応なし |

---

## 3. 機能要件

### F1. ドキュメント収集

| ID | 要件 |
|---|---|
| F1-01 | 指定ルート配下を再帰的にスキャンする |
| F1-02 | `.md` 拡張子のみ対象とする |
| F1-03 | `.gitignore` を尊重する |
| F1-04 | 除外 glob を設定ファイル（`docgraph.toml`）で指定できる |
| F1-05 | ファイルパスは相対パス（プロジェクトルート起点）で保持する |
| F1-06 | ファイルハッシュ（SHA-256）と更新日時を記録する |

### F2. パース

| ID | 要件 |
|---|---|
| F2-01 | 見出し（H1〜H6）を階層付きで抽出する |
| F2-02 | 明示リンク（`[text](path)` 形式）を抽出する |
| F2-03 | Wiki リンク（`[[...]]` 形式）を抽出する |
| F2-04 | コードブロック内（``` ~ ```）はマッチング対象から除外する |
| F2-05 | 各要素は行番号を保持する |

### F3. 関係抽出

| ID | 要件 |
|---|---|
| F3-01 | **明示リンク**: F2-02 / F2-03 の結果をエッジ化する（`reason: explicit_link` / `confidence: 1.0`） |
| F3-02 | **ファイル名逆引き**: 他ドキュメントのファイル名（拡張子なし・3 文字以上）が本文に登場する箇所を検出しエッジ化する（`reason: name_mention` / `confidence: 0.7`） |
| F3-03 | **見出し語逆引き**: 他ドキュメントの H1〜H3 見出し語（3 文字以上）が本文に登場する箇所を検出しエッジ化する（`reason: heading_mention` / `confidence: 0.6`） |
| F3-04 | 同一文書内の自己参照は除外する |
| F3-05 | コードブロック内の言及は除外する（F2-04 の結果を使う） |
| F3-06 | 除外辞書（`stopwords.txt`）を持ち、そこに含まれる語はマッチ対象から除外する |

### F4. 永続化

| ID | 要件 |
|---|---|
| F4-01 | SQLite ファイル 1 つに全データを格納する（既定: `.docgraph/graph.db`） |
| F4-02 | `documents` テーブル: id / path / hash / updated_at / indexed_at |
| F4-03 | `headings` テーブル: id / doc_id / level / text / line |
| F4-04 | `links` テーブル: id / doc_id / target_path / text / line |
| F4-05 | `relations` テーブル: id / source_id / target_id / reason / confidence / evidence_line |
| F4-06 | FTS5 全文検索テーブル: doc_id / body |
| F4-07 | インデックス構築はアトミック（トランザクション） |
| F4-08 | スキーマバージョンを持ち、初回起動時に自動作成する |

### F6. Query CLI

| ID | 要件 |
|---|---|
| F6-01 | `docgraph index` : 対象ディレクトリを解析して DB を構築・更新する |
| F6-02 | `docgraph related <path>` : 指定ファイルの関連パス一覧を返す |
| F6-03 | `docgraph search <keyword>` : キーワードを含むドキュメントのパス一覧を返す |
| F6-04 | 出力形式は JSON をデフォルト、`--format text` でテキスト出力に切替可能 |
| F6-05 | `related` は信頼度降順でソートする |
| F6-06 | `related` は `--min-confidence` オプションで閾値フィルタ可能 |
| F6-07 | `search` は FTS5 の BM25 スコア順でソートする |

### F10. CodePrep 連携

| ID | 要件 |
|---|---|
| F10-01 | `docgraph related <path>` の JSON 出力を CodePrep に食わせる想定とする |
| F10-02 | 出力 JSON はパイプで CodePrep に渡せる形式とする |
| F10-03 | パス表現は CodePrep と統一（プロジェクトルート相対） |

---

## 4. 出力仕様

### 4-1. `docgraph related <path>` の出力

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
    },
    {
      "path": "docs/design/shipment.md",
      "reason": "heading_mention",
      "confidence": 0.6,
      "evidence_line": 105
    }
  ]
}
```

### 4-2. `docgraph search <keyword>` の出力

```json
{
  "query": "受発注",
  "results": [
    {"path": "docs/design/order.md", "score": 8.42, "snippet": "...受発注機能の..."},
    {"path": "docs/requirements/sales.md", "score": 6.11, "snippet": "...受発注に関する..."}
  ]
}
```

### 4-3. `docgraph index` の出力

```json
{
  "indexed_files": 234,
  "skipped_files": 3,
  "explicit_links": 156,
  "name_mentions": 412,
  "heading_mentions": 289,
  "elapsed_ms": 3421
}
```

---

## 5. 非機能要件

| ID | 要件 |
|---|---|
| N-01 | 1000 ファイル規模で `index` が 30 秒以内に完了する |
| N-02 | `related` / `search` の応答時間が 500ms 以内 |
| N-03 | Python 3.12+ / Windows・macOS・Linux で動作 |
| N-04 | 外部 API 依存なし |
| N-05 | 依存パッケージは最小限（Typer / markdown-it-py / SQLite 標準ライブラリ） |

---

## 6. 命名・配置

| 項目 | 決定 |
|---|---|
| パッケージ名 | `docgraph` |
| コマンド名 | `docgraph` |
| DB ファイル | `.docgraph/graph.db`（プロジェクトルート直下） |
| 設定ファイル | `docgraph.toml`（プロジェクトルート直下） |
| リポジトリ配置 | カンディハウス PJ 配下（別リポジトリ運用は Phase 2 で判断） |

---

## 7. 運用手順（ジュニアメンバー向け）

| 場面 | 手順 |
|---|---|
| 詳細設計に着手する時 | `docgraph related docs/design/対象.md` で関連取得 |
| AI に相談する時 | 上記出力を CodePrep に食わせてからチャットに投げる |
| キーワードで探す時 | `docgraph search "受発注機能"` |
| ドキュメント更新後 | `docgraph index` で再解析 |

---

## 8. 完了判定

MVP-0 は以下すべてを満たしたらリリースとする。

| ID | 判定基準 |
|---|---|
| D-01 | カンディハウス PJ の実データで `index` が完走する |
| D-02 | `related` が明示リンク・ファイル名逆引き・見出し語逆引きの 3 種を返す |
| D-03 | `search` が FTS5 で日本語検索できる |
| D-04 | 出力 JSON を CodePrep に食わせて動作する |
| D-05 | ジュニアメンバー 1 名が運用手順に沿って自走できる |

---

## 9. リスクと対策

| ID | リスク | 対策 |
|---|---|---|
| R-01 | ファイル名逆引きの偽陽性 | 3 文字未満は除外・除外辞書運用 |
| R-02 | 日本語全文検索の精度 | FTS5 のトークナイザに unicode61 + separators 指定、初期運用で調整 |
| R-03 | ジュニアが使わない | AI-DLC 標準手順に組み込み、詳細設計チェックリストに `docgraph related` 実行を必須化 |
| R-04 | ドキュメント配置がバラバラで効果が出ない | 導入前にディレクトリ再編を並行実施 |

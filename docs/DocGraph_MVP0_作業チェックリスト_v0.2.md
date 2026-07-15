# DocGraph MVP-0 作業チェックリスト v0.2

- 作成日: 2026-07-15
- 対象: DocGraph MVP-0 の実装〜運用開始
- 目標: 1 日で立ち上げ、翌日から運用開始
- 前提: AI エージェント（Claude Code）で実装、木村さんは指示・レビュー中心

---

## 0. 事前準備（実装前・30 分）

- [ ] カンディハウス PJ のリポジトリで対象ドキュメントの配置を把握
- [ ] 対象 `.md` ファイル数を概算（`find . -name "*.md" | wc -l`）
- [ ] リポジトリ配置場所を決定（カンディハウス PJ 配下 / 別リポジトリ）
- [ ] Python 3.12+ が実行環境に入っていることを確認
- [ ] Claude Code のワークスペース準備

---

## 1. プロジェクト初期化（1 時間）

### 1-1. リポジトリ構造

- [ ] リポジトリ作成 or ディレクトリ作成
- [ ] `pyproject.toml` 作成（プロジェクトメタ / 依存 / エントリポイント）
- [ ] ディレクトリ構造作成:
  - [ ] `src/docgraph/domain/`
  - [ ] `src/docgraph/application/`
  - [ ] `src/docgraph/infrastructure/`
  - [ ] `src/docgraph/interface/`
  - [ ] `tests/`
  - [ ] `docs/`
- [ ] `.gitignore` 追加（`.docgraph/` / `__pycache__/` / `.venv/` 等）
- [ ] `README.md` 雛形

### 1-2. 開発環境

- [ ] `uv` もしくは `poetry` で仮想環境作成
- [ ] 依存追加: `typer` / `markdown-it-py` / `pydantic` / `tomli`
- [ ] 開発依存追加: `pytest` / `mypy` / `ruff`
- [ ] `ruff.toml` / `mypy.ini` 設定
- [ ] `AGENTS.md` 作成（AI エージェント向け制約）

---

## 2. ドメイン層実装（1 時間）

- [ ] `Document` エンティティ（id / path / hash / updated_at）
- [ ] `Heading` 値オブジェクト（level / text / line）
- [ ] `Link` 値オブジェクト（target_path / text / line）
- [ ] `Relation` エンティティ（source / target / reason / confidence / evidence_line）
- [ ] `Reason` Enum（`explicit_link` / `name_mention` / `heading_mention`）
- [ ] `Confidence` 値オブジェクト（0.0〜1.0 の制約）
- [ ] ドメイン層のユニットテスト（各エンティティ / 値オブジェクト）

---

## 3. インフラ層実装（2 時間）

### 3-1. SQLite ストア

- [ ] スキーマ定義 SQL 作成
  - [ ] `documents` テーブル
  - [ ] `headings` テーブル
  - [ ] `links` テーブル
  - [ ] `relations` テーブル
  - [ ] FTS5 テーブル `documents_fts`
  - [ ] `schema_version` テーブル
- [ ] マイグレーション実装（初回起動時の自動作成）
- [ ] `DocumentRepository` 実装
- [ ] `RelationRepository` 実装
- [ ] `SearchRepository` 実装（FTS5 クエリ）
- [ ] トランザクション制御
- [ ] リポジトリのユニットテスト

### 3-2. Markdown パーサ

- [ ] `markdown-it-py` で AST 取得
- [ ] 見出し抽出（H1〜H6 / 行番号付き）
- [ ] 明示リンク抽出（`[text](path)` / 行番号付き）
- [ ] Wiki リンク抽出（`[[...]]` / 行番号付き）
- [ ] コードブロック範囲の記録（除外用）
- [ ] パーサのユニットテスト（代表的な md サンプル）

### 3-3. ファイルスキャナ

- [ ] 再帰的な `.md` ファイル列挙
- [ ] `.gitignore` 尊重（`pathspec` ライブラリ検討）
- [ ] 除外 glob 適用
- [ ] ハッシュ計算（SHA-256）
- [ ] スキャナのユニットテスト

---

## 4. アプリケーション層実装（2 時間）

### 4-1. IndexUseCase

- [ ] ファイルスキャン → パース → DB 保存
- [ ] 明示リンクからのエッジ生成
- [ ] ファイル名逆引きエッジ生成（3 文字以上 / 除外辞書適用）
- [ ] 見出し語逆引きエッジ生成（3 文字以上 / 除外辞書適用）
- [ ] コードブロック内マッチの除外
- [ ] 自己参照の除外
- [ ] インクリメンタル更新（ハッシュ差分検知）
- [ ] IndexUseCase のユニットテスト

### 4-2. QueryUseCase

- [ ] `related(path)` : 指定ファイルの関連取得
- [ ] 信頼度降順ソート
- [ ] `--min-confidence` フィルタ
- [ ] `search(keyword)` : FTS5 全文検索
- [ ] BM25 スコア順ソート
- [ ] スニペット生成
- [ ] QueryUseCase のユニットテスト

### 4-3. 除外辞書

- [ ] `stopwords.txt` の初期版作成（一般語 200 語程度）
- [ ] 設定ファイル `docgraph.toml` からの読み込み
- [ ] ユーザ辞書のマージ

---

## 5. インタフェース層実装（1 時間）

### 5-1. CLI

- [ ] Typer でエントリポイント作成
- [ ] `docgraph index [--root PATH]` コマンド
- [ ] `docgraph related <path> [--min-confidence F] [--format json|text]` コマンド
- [ ] `docgraph search <keyword> [--format json|text]` コマンド
- [ ] `docgraph --version` コマンド
- [ ] JSON 出力フォーマット統一
- [ ] エラーメッセージの標準化

### 5-2. 設定ファイル

- [ ] `docgraph.toml` の schema 定義
- [ ] デフォルト値の実装
- [ ] 設定読み込みロジック

---

## 6. 統合テスト（1 時間）

- [ ] テスト用ドキュメント群を用意（10〜20 ファイル）
- [ ] E2E: `index` → `related` → JSON 検証
- [ ] E2E: `index` → `search` → JSON 検証
- [ ] E2E: インクリメンタル更新の確認
- [ ] E2E: 除外辞書が効いていることの確認
- [ ] E2E: コードブロック内が除外されていることの確認
- [ ] E2E: 自己参照が除外されていることの確認

---

## 7. カンディハウス PJ 実データでの検証（1 時間）

- [ ] 実データで `docgraph index` 実行
- [ ] 処理時間計測（N-01 の 1000 ファイル / 30 秒 を満たすか）
- [ ] `docgraph related <代表的な外部設計書>` を数件実行
- [ ] 期待通りの関連が返るか目視確認
- [ ] `docgraph search "受発注"` 等の実クエリで検証
- [ ] 偽陽性が多い語を洗い出して stopwords に追加
- [ ] 出力 JSON を CodePrep に食わせて動作確認

---

## 8. ドキュメント整備（30 分）

- [ ] `README.md` 完成
  - [ ] インストール手順
  - [ ] 3 コマンドの使い方
  - [ ] 出力 JSON 仕様
- [ ] `USAGE.md` 作成（ジュニア向け運用手順）
- [ ] `CONFIG.md` 作成（`docgraph.toml` 全設定）
- [ ] トラブルシューティング（FAQ）

---

## 9. リリース・展開（30 分）

- [ ] `pyproject.toml` バージョン設定（`0.1.0`）
- [ ] `pip install -e .` で開発インストール確認
- [ ] `docgraph` コマンドが PATH から実行できることを確認
- [ ] カンディハウス PJ リポジトリに `docgraph.toml` と `.docgraph/` を追加
- [ ] `docgraph.toml` の除外設定をカンディハウス PJ 向けに調整
- [ ] 初回 `docgraph index` を実行して DB を配置

---

## 10. ジュニアメンバー展開（翌日以降・30 分）

### 10-1. 導入セッション

- [ ] 若手 2 名（若手-K / 若手-S）に 15 分のデモ
  - [ ] `docgraph related` の実演
  - [ ] `docgraph search` の実演
  - [ ] CodePrep への食わせ方の実演
- [ ] BP メンバーへの共有方法を PL-N と相談

### 10-2. 運用ルール明文化

- [ ] 詳細設計チェックリストに以下を追加:
  - [ ] 「着手前に `docgraph related` を実行し関連ドキュメントを確認したか」
  - [ ] 「AI に相談する前に CodePrep でパッキングしたか」
  - [ ] 「新規ドキュメント作成時に `docgraph index` を再実行したか」
- [ ] AI-DLC 標準手順書への追記

---

## 11. リリース判定チェック（完了判定）

MVP-0 完了判定基準（要件定義書 8. 完了判定と対応）:

- [ ] **D-01**: カンディハウス PJ の実データで `index` が完走する
- [ ] **D-02**: `related` が 3 種のエッジ（explicit_link / name_mention / heading_mention）を返す
- [ ] **D-03**: `search` が日本語で機能する
- [ ] **D-04**: 出力 JSON を CodePrep に食わせて動作する
- [ ] **D-05**: ジュニア 1 名が運用手順に沿って自走できる

すべてチェックが入ったら MVP-0 リリース完了。

---

## 12. Phase 1 への橋渡し（MVP-0 リリース後）

MVP-0 運用開始後、次のフェーズ判断のために以下を測定:

- [ ] 1 週間の `docgraph related` 実行回数
- [ ] 偽陽性報告件数
- [ ] ジュニアからの改善要望
- [ ] AI 呼び出しコストの変化（従来比）
- [ ] Phase 1 スコープの最終確定
  - [ ] docx / xlsx 対応の優先度
  - [ ] 意味類似導入の優先度
  - [ ] 5 軸評価器の優先度

---

## 想定タイムライン（1 日実装案）

| 時間帯 | 作業 |
|---|---|
| 9:00〜9:30 | 0. 事前準備 |
| 9:30〜10:30 | 1. プロジェクト初期化 |
| 10:30〜11:30 | 2. ドメイン層 |
| 11:30〜13:30 | 3. インフラ層（昼休憩含む） |
| 13:30〜15:30 | 4. アプリケーション層 |
| 15:30〜16:30 | 5. インタフェース層 |
| 16:30〜17:30 | 6. 統合テスト |
| 17:30〜18:30 | 7. 実データ検証 |
| 18:30〜19:00 | 8. ドキュメント |
| 19:00〜19:30 | 9. リリース準備 |

翌日: 10. ジュニア展開 → 11. 完了判定

---

## リスク・注意事項

| ID | リスク | 対策 |
|---|---|---|
| CR-01 | パーサの日本語見出し抽出が不安定 | markdown-it-py の設定を明示指定、ゴールデンテスト用意 |
| CR-02 | FTS5 の日本語トークナイザ問題 | unicode61 + separators で対応、駄目なら 2-gram フォールバック |
| CR-03 | ファイル名逆引きの偽陽性爆発 | stopwords 初期辞書を厚めに、実データで即調整 |
| CR-04 | 実装 1 日は楽観的 | 6 時間で終わらなければ 5-2（設定）と 8（ドキュメント）を翌日繰越 |
| CR-05 | ジュニアが使わない | 詳細設計チェックリストで強制、レビュー時に確認 |

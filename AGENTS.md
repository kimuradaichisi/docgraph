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

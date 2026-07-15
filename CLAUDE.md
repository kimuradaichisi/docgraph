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

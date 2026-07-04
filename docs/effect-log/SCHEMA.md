# 効果ログ スキーマ（Track B / Plans 4.4）

配布ハーネスの「実作業での実捕捉」を継続証明するテレメトリ。1 レコード = JSONL 1 行。
生ログは各リポジトリの `.claude/state/harness-telemetry/YYYY-MM.jsonl`（gitignore 済み・**非コミット**）に貯まり、
4.5 の収穫スクリプトが**サニタイズ集計値のみ**を本リポジトリへ取得する（recall 証明＝Track A とは別軸）。

## 発火点（3 経路）

| tool | 発火 | 決定性 |
|---|---|---|
| `pre-commit-gate` | `hooks/pre-commit-gate.sh`（PreToolUse で `git commit` をインターセプト） | **決定的**（シェル・主計測） |
| `code-review` | `/code-review` の統合後（Step 8） | best-effort（skill 指示） |
| `pr-review-loop` | `/pr-review-loop` の各周回 | best-effort（skill 指示） |

## フィールド

| フィールド | 型 | 説明 |
|---|---|---|
| `timestamp` | string | ISO8601 UTC（`YYYY-MM-DDThh:mm:ssZ`） |
| `tool` | string | `pre-commit-gate` / `code-review` / `pr-review-loop` |
| `model` | string | 実行モデル（ゲートは空。LLM 経路のみ設定） |
| `repo_bucket` | string | **サニタイズ済み**リポジトリ識別。basename の SHA-256 先頭 12 桁（実名を出さずリポジトリ間の区別を保つ） |
| `diff_size_bucket` | string | `xs`(<10) / `s`(<50) / `m`(<200) / `l`(<1000) / `xl`(>=1000) 行 |
| `findings.critical` / `.warning` / `.info` | int | code-review の検出件数 |
| `verified_confirmed` | int | 検証パスで confirmed になった件数 |
| `refuted` | int | 検証パスで棄却された件数 |
| `gate.type` | string | ゲート種別（`pre-commit` 等。非ゲート経路は空） |
| `gate.blocked` | bool | ブロックしたか |
| `gate.reason_category` | string | `git-add-all` / `secret-pattern` / `none` |

## サニタイズ原則

- 生ログ段階から**リポジトリ実名・SHA・指摘本文・コード断片を含めない**（`repo_bucket` はハッシュ、`findings` は件数のみ）。
- 文字列フィールドは `[A-Za-z0-9._-]` に制限（JSON インジェクションと固有名混入の二重防止）。
- 4.5 の本リポジトリ集計時に、サニタイズ検証（固有名 0 件の機械 grep）をコミットゲートにする。

## ブロック方針（誤爆防止）

全プロジェクトへ配布されるため、`deny` は**明確な事故パターンに限定**する:

- `git add -A` / `git add .` / `git add --all` の使用（CLAUDE.md「git add は明示パスのみ」の機械強制）
- staged 差分の汎用機密パターン（秘密鍵ブロック・クラウドのアクセスキー・各種トークン形式）

上記以外は **pass**。blocked・passed とも記録し、実捕捉率を算出可能にする。会社固有名等のプロジェクト依存パターンはゲートにハードコードしない（公開 hook に固有名を書かないため）。

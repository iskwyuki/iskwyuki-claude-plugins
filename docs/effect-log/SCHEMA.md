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

## 収穫（Plans 4.5）

生ログは各リポジトリの `.claude/state/` に貯まる（非コミット）。本リポジトリへは `scripts/harvest-effect-log.sh` が
**集計値のみ**を能動的に「都度取得」する（月次ルーチン 3.3 は読み取り専用でコミットしないため、収穫は手動運用）。

```sh
scripts/harvest-effect-log.sh [YYYY-MM]        # 個人リポの生ログを収穫・集計 → docs/effect-log/YYYY-MM.md（省略時は当月 UTC）
scripts/harvest-effect-log.sh --verify <file>  # 既存 md のサニタイズ検証のみ（コミット前ゲート単体実行）
```

- 対象は**個人リポジトリのみ**（会社リポは対象外）。読み取り専用で対象リポへは一切書き込まない。
- 集計 md を書き出す前に**サニタイズ検証をコミット前ゲート**として実行し、固有名（対象リポ実名）・SHA（40 桁 hex）の
  混入があれば書き出さず非ゼロ終了する。指摘本文はスキーマ上そもそも生ログに存在しない（`findings` は件数のみ）。
- 集計項目: 総レコード数 / ゲート阻止回数（reason 別）/ 重大度別検出量 / 誤修正率（refuted÷(confirmed+refuted)）/ モデル別内訳 / diff_size 分布。

---
name: bootstrap
description: iskwyuki-claude-plugins の初回セットアップ skill。Plugin install 直後に Skill tool 経由で呼び出し、SETUP.md を提示してからプロジェクトの .claude/ に全 asset を初回展開し、品質ゲート（.githooks/pre-commit）をリポジトリ構成に合わせて生成する。
---

# bootstrap

Plugin `iskwyuki-claude-plugins` を install した直後に 1 度だけ呼び出す踏み台 skill。
呼び出しは Skill tool (`iskwyuki-claude-plugins:bootstrap`) 経由。bootstrap によってプロジェクトに展開された `pull-assets` / `push-asset` は短縮名のスラッシュコマンド (`/pull-assets`, `/push-asset`) で使える。

## 手順

### Step 0: plugin キャッシュパスの解決

plugin キャッシュの実体は `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` に展開される。バージョン番号が含まれるため、最新版のパスを動的に解決する。

```bash
PLUGIN_ROOT=$(ls -d "$HOME/.claude/plugins/cache/iskwyuki-claude-plugins/iskwyuki-claude-plugins"/*/ 2>/dev/null | sort -V | tail -1 | sed 's:/*$::')
test -n "$PLUGIN_ROOT" || { echo "Plugin cache not found. Run: /plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins"; exit 1; }
echo "PLUGIN_ROOT=$PLUGIN_ROOT"
```

以降の手順では `$PLUGIN_ROOT` を使って参照する。

### Step 1: SETUP.md を提示

```bash
cat "$PLUGIN_ROOT/SETUP.md"
```

主要項目を抜粋してユーザーに伝える（初回セットアップの流れ、短縮名 skill の一覧、環境変数）。

### Step 2: 配信元キャッシュの存在確認

```bash
test -d "$PLUGIN_ROOT/assets" || echo "MISSING"
```

`MISSING` の場合はユーザーに `/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins` の実行を促して終了。

### Step 3: assets 配下のディレクトリを動的走査

配布対象を決め打ちせず、`assets/` 直下に存在するディレクトリを列挙する。

```bash
ls -1 "$PLUGIN_ROOT/assets/"
```

出力された各ディレクトリ名 `<type>` を後続の同期対象とする。現時点では `skills`, `agents` が存在するが、将来 `hooks`, `commands`, `mcp` などが増えたときも自動で対象に加わる。

### Step 4: 差分の事前提示

プロジェクトルートの `.claude/<type>/` と配信元の差分を表示する。

```bash
rsync -avn "$PLUGIN_ROOT/assets/<type>/" ./.claude/<type>/
```

新規追加 / 上書き対象を整理してユーザーに見せる。

### Step 5: 同期の実行

AskUserQuestion で「このまま同期してよいか」を確認してから実コピーする。削除はしない（プロジェクト固有ファイルを守る）。

```bash
rsync -av "$PLUGIN_ROOT/assets/<type>/" ./.claude/<type>/
```

### Step 6: settings.json への marketplace / plugin 宣言

プロジェクトの `.claude/settings.json` に以下のキーをマージする。**既存の settings.json がある場合は Read で内容を確認し、既存キーを保持したまま `extraKnownMarketplaces` と `enabledPlugins` だけを追加・更新すること**（上書きで他の設定を消さない）。

```json
{
  "extraKnownMarketplaces": {
    "iskwyuki-claude-plugins": {
      "source": {
        "source": "github",
        "repo": "iskwyuki/iskwyuki-claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "iskwyuki-claude-plugins@iskwyuki-claude-plugins": true,
    "claude-code-harness@iskwyuki-claude-plugins": true
  }
}
```

これにより、このリポジトリを開いた別環境でも marketplace 追加とプラグイン有効化（依存の claude-code-harness を含む）がプロンプト一発で再現される。

### Step 7: 品質ゲート（pre-commit）の展開

「`.githooks/pre-commit` ＋ package manager の prepare 配線」規約（portfolio で実証済み）を、リポジトリ構成を検出して展開する。

#### 原則

- ゲートに入れるのは**そのリポジトリで既に設定済みのチェックだけ**。未設定のツールを bootstrap が新規導入しない（配線が bootstrap の責務、ツール選定はリポジトリ側の責務）
- 既存の `.githooks/pre-commit` がある場合は**上書きしない**。雛形との差分を提示して手動判断に委ねる
- 配線は git ネイティブ層（`core.hooksPath`）に行う。Claude 経由・手動を問わず、すべてのコミットに適用させるため
- 緊急回避は `git commit --no-verify`（原則使わない）

#### 構成検出と prepare 配線

ルート直下のマーカーで種別を判定する（複数ある場合はルートの主言語を優先）。

| マーカー | 種別 | prepare 配線 |
|---|---|---|
| `package.json` | Node 系 | `scripts.prepare` に `git config core.hooksPath .githooks` を設定（既存の prepare がある場合は `既存コマンド && git config core.hooksPath .githooks` で連結） |
| `pyproject.toml` | Python 系 | prepare 相当がないため `git config core.hooksPath .githooks` を直接実行し、README のセットアップ手順に同コマンドを 1 行追記 |
| `Cargo.toml` | Rust 系 | 同上（cargo に prepare 相当なし） |
| いずれもなし | - | スキップし、skip 理由を完了報告に含める |

#### 雛形: Node 系（portfolio の手書き版と同一形式）

パッケージマネージャは lockfile で判定する（`pnpm-lock.yaml` → pnpm / `yarn.lock` → yarn / `package-lock.json` → npm）。以下は pnpm の例。

```sh
#!/bin/sh
# 品質ゲート: コミット前に lint と型チェックを必ず通す。
# Claude 経由・手動を問わず、すべてのコミットに git ネイティブ層で適用される。
# 緊急回避は git commit --no-verify（原則使わない）。
set -e

echo "[quality-gate] pnpm lint"
pnpm lint

echo "[quality-gate] tsc --noEmit"
pnpm exec tsc --noEmit

echo "[quality-gate] OK"
```

チェックリスト:

- [ ] `package.json` の `scripts` に `lint` があるか。なければ lint 段を省く
- [ ] `tsconfig.json` があるか。JS のみのリポジトリなら tsc 段を省く
- [ ] pnpm 以外の場合はコマンドを読み替える（npm なら `npm run lint` / `npx tsc --noEmit`）
- [ ] 生成後に `chmod +x .githooks/pre-commit`
- [ ] 検証: `pnpm install`（または prepare 手動実行）後に `git config core.hooksPath` が `.githooks` を返すこと

#### 雛形: Python 系

`pyproject.toml` に設定がある（`[tool.ruff]` / `[tool.mypy]` 等）ツールだけを段に入れる。

```sh
#!/bin/sh
# 品質ゲート: コミット前に lint と型チェックを必ず通す。
# Claude 経由・手動を問わず、すべてのコミットに git ネイティブ層で適用される。
# 緊急回避は git commit --no-verify（原則使わない）。
set -e

echo "[quality-gate] ruff check"
ruff check .

echo "[quality-gate] mypy"
mypy .

echo "[quality-gate] OK"
```

#### 雛形: Rust 系

```sh
#!/bin/sh
# 品質ゲート: コミット前にフォーマットと clippy を必ず通す。
# Claude 経由・手動を問わず、すべてのコミットに git ネイティブ層で適用される。
# 緊急回避は git commit --no-verify（原則使わない）。
set -e

echo "[quality-gate] cargo fmt --check"
cargo fmt --check

echo "[quality-gate] cargo clippy"
cargo clippy --all-targets -- -D warnings

echo "[quality-gate] OK"
```

#### 過去事例

- portfolio（Node / pnpm）: lint ＋ `tsc --noEmit` の 2 段ゲート。`prepare` 配線により clone 直後の install で自動有効化（2026-06 実証）
- アンチパターン: 未設定ツールをゲートに入れると初回コミットから fail し、`--no-verify` が常態化してゲートが形骸化する

### Step 8: 完了報告

- `.claude/` と `.githooks/` 配下の変更を `git status -- .claude/ .githooks/` で確認させる
- `git add .claude/ .githooks/`（Node 系で prepare を配線した場合は `package.json` も追加）の上で `git commit -m "chore: iskwyuki-claude-plugins 初回同期"` を案内（`git add -A` は使わない）
- 品質ゲートをスキップした場合はその理由を報告に含める
- 以降は `/pull-assets` と `/push-asset` が短縮名で利用可能になる旨を伝える

---
name: bootstrap
description: iskwyuki-claude-plugins の初回セットアップ skill。Plugin install 直後に Skill tool 経由で呼び出し、SETUP.md を提示してからプロジェクトの .claude/ に全 asset を初回展開する。
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

### Step 7: 完了報告

- `.claude/` 配下の変更を `git status -- .claude/` で確認させる
- `git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 初回同期"` を案内
- 以降は `/pull-assets` と `/push-asset` が短縮名で利用可能になる旨を伝える

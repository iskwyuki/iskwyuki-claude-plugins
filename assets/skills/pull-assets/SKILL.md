---
name: pull-assets
description: 配信元リポジトリ (iskwyuki-claude-plugins) の asset をプロジェクトの .claude/ へ同期する。assets/ 配下のディレクトリを動的走査するため、将来 hooks や commands が追加されても skill 本体の変更なしで対応する。
---

# pull-assets

Plugin キャッシュ配下の `assets/` をプロジェクトの `.claude/` にコピーする skill。2 回目以降の継続運用で使う。

## 使い方

- `/pull-assets` - assets 配下の全ディレクトリを同期
- `/pull-assets --dry-run` - 差分表示のみで実変更なし
- `/pull-assets --only=<dir>` - 特定ディレクトリだけ同期（例: `--only=skills`）

## 手順

### Step 0: plugin キャッシュパスの解決

plugin キャッシュの実体は `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` に展開される。最新版のパスを動的に解決する。

```bash
PLUGIN_ROOT=$(ls -d "$HOME/.claude/plugins/cache/iskwyuki-claude-plugins/iskwyuki-claude-plugins"/*/ 2>/dev/null | sort -V | tail -1 | sed 's:/*$::')
test -n "$PLUGIN_ROOT" || { echo "Plugin cache not found. Run: /plugin marketplace update && /plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins"; exit 1; }
```

### Step 1: 引数パース

ユーザー入力から以下を取得:
- `--dry-run` フラグ
- `--only=<dir>` の値（存在すればフィルタとして使用）

### Step 2: 配信元キャッシュの存在確認

```bash
test -d "$PLUGIN_ROOT/assets" || echo "MISSING"
```

`MISSING` の場合は以下を案内して終了:
1. `/plugin marketplace update` で最新化
2. `/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins` で再 install

### Step 3: 配布対象ディレクトリの動的走査

```bash
ls -1 "$PLUGIN_ROOT/assets/"
```

出力された各ディレクトリを配布対象として扱う。`--only=<dir>` 指定時はそのディレクトリだけに絞る。

**重要**: ハードコードで skills/agents のみを対象にしないこと。assets 直下にあるものすべてを動的に検出する。

### Step 4: 各ディレクトリの差分表示

対象ディレクトリごとに rsync の dry-run で差分を表示する。

```bash
rsync -avn "$PLUGIN_ROOT/assets/<type>/" ./.claude/<type>/
```

出力を整形し、以下を区別して提示:
- 新規追加されるファイル
- 上書きされる既存ファイル

`--dry-run` 指定時はここで終了。

### Step 5: 同期の実行

AskUserQuestion で「同期してよいか」を確認してから実コピーする。

```bash
rsync -av "$PLUGIN_ROOT/assets/<type>/" ./.claude/<type>/
```

- `--delete` は使わない（プロジェクト固有の skill を誤って削除しないため）
- コピー先ディレクトリがなければ作成される

### Step 6: 変更の報告

```bash
git status -- .claude/
```

変更されたファイルの一覧を表示し、`git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 同期"` を案内する。

## 衝突時の取扱い

配信元 asset とプロジェクト固有 skill のディレクトリ名が同じ場合、配信元側が上書きする。プロジェクト固有で独自機能を持たせたい場合は、**ディレクトリ名を配信元と重複させない命名**にすること（例: `/code-review` は配信元、`/code-review-custom` はプロジェクト固有）。

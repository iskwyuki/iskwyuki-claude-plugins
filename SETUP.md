# iskwyuki-claude-plugins セットアップ手順

この md ファイルは Plugin install 時に `~/.claude/plugins/iskwyuki-claude-plugins/SETUP.md` に配置され、`/iskwyuki-claude-plugins:bootstrap` skill から参照されます。

## 初回セットアップ

各プロジェクトのルートで以下を 1 回だけ実行します。

```
/plugin marketplace add iskwyuki/iskwyuki-claude-plugins
/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins
/iskwyuki-claude-plugins:bootstrap
git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 初回同期"
```

`/plugin install` のフォーマットは `<plugin-name>@<marketplace-name>` で、今回はどちらも同じ `iskwyuki-claude-plugins` です。

bootstrap が終わると、プロジェクトの `.claude/` に `pull-assets`, `push-asset` を含む全 asset が展開され、以降は短縮名で運用できます。

## 同梱プラグイン（claude-code-harness）

本プラグインは `plugin.json` の `dependencies` で [claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) を宣言しており、インストール時に自動でインストール・有効化されます（Claude Code v2.1.143+）。マーケットプレイス定義に外部ソースとして掲載済みのため、追加の marketplace 登録は不要です。

## 複数環境への自動展開（settings.json）

bootstrap はプロジェクトの `.claude/settings.json` に以下のキーをマージします。これをコミットしておくと、リポジトリを開いた別環境でも marketplace 追加とプラグイン有効化がプロンプト一発で再現されます。

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

## 通常の運用フロー

### 配信元の変更をプロジェクトに取り込む

```
/plugin marketplace update
/pull-assets
git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 同期"
```

### プロジェクトで作った asset を配信元に昇格する

```
/push-asset skills <name>
```

`/push-asset` 内部で配信元リポジトリ (`$CLAUDE_PLUGINS_REPO` または `~/dev/iskwyuki-claude-plugins`) に asset がコピーされます。完了後、配信元で commit & push すれば、他プロジェクトから `/pull-assets` で取得可能になります。

## 短縮名で使える主要 skill

bootstrap 完了後、以下はすべて namespace なしで呼び出せます。

| skill | 用途 |
|---|---|
| `/pull-assets` | 配信元 → プロジェクトの同期 |
| `/push-asset <type> <name>` | プロジェクト → 配信元への昇格 |
| `/review` | コードレビュー |
| `/commit` | コミットメッセージ生成 + 実行 |
| `/pr` | PR 作成 |
| `/issue` | Issue 操作 |
| `/test` | テスト実行 |
| `/todo` | オープン Issue 一覧 |
| `/code-review` | マルチエージェント並列レビュー |

配信対象の全体は `~/.claude/plugins/iskwyuki-claude-plugins/assets/` で確認できます。

## オプション

### `--dry-run`

`/pull-assets --dry-run` や `/push-asset skills foo --dry-run` で、実際にファイルを書き換えず差分だけを表示します。

### `--only=<dir>`

`/pull-assets --only=skills` のように対象ディレクトリを限定できます。hooks だけ反映したい等の場面で使用。

### 環境変数 `CLAUDE_PLUGINS_REPO`

`push-asset` が配信元リポジトリを特定するためのローカルパス。デフォルトは `~/dev/iskwyuki-claude-plugins`。別の場所に clone している場合は設定してください。

```
export CLAUDE_PLUGINS_REPO=$HOME/workspace/iskwyuki-claude-plugins
```

## トラブルシューティング

### `/plugin marketplace update` しても内容が変わらない

version が同じだと cache が更新されないケースがある。配信元で `.claude-plugin/plugin.json` の version を bump (例: `0.2.0` → `0.3.0`) してから、利用側で以下を実行:

```
/plugin marketplace update
/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins
```

もしくは cache を物理削除して強制リフレッシュ:

```
rm -rf ~/.claude/plugins/cache/iskwyuki-claude-plugins
```

その後 `/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins` で再展開。

### `/pull-assets` で想定外の上書きが発生した

`/pull-assets --dry-run` で事前に差分確認してください。プロジェクト固有の拡張は、配信元 asset と **ディレクトリ名を重複させない** 運用で衝突を回避します。

### `/push-asset` で配信元が見つからない

配信元リポジトリをローカルに clone しているか確認:

```
git clone https://github.com/iskwyuki/iskwyuki-claude-plugins.git ~/dev/iskwyuki-claude-plugins
```

もしくは `CLAUDE_PLUGINS_REPO` で別パスを指定してください。

## 新しい配布対象タイプが増えたとき

将来 `hooks`, `commands`, `mcp` などを配信する場合、配信元の `assets/` 配下に同名ディレクトリを追加するだけで `/pull-assets` が自動的に検出・同期します（skill 本体の変更は不要）。

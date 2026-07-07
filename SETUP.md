# iskwyuki-claude-plugins セットアップ手順

この md ファイルは Plugin install 時に `~/.claude/plugins/iskwyuki-claude-plugins/SETUP.md` に配置され、`/iskwyuki-claude-plugins:bootstrap` skill から参照されます。

## 初回セットアップ

各プロジェクトのルートで以下を 1 回だけ実行します。

```
/plugin marketplace add iskwyuki/iskwyuki-claude-plugins
/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins
/iskwyuki-claude-plugins:bootstrap
# bootstrap が品質ゲートを生成した場合は、完了報告が提示する明示パス（.githooks/ 等）を add に加える
git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 初回同期"
```

最後のコミットは基本 `.claude/` のみですが、bootstrap が品質ゲートを生成した場合は完了報告（Step 8）が提示する明示パス（`.githooks/`、prepare 配線時は `package.json`、セットアップ文書追記時は `README.md` 等）を加えてください。

`/plugin install` のフォーマットは `<plugin-name>@<marketplace-name>` で、今回はどちらも同じ `iskwyuki-claude-plugins` です。

bootstrap が終わると、プロジェクトの `.claude/` に `pull-assets`, `push-asset` を含む全 asset が展開され、以降は短縮名で運用できます。あわせて品質ゲート（`.githooks/pre-commit`）がリポジトリ構成（package.json / pyproject.toml / Cargo.toml）に合わせて生成されます。配線は Node 系が `scripts.prepare`、Python / Rust 系が `git config` 直接実行＋セットアップ文書への追記です。既存のフック機構がある場合・設定済みで現状 PASS するチェックが無い場合・マーカーが無い場合は生成をスキップし、理由を報告します（詳細は bootstrap skill の Step 7）。

## 配信の2レイヤー（harness はどちらで入るか）

本プラグインは性質の異なる 2 つの仕組みでアセットを配ります。**[claude-code-harness](https://github.com/Chachamaru127/claude-code-harness) は ① で自動的に入り、`pull-assets`（②）では入りません。**

| レイヤー | 運ぶもの | 入り方 | 追従 |
|---|---|---|---|
| **① Plugin 機構**（Claude Code ネイティブ） | iskwyuki 本体 + **claude-code-harness** | `/plugin install` 一発。harness は `plugin.json` の `dependencies` で自動解決され、同時に install・有効化される（インストール出力に `(+ 1 dependency: claude-code-harness)` と表示される） | marketplace / 本家追従 |
| **② asset 機構**（自作 `pull-assets` / `push-asset`） | iskwyuki 固有の軽量 skills / agents | `bootstrap` / `/pull-assets` でプロジェクトの `.claude/` にコピーしてコミット | 手動同期 |

harness は「プラグイン」であって「asset」ではないため、②（`pull-assets`）の対象には**含めません**（丸ごと `.claude/` に展開すると本家追従が壊れ、選別ミラー方針とも矛盾するため）。「iskwyuki を入れれば harness も各リポで使える」という狙いは ① の dependencies 機構だけで完結しています。

### dependencies 機構の前提と挙動

- harness は `marketplace.json` に**同一 marketplace 内の外部 github ソース**として掲載されているため、`allowCrossMarketplaceDependenciesOn` の設定なしで自動解決されます（dependencies 対応は Claude Code v2.1.110+）。追加の marketplace 登録は不要です
- 掲載はバージョンピンなし（本家デフォルトブランチ追従）です。問題が起きた場合の巻き戻しは `/iskwyuki-claude-plugins:update-plugins` の手順（`ref` / `sha` ピン留め）を参照してください
- **`plugin update` は依存を再解決しません。** 古い版から更新したなどで harness だけ欠けているリポは、そのルートで**再 install**すると補完されます（→ トラブルシューティング）

## 外部由来の選別ミラー skill（grill-me / zoom-out / prototype / find-skills）

[mattpocock/skills](https://github.com/mattpocock/skills)（MIT）と [vercel-labs/skills](https://github.com/vercel-labs/skills)（MIT）から、harness・自前 skills と役割も生成物も衝突しないものだけを選別して `assets/skills/` にミラーしています。プラグイン丸ごと同梱（mattpocock 側 15 skills）は tdd / triage / to-issues 等が harness と重複するため不採用。grill-with-docs も CONTEXT.md / ADR を生成して harness の SSOT 管理と競合するため見送りました。

- `/grill-me` — 計画・設計を 1 問ずつ（推奨回答付きで）尋問し、決定木の全分岐を解消する（生成物なし）
- `/zoom-out` — 不慣れなコード領域で 1 段抽象度を上げ、関連モジュールと呼び出し元の地図を出させる（読み取り専用・手動起動のみ）
- `/prototype` — 設計確定前に使い捨てプロトタイプ（ロジック検証用 CLI or UI バリエーション）を作り、答えが出たら削除する
- `/find-skills` — 「こういう skill ないか」に対し外部 skill エコシステムを `npx skills find / add` で横断検索・導入提案する（skills.sh インストール 1 位の発見メタ skill）

上流追従は GitHub Action（`.github/workflows/sync-upstream-skills.yml`、毎日実行）が担い、上流に差分が出ると自動で同期 PR が作成されます。対象ファイルは `.github/upstream-skills.manifest`（`<上流リポジトリ> <上流パス> <ローカルパス>` 形式）で管理し、上流リポジトリを跨いだ複数ソースに対応します。ミラーは verbatim（無改変）で、出典・ライセンスは各 skill ディレクトリの `NOTICE.md` に記載しています。

## プラグイン更新モニタ

同梱の SessionStart hook（`hooks/check-plugin-updates.sh`）が、セッション開始時にインストール済み全プラグインの更新有無をチェックし、更新があれば端末通知します。

- チェックは TTL でゲートされます（既定 12 時間、環境変数 `PLUGIN_UPDATE_CHECK_TTL_HOURS` で変更可）
- **実施・TTLスキップ・失敗・検知のすべての状態で 1 行以上のメッセージを表示**します（「更新がない」のか「チェックに失敗している」のか区別できるように）。失敗時もセッション開始は妨げません
- `sha` ピン留めされた外部ソースは「意図的な固定」とみなしチェック対象外です
- 更新の適用・巻き戻しは `/iskwyuki-claude-plugins:update-plugins` skill が担当します（適用は `claude plugin update <plugin>`、反映には再起動が必要）。この skill はプラグイン同梱のため bootstrap 不要で、プラグインを有効化した全プロジェクトで使えます

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
/iskwyuki-claude-plugins:update-plugins
```

marketplace update → plugin update → asset 同期 → commit 案内までワンステップで実行します（従来の `/plugin marketplace update` → `/pull-assets` → commit の手動フローは不要。同期だけを単体で行いたい場合は従来どおり `/pull-assets`）。

### プロジェクトで作った asset を配信元に昇格する

```
/push-asset skills <name>
```

`/push-asset` 内部で配信元リポジトリ (`$CLAUDE_PLUGINS_REPO` または `~/dev/iskwyuki-claude-plugins`) に asset がコピーされます。完了後、配信元で version bump を含めて commit & push すれば、他プロジェクトから `/iskwyuki-claude-plugins:update-plugins` で取得できます。

## 短縮名で使える主要 skill

bootstrap 完了後、以下はすべて namespace なしで呼び出せます。

| skill | 用途 |
|---|---|
| `/pull-assets` | 配信元 → プロジェクトの同期 |
| `/push-asset <type> <name>` | プロジェクト → 配信元への昇格 |
| `/commit` | コミットメッセージ生成 + 実行 |
| `/pr` | PR 作成 |
| `/issue` | Issue 操作 |
| `/test` | テスト実行 |
| `/todo` | オープン Issue 一覧 |
| `/code-review` | マルチエージェント並列レビュー（全件報告＋検証パス） |
| `/pr-review-loop` | PR のレビュー → 検証 → 修正 → 再レビューの自律ループ（マージは手動） |
| `/harvest-lessons` | git 履歴から再発パターンを抽出し rules / hooks へ昇格 |
| `/grill-me` | 計画を 1 問ずつ尋問して決定木を解消（mattpocock/skills 由来） |
| `/zoom-out` | 不慣れなコードの俯瞰地図を出させる（mattpocock/skills 由来） |
| `/prototype` | 使い捨てプロトタイプで設計を検証（mattpocock/skills 由来） |
| `/find-skills` | 外部 skill エコシステムを横断検索・導入提案（vercel-labs/skills 由来） |

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

### 既存リポで harness だけ入っていない

`iskwyuki-claude-plugins` は入っているのに `claude-code-harness` が無いリポがある場合（harness 同梱導入より前に入れた、`plugin update` だけで上げた等）。`plugin update` は依存を**再解決しない**ため、そのリポのルートで **再 install** する:

```
claude plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins --scope project
```

`(+ 1 dependency: claude-code-harness)` と表示され、harness が補完される。

## 新しい配布対象タイプが増えたとき

将来 `hooks`, `commands`, `mcp` などを配信する場合、配信元の `assets/` 配下に同名ディレクトリを追加するだけで `/pull-assets` が自動的に検出・同期します（skill 本体の変更は不要）。

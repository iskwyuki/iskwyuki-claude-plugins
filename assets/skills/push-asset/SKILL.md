---
name: push-asset
description: プロジェクトの .claude/<type>/<name>/ を配信元リポジトリ (iskwyuki-claude-plugins) の assets/ にコピーし、feature branch + PR 経由で他リポジトリからも利用できるようにする。「この skill を他リポジトリでも使いたい」導線。
---

# push-asset

プロジェクトで作成・改善した asset を配信元に昇格させる skill。
pull-assets と対になる、逆方向の同期。

**main 直接 push は行わず、必ず feature branch + Pull Request 経由で取り込む。**

## 使い方

- `/push-asset <type> <name>` - feature branch を作成し push、PR 作成ステップを案内
- `/push-asset <type> <name> --dry-run` - 差分表示のみ
- `/push-asset <type> <name> --auto-merge` - PR 作成 → squash merge → branch 削除 → local main 同期まで自動実行

`<type>` は skills / agents / hooks / commands / mcp など、プロジェクトの `.claude/` 直下にあるディレクトリ名。

## 手順

### Step 1: 引数パース

- `<type>`, `<name>` を必須引数として取得
- `--dry-run`, `--auto-merge` フラグを解釈

### Step 2: プロジェクト側の対象確認

```
test -e .claude/<type>/<name> || echo "MISSING"
```

ディレクトリまたはファイル（例: `agents/foo.md`）の存在を確認。
見つからない場合はエラーで終了。

### Step 3: 配信元リポジトリのローカルパス解決

優先順位:
1. 環境変数 `$CLAUDE_PLUGINS_REPO`
2. `~/dev/iskwyuki-claude-plugins`
3. `~/dev/claude-code-plugins`（リネーム前の後方互換）

最初に存在するものを採用。見つからなければ以下を案内して終了:

```
git clone https://github.com/iskwyuki/iskwyuki-claude-plugins.git ~/dev/iskwyuki-claude-plugins
```

### Step 4: 差分表示

配信元 `<repo>/assets/<type>/<name>` の存在確認:
- 未存在: 「新規追加」として表示
- 存在: `diff -ruN <repo>/assets/<type>/<name> .claude/<type>/<name>` で差分表示

`--dry-run` 指定時はここで終了。

### Step 5: feature branch の作成

配信元リポジトリで main を最新化してから feature branch を切る:

```
cd <repo>
git checkout main
git pull origin main
git checkout -b feat/push-<type>-<name>
```

branch 名が既に存在する場合はタイムスタンプを付ける（例: `feat/push-skills-deploy-check-20260423`）。

### Step 6: 実コピー

AskUserQuestion で「配信元に push してよいか」を確認してから実コピーする:

```
rsync -av --delete .claude/<type>/<name>/ <repo>/assets/<type>/<name>/
```

単一ファイル（agents/foo.md 等）の場合は `cp -f`。

### Step 7: commit と feature branch への push

```
cd <repo>
git add assets/<type>/<name>
git commit -m "feat(<type>): add <name>"
git push -u origin feat/push-<type>-<name>
```

### Step 8: PR 作成 + 自動 merge

`--auto-merge` 指定時は PR 作成から squash merge、remote branch 削除、local main 同期まで一気通貫で自動実行:

```
cd <repo>
gh pr create --base main --head feat/push-<type>-<name> \
  --title "feat(<type>): add <name>" \
  --body "プロジェクト <project-name> から push-asset で追加。<簡単な説明>"
gh pr merge --squash --delete-branch
git checkout main && git pull --ff-only origin main
git branch -D feat/push-<type>-<name>
```

指定がなければ PR 作成コマンドをユーザーに案内して終了する。ユーザーが GitHub 上で内容を確認してから merge する運用になる。

### Step 9: 他プロジェクトへの反映手順を案内

PR merge 後、他プロジェクトで以下を実行すれば最新の asset が届く、と伝える:

```
/plugin marketplace update
/pull-assets
git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 同期"
```

## 注意事項

- 配信元に push する asset は **技術スタックに依存しない汎用性** を持つこと。プロジェクト固有の npm スクリプトや特定フレームワーク向けの実装を含む場合は、プロジェクト側に残す判断を検討する
- 既存 asset を上書きする場合、他プロジェクトに影響するため差分を慎重に確認すること
- **main への直接 push は禁止**。必ず feature branch + PR 経由で取り込む（レビューフックや revert しやすさの確保のため）

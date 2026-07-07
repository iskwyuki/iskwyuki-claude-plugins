---
name: update-plugins
description: インストール済み Claude Code プラグインの更新確認・適用・asset 同期をワンステップで行い、問題発生時のバージョン巻き戻しも担当する。SessionStart hook（check-plugin-updates.sh）の通知から誘導される
---

# プラグイン更新スキル

インストール済みプラグインの更新を確認・適用する。問題があった場合の巻き戻し手順も提供する。

## 手順

### 更新の確認

1. `claude plugin marketplace update` で全マーケットプレイス定義を最新化する
2. 直近の SessionStart hook のチェック結果を参照する:
   ```bash
   cat "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/iskwyuki-claude-plugins}/update-check.json"
   ```
3. `updates` が空でキャッシュが古い可能性がある場合は、キャッシュを削除して hook スクリプトを直接実行する:
   ```bash
   rm -f "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/iskwyuki-claude-plugins}/update-check.json"
   bash <plugin-root>/hooks/check-plugin-updates.sh </dev/null
   ```

### 「⚠ 一部失敗」通知が出ているとき

SessionStart の「一部失敗: marketplace 定義の更新に失敗」等は、前回チェック時の一時的な失敗（ネットワーク・認証切れ等）がキャッシュされている場合が大半。以下で解消する:

1. `claude plugin marketplace update` を実行して今は成功するか確認する（成功すれば一時的な失敗だったと判断できる）
2. 失敗が再現する場合は原因を切り分ける: `gh auth status`（認証切れ）、ネットワーク到達性、`~/.claude/plugins/marketplaces/` 配下の git リポジトリの状態
3. 上記「更新の確認」手順 3 のキャッシュ削除 → hook 再実行でキャッシュを正常結果に更新する（失敗のみのキャッシュは 1 時間で自動失効するため、放置しても次回セッションで自動再チェックされる）

### 更新の適用

1. 更新対象をユーザーに提示し、適用してよいか確認する
2. 対象プラグインのインストールスコープを確認する（`claude plugin list` または `~/.claude/plugins/installed_plugins.json`）。`claude plugin update` の `--scope` 既定は **user** のため、project / local スコープのプラグインはスコープを明示しないと `not installed at scope user` で失敗する
3. `claude plugin update <plugin>@<marketplace> --scope <scope>` を対象ごとに実行する（user スコープなら `--scope` 省略可）。同一プラグインが複数プロジェクトに project スコープで入っている場合、更新は各プロジェクトディレクトリで個別に実行する
4. `iskwyuki-claude-plugins` 本体を更新した場合は、続けて下記「asset 同期」を実行する
5. **反映には Claude Code の再起動が必要**である旨を必ず伝える

### asset 同期（自作 plugin 更新時の後続ステップ・ワンステップ化）

従来の手動フロー（`/plugin marketplace update` → `/pull-assets` → commit）を本 skill 内で完結させる。`iskwyuki-claude-plugins` 本体の更新を適用した場合のみ実行する（harness 等の外部 plugin のみの更新では不要）。更新なしの場合でも、別プロジェクトで更新適用済み等の理由で `.claude/` が cache より古い疑いがあるときは `/pull-assets` 単体を案内する。

1. **配信元リポジトリ自身ではスキップ**する。判定は git 追跡済みマーカーを第一指標にする（`.claude/skills` symlink は非追跡の手元生成物で、fresh clone には存在しないため単独では偽陰性になる）。SKIP の場合は**以降の手順に進まない**:
   ```bash
   if [ -f .claude-plugin/marketplace.json ] || [ -L .claude/skills ]; then
     echo "SKIP: 配信元リポジトリ（assets/ が SSOT。git pull で直接最新化する）"
   else
     echo "PROCEED"
   fi
   ```
2. `PROCEED` の場合、更新後のキャッシュパスを**再解決**する（`claude plugin update` でバージョンディレクトリが変わるため。asset の実体は再起動前でも新版がディスクに展開済み）:
   ```bash
   PLUGIN_ROOT=$(ls -d "$HOME/.claude/plugins/cache/iskwyuki-claude-plugins/iskwyuki-claude-plugins"/*/ 2>/dev/null | sort -V | tail -1 | sed 's:/*$::')
   test -n "$PLUGIN_ROOT" || { echo "Plugin cache not found. Run: /plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins"; exit 1; }
   basename "$PLUGIN_ROOT"   # 手順「更新の適用」で適用したバージョンと一致することを確認（不一致なら cache 未反映として中止）
   ```
3. 以降は pull-assets skill と同一フロー（詳細は `$PLUGIN_ROOT/assets/skills/pull-assets/SKILL.md`＝更新後 cache 側を正とする）: `ls -1 "$PLUGIN_ROOT/assets/"` で対象を動的走査 → `rsync -avn`（dry-run）で新規/上書きの差分を提示 → ユーザー確認後に `rsync -av` で実コピー（**`--delete` は使わない**）
4. 同期後は `git status -- .claude/` を提示し、**同期で書き込んだパスだけ**を明示 add して commit を案内する（`git add .claude/` 一括は使わない — 同期対象外の `.claude/memory/` やプロジェクト固有 skill の WIP を巻き込むため）:
   ```bash
   git add .claude/<type>/<name> ...   # 手順 3 の rsync 転送結果に現れたパスを列挙（type 単位の一括 add は WIP を巻き込むため不可）
   git commit -m "chore: iskwyuki-claude-plugins 同期"
   ```

## 巻き戻し（問題が起きたとき）

ピンなし運用（常に本家最新）の前提なので、壊れた更新が入った場合は以下で固定する。

### 外部 GitHub ソースのプラグイン（例: claude-code-harness）

1. 直前まで動いていたコミットを特定する。`~/.claude/plugins/installed_plugins.json` の履歴や、upstream のリリース一覧（`gh api repos/<owner>/<repo>/releases --jq '.[].tag_name'`）から既知の正常バージョンを選ぶ
2. 配信元リポジトリ（iskwyuki/iskwyuki-claude-plugins）の `.claude-plugin/marketplace.json` で、該当エントリの `source` にピンを追加する:
   ```json
   { "source": "github", "repo": "<owner>/<repo>", "ref": "v4.14.0" }
   ```
   コミット単位で固定する場合は `"sha": "<40桁のコミットSHA>"`（ref と併記時は sha が優先）
3. 配信元の変更を commit & push し、利用側で `claude plugin marketplace update` → `claude plugin update <plugin>@<marketplace>` → 再起動
4. upstream で問題が解消されたらピンを外して戻す

### マーケットプレイス内のプラグイン（自作）

配信元リポジトリで問題のコミットを revert し、`plugin.json` の version を bump して push する。利用側は同じく marketplace update → plugin update → 再起動。

## 注意事項

- 更新の適用・巻き戻しはユーザーの承認を得てから実行する
- 巻き戻しのピン留めは恒久化しない。問題解消後に外すことを TODO として残す（Issue 化を提案する）
- `claude plugin update` が失敗する場合はキャッシュの物理削除で強制リフレッシュ: `rm -rf ~/.claude/plugins/cache/<marketplace>/<plugin>` → `claude plugin install <plugin>@<marketplace>`

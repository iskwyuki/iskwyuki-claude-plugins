---
name: update-plugins
description: インストール済み Claude Code プラグインの更新確認・適用と、問題発生時のバージョン巻き戻し。SessionStart hook（check-plugin-updates.sh）の通知から誘導される
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
4. **反映には Claude Code の再起動が必要**である旨を必ず伝える

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

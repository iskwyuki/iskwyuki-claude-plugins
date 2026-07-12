---
description: git worktree 並列開発のライフサイクル正本。worktree の作成/破棄・起動/停止（wt-up/wt-down）・ポート自動採番・設定と plugin の引き継ぎ・マニフェスト（.wt-parallel.yaml）仕様・安全不変条件の SSOT
trigger: "when working with git worktree parallel development, the .wt-parallel.yaml manifest, or wt-new/wt-up/wt-down/wt-rm scripts"
---

# wt-parallel — worktree 並列開発ライフサイクル（正本）

複数 Issue を worktree で分けて並列開発するための土台。app 固有部分はリポジトリ直下の
マニフェスト `.wt-parallel.yaml`（任意）＋フックに externalize する。設計正本は
`docs/wt-parallel-design.md`。

> **現在の配信段階（リリース 2 / Stage 2）**: 作成・破棄・引き継ぎ・plugin 登録に加え、
> **起動オーケストレーション（wt-up / wt-down・ポート自動採番・pre_start/post_start フック・
> env 式展開・health 待ち）まで対応**。マニフェスト or `start` 宣言が無ければ起動系は
> 「宣言されていません」と案内して正常終了する（opt-in・§Q9）。

## スクリプト（`scripts/`）

| スクリプト | 役割 | 段階 |
|-----------|------|------|
| `wt-identity.sh` | 共通ライブラリ（slug 正規化・`.dev/` 永続化・strict-subset パーサ〔scalar/list/2階層マップ/flow list〕・マニフェスト検証・空きポート offset 採番・env 式展開サンドボックス・plugin 可用性判定）。source して使う | S1+S2 |
| `wt-new.sh` | worktree 作成 → 引き継ぎ（`.env`/`settings.local.json`/`inherit`）→ plugin 登録 → 次手順表示 | S1 |
| `wt-rm.sh` | 破棄。plugin 対称解除 → `git worktree remove` | S1 |
| `wt-up.sh` | 起動。offset 採番 → env 展開 → pre_start → start を BG 起動 → ログ集約 → health 待ち → post_start → URL/ログパス提示 | S2 |
| `wt-down.sh` | 停止のみ（worktree・外部リソース・offset/slug は残す）| S2 |

実行例:

```sh
sh scripts/wt-new.sh  "feature/topic" [base_ref] [worktree_dir]  # 作成（stdout に worktree パス）
sh scripts/wt-up.sh   "<worktree_dir>"                           # 起動（health 緑まで待つ・省略時は現在の worktree）
sh scripts/wt-down.sh "<worktree_dir>"                           # 停止（起動プロセスのみ）
sh scripts/wt-rm.sh   "<worktree_dir>"                           # 破棄
```

## 起動 / 停止（wt-up / wt-down・§6・§7）

- **wt-up**: `start` を `.dev/logs/start.log` へ集約してバックグラウンド起動し、`health` が緑になるまで
  待って return する。マニフェスト or `start` が無ければ案内して正常終了（opt-in）。
- **ポート自動採番（§7）**: `ports.check` の全ポートが offset とともに同時に空く最小 offset を探索し、
  `WT_OFFSET` を `.dev/offset` に永続化（再起動で同じポートを再利用）。汎用側はポートの意味を持たない。
- **env 注入（§Q15）**: `env` マップ値を concrete 値へ展開して export し、`start`・`health.url`・全フックへ
  同一値で注入する。`WT_SLUG` / `WT_OFFSET` も全実行文脈へ export。
- **health（§Q12）**: `url`（curl/wget で 2xx/3xx）か `command`（exit 0）の一方。既定タイムアウト 60s。
  緑前にプロセスが落ちる / タイムアウトした場合はログ末尾を出して停止・非ゼロ終了。
- **フック（§Q13）**: `pre_start`（起動直前・失敗で中断）/ `post_start`（health 緑後・失敗で中断）を
  worktree ルートで `sh -c` 実行（注入済み env つき）。
- **wt-down**: `.dev/pid` の起動プロセスを TERM→（猶予）→KILL で停止するだけ。worktree・外部リソース・
  `.dev/offset`・slug は残す。起動記録なし / 既に停止済みは冪等に exit 0。

### env 式展開の安全境界（§12.3）

`env` 値と `health.url` は「値であってコマンドではない」ため、専用サンドボックス `wt_expand_value` で
`${VAR}` / `$VAR` / `$((算術))` のみ解決する（テンプレート全体を eval しない）。**コマンド置換 `$(...)` と
backtick は loud-error で拒否**。算術は算術コンテキスト `$(( ))`（コマンド実行不能）でのみ評価する。
一方 `start` / `hooks` / `health.command` は意図的なコマンド実行なので、注入済み env のもと `sh -c` で実行する。

## マニフェスト `.wt-parallel.yaml`（すべて任意）

- 完全な例とフィールド仕様は同ディレクトリの **`.wt-parallel.yaml.example`**。
- パーサは **yq 非依存**。bash（awk）で読む **strict-subset のみ受理**する（設計書 §5.1）:
  - 受理: トップレベルスカラ / ブロックリスト `- item` / inline flow list `[a, b]`（1 形式）/
    2 階層マップ `key:`→`  sub: val` / クォート / `#` コメント。インデントはスペース 2。
  - 明示拒否（loud error）: anchor/alias・block scalar `|`/`>`・多文書 `---`・flow map `{}`・
    inline list の入れ子・タブ・3 階層以上。
- **バリデーション（範囲外構文の loud-error 拒否）はリリース 2（6.3）で有効**。`wt-up` は起動前に
  `wt_manifest_validate` を通し、範囲外構文を明示エラーで拒否する（黙って誤読しない）。
  クォート値の中身（`uv sync && pnpm install` 等のシェル演算子）は逐語スカラとして誤検知しない。
- `wt-new` は `base_ref` と `inherit` を読む。`env`/`health`/`hooks`/`ports` は起動系（`wt-up`）が使う。
  マニフェストが無くても作成・引き継ぎ・plugin 登録は動く（起動系は opt-in）。

## 引き継ぎ（§Q16）

- 既定で `.env` と `.claude/settings.local.json` を worktree にコピー（存在すれば・無ければ無警告）。
- `inherit:` に列挙したパスを追加でコピー（非存在は無警告スキップ）。
- `.env` は書き換えない（起動時の env 上書きはリリース 2 の `env` マップで行う）。

## plugin 登録引き継ぎ（§8）

- ソース project の `enabledPlugins=true` のうち **user スコープ済みを除いた** ものを、
  新 worktree に `claude plugin install --scope project` で登録。共有キャッシュ・他 worktree に影響しない。
- 登録した plugin は `.dev/plugins` に記録し、`wt-rm` が `claude plugin uninstall --scope project` で
  **対称に解除**する（`installed_plugins.json` にダングリングを残さない）。
- `claude` / `jq` 不在、または `WT_SKIP_PLUGIN_REGISTER=1` で自動スキップ（警告のみ・処理は続行）。

## 安全不変条件（§9）

- **worktree 作成は必ず `wt-new`、片付けは必ず `wt-rm`**（`git worktree add`/`remove` 直叩き禁止）。
- **メイン worktree・未登録パスは破棄しない**（`wt-rm` が拒否する）。
- 共有外部リソース（DB コンテナ等）は worktree 操作で止めない/消さない。
- `.dev/`（slug / plugins / 将来の offset・logs）は git-native exclude（`.git/info/exclude`）に
  自動追記され全 worktree で無視される。tracked な `.gitignore` は汚さない。

## テスト

- `tests/test-wt-identity.sh`（純粋関数: slug・パーサ〔scalar/list/2階層マップ/flow list〕・
  マニフェスト検証・除外冪等・offset 採番〔`wt_port_free` スタブ〕・env 式展開サンドボックス・plugin 可用性/抽出）
- `tests/test-wt-lifecycle.sh`（統合スモーク: 作成→引き継ぎ→plugin スキップ→破棄）
- `tests/test-wt-startup.sh`（統合スモーク: wt-new→wt-up→health 緑→wt-down→wt-rm。
  command-health は常時実行、URL health＋実ポート衝突回避は python3+curl があれば実行）

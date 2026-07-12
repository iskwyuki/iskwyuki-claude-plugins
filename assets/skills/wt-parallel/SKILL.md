---
description: git worktree 並列開発のライフサイクル正本。worktree の作成/破棄・設定と plugin の引き継ぎ・マニフェスト（.wt-parallel.yaml）仕様・安全不変条件の SSOT。起動系（wt-up/down）はリリース2で追加
trigger: "when working with git worktree parallel development, the .wt-parallel.yaml manifest, or wt-new/wt-rm scripts"
---

# wt-parallel — worktree 並列開発ライフサイクル（正本）

複数 Issue を worktree で分けて並列開発するための土台。app 固有部分はリポジトリ直下の
マニフェスト `.wt-parallel.yaml`（任意）＋フックに externalize する。設計正本は
`docs/wt-parallel-design.md`。

> **現在の配信段階（リリース 1 / Stage 1）**: 作成・破棄・引き継ぎ・plugin 登録まで。
> **起動オーケストレーション（wt-up / wt-down・ポート採番・pre_start/post_start フック）は
> リリース 2 で追加予定**。それまで起動系は「宣言されていません」と案内して正常終了する。

## スクリプト（`scripts/`）

| スクリプト | 役割 | 段階 |
|-----------|------|------|
| `wt-identity.sh` | 共通ライブラリ（slug 正規化・`.dev/` 永続化・マニフェスト strict-subset パーサ・plugin 可用性判定）。source して使う | S1 |
| `wt-new.sh` | worktree 作成 → 引き継ぎ（`.env`/`settings.local.json`/`inherit`）→ plugin 登録 → 次手順表示 | S1 |
| `wt-rm.sh` | 破棄。plugin 対称解除 → `git worktree remove` | S1 |
| `wt-up.sh` / `wt-down.sh` | 起動 / 停止 | S2（未実装）|

実行例:

```sh
sh scripts/wt-new.sh "feature/topic" [base_ref] [worktree_dir]   # 作成（stdout に worktree パス）
sh scripts/wt-rm.sh  "<worktree_dir>"                            # 破棄
```

## マニフェスト `.wt-parallel.yaml`（すべて任意）

- 完全な例とフィールド仕様は同ディレクトリの **`.wt-parallel.yaml.example`**。
- パーサは **yq 非依存**。bash（awk）で読む **strict-subset のみ受理**する（設計書 §5.1）:
  - 受理: トップレベルスカラ / ブロックリスト `- item` / inline flow list `[a, b]`（1 形式）/
    2 階層マップ `key:`→`  sub: val` / クォート / `#` コメント。インデントはスペース 2。
  - 明示拒否（loud error）: anchor/alias・block scalar `|`/`>`・多文書 `---`・flow map `{}`・
    inline list の入れ子・タブ・3 階層以上。
- **⚠️ バリデーション（範囲外構文の loud-error 拒否）はリリース 2（6.3）で実装**。リリース 1 の
  パーサは寛容読みで、不正構文を黙って読み違える可能性がある（受理範囲は上記が最終目標契約）。
- **リリース 1 で実際に読むのは `base_ref` と `inherit` のみ**（`env`/`health`/`hooks`/`ports` は
  起動系＝リリース 2 で使う）。マニフェストが無くても作成・引き継ぎ・plugin 登録は動く。

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

- `tests/test-wt-identity.sh`（純粋関数: slug・パーサ・除外冪等・plugin 可用性〔非CC/オプトアウト判定〕・plugin 抽出）
- `tests/test-wt-lifecycle.sh`（統合スモーク: 作成→引き継ぎ→plugin スキップ〔オプトアウト経路〕→破棄。非CC ゲート自体は identity テストが担う）

#!/bin/sh
# 月次品質ルーチン（Plans.md 3.3、2026-07-02 設置）
# 対象は個人リポジトリのみ。非公開の外部リポジトリへのアクセスは行わない
# （定期取得は 2026-07-02 に恒久禁止が確定。docs/quality-baseline/README.md の凍結注記を参照）。
# すべて読み取り専用: git commit/push・PR 作成・公開系の操作は一切行わない。
# Mac（launchd）/ Linux（cron）共通。claude CLI が PATH にあること。
set -u
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"

REPO_DIR="$HOME/dev/iskwyuki-claude-plugins"
REPORT_DIR="$REPO_DIR/.claude/state/monthly-reports"
mkdir -p "$REPORT_DIR"
STAMP="$(date +%Y-%m)"

cd "$REPO_DIR" || exit 1

claude -p "月次品質ルーチンを実行してください（読み取り専用。git commit/push・PR 作成・公開系の操作・非公開外部リポジトリへのアクセスは禁止）:

1. 差分収穫（個人リポジトリのみ）: ~/dev/tech-blog と ~/dev/Antenna の git log を前回レポート（${REPORT_DIR}/ の最新ファイルの日付、無ければ 2026-07-02）以降に絞って確認し、assets/skills/harvest-lessons/SKILL.md の基準（再発・予防可能・ノイズ分類と裏取り）で新しいパターン候補を抽出する。候補があれば rules 追記の draft 文面をレポートに含める（対象リポジトリへの書き込みはしない）
2. 基準レビューセット比較の要否判定: docs/quality-baseline/results/ の最新結果の「モデル×資産バージョン」と現在の環境（claude --version と .claude-plugin/plugin.json の version）を比較し、変化していれば『要再実行（対象は公開ケース PF-* のみ。非公開ケースは凍結済み）』、同一なら『不要』と判定する
3. 結果を ${REPORT_DIR}/${STAMP}.md に保存する（新規発見 0 件でもその旨を記録）

レポート末尾に『次のアクション』（ユーザーが判断すべきこと）を 3 行以内でまとめること。" \
  > "$REPORT_DIR/${STAMP}-run.log" 2>&1

exit 0

#!/bin/sh
# 月次品質ルーチン（Plans.md 3.3 設置・2026-07-05 に 4.3 の公開 baseline 再走を配線）
# 対象は個人リポジトリのみ。非公開の外部リポジトリへのアクセスは行わない
# （定期取得は 2026-07-02 に恒久禁止が確定。docs/quality-baseline/README.md の凍結注記を参照）。
# 会社ケース CO-* は凍結済みで再走しない。基準セット再走は公開ケース PF-* のみ（4.3）。
# すべて読み取り専用: git commit/push・PR 作成・公開系の操作は一切行わない。
# 公開 baseline の採点結果も results/ に自動コミットせず NAS レポートに draft 保存し、反映は手動。
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
2. 基準レビューセット比較の要否判定: docs/quality-baseline/results/ の最新の公開結果（ファイル名に public を含む results）の「モデル×資産バージョン」と現在の環境（claude --version と .claude-plugin/plugin.json の version）を比較し、変化していれば『要再実行』、同一なら『不要』と判定する
3. 公開ケース baseline の再走（要再実行のときのみ・会社禁止のまま公開 PF-* のみ対象）: docs/quality-baseline/PROTOCOL.md の baseline-protocol v1 に厳密に従い、docs/quality-baseline/cases/PF-*.md の各ケースファイルに記載された取得コマンド（PF-1/2 は git -C ~/dev/portfolio show、PF-3〜8 は git -C ~/dev/Antenna show の形。読み取り専用・PF-2/5/6/8 は該当ファイルにスコープ）で各導入コミット diff を取得し、ケースごとに blind な X（code-reviewer＋design-checker 観点）/Y（silent-failure-hunter 観点）subagent を独立起動して 4 区分採点（検出/部分検出/見逃し/追加指摘）する。会社ケース CO-* および非公開リポジトリには一切アクセスしない。**採点結果は results/ に直接コミットせず、${REPORT_DIR}/${STAMP}-public-baseline-draft.md に下書きとして保存**し、サニタイズ（会社固有名 0 件・SHA 断片 0 件）を機械 grep で確認して draft に明記する
4. 結果を ${REPORT_DIR}/${STAMP}.md に保存する（新規発見 0 件・再走不要でもその旨を記録。要再実行なら draft のパスと集計サマリを含める）

レポート末尾に『次のアクション』（ユーザーが判断すべきこと）を 3 行以内でまとめること。" \
  > "$REPORT_DIR/${STAMP}-run.log" 2>&1

exit 0

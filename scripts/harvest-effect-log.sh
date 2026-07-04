#!/bin/sh
# 効果ログ収穫＋サニタイズ集計（Plans.md 4.5 / Track B）
#
# 個人リポジトリの .claude/state/harness-telemetry/YYYY-MM.jsonl（非コミット生ログ・
# スキーマ docs/effect-log/SCHEMA.md）を読み取り専用で集計し、サニタイズ検証を通過した
# 「集計値のみ」を docs/effect-log/YYYY-MM.md に書き出す。recall 証明（Track A）とは別軸で
# 「実作業での実捕捉」を継続証明する。
#
# 制約（3.3 の月次ルーチンと同じ）:
#   - 対象は個人リポジトリのみ。会社リポジトリには一切アクセスしない。
#   - 読み取り専用。対象リポへの書き込み・git commit/push・PR 作成はしない。
#   - 集計値のみをコミット。生ログ（repo 実名は元から無くハッシュ）・SHA・指摘本文は出さない。
#
# 使い方:
#   scripts/harvest-effect-log.sh [YYYY-MM]        # 収穫＋集計（省略時は当月 UTC）
#   scripts/harvest-effect-log.sh --verify <file>  # 既存 md のサニタイズ検証のみ（コミット前ゲート用）
#
# 環境変数（主にテスト用）:
#   HARVEST_REPOS  : 対象リポの絶対パスを空白区切りで上書き
#   HARVEST_OUTDIR : 出力先ディレクトリ（既定 <repo>/docs/effect-log）
set -u

REPO_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

# 収穫対象の個人リポジトリ（会社リポは含めない）。実名はこのスクリプト内に閉じ、出力 md には出さない。
DEFAULT_REPOS="$HOME/dev/iskwyuki-claude-plugins $HOME/dev/tech-blog $HOME/dev/Antenna $HOME/dev/portfolio $HOME/dev/keiba"

# 収穫対象パス群の basename を denylist として動的生成（実名リストの二重管理を避け、
# HARVEST_REPOS 上書き時もその実名を検証対象に含める）。
deny_names() { for p in $1; do basename "$p"; done; }

# ---- サニタイズ検証（コミット前ゲート） --------------------------------------
# 集計 md に固有名（対象リポ実名）・SHA が混入していないことを機械 grep で確認する。
# 指摘本文はスキーマ上そもそも生ログに存在しない（findings は件数のみ）ため構造的に 0 件。
# denylist は呼び出し前に $DENY_NAMES へ設定しておくこと。
verify_sanitized() {
  f="$1"
  bad=0
  # 40 桁以上の hex = 生 SHA の混入疑い（repo_bucket は 12 桁なので許容される）
  if LC_ALL=C grep -Eq '[0-9a-f]{40,}' "$f" 2>/dev/null; then
    echo "SANITIZE NG: 40 桁以上の hex（SHA 疑い）を検出:" >&2
    LC_ALL=C grep -nE '[0-9a-f]{40,}' "$f" >&2
    bad=1
  fi
  # 対象リポの basename 実名の混入（集計 md は repo_bucket ハッシュのみで区別すべき）
  for name in $DENY_NAMES; do
    if LC_ALL=C grep -Fq "$name" "$f" 2>/dev/null; then
      echo "SANITIZE NG: リポジトリ実名 '$name' を検出:" >&2
      LC_ALL=C grep -nF "$name" "$f" >&2
      bad=1
    fi
  done
  return $bad
}

# ---- --verify サブコマンド ---------------------------------------------------
if [ "${1:-}" = "--verify" ]; then
  target="${2:-}"
  if [ -z "$target" ] || [ ! -f "$target" ]; then
    echo "ERROR: --verify にはサニタイズ検証する md ファイルを指定してください" >&2
    exit 1
  fi
  DENY_NAMES=$(deny_names "${HARVEST_REPOS:-$DEFAULT_REPOS}")
  if verify_sanitized "$target"; then
    echo "SANITIZE OK: ${target}（固有名 0 件・SHA 0 件）"
    exit 0
  fi
  exit 1
fi

# ---- 収穫＋集計 --------------------------------------------------------------
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq が必要です" >&2; exit 1; }

MONTH="${1:-}"
[ -z "$MONTH" ] && MONTH=$(date -u +%Y-%m)
case "$MONTH" in
  [0-9][0-9][0-9][0-9]-[0-9][0-9]) ;;
  *) echo "ERROR: 月は YYYY-MM 形式で指定してください（指定: '$MONTH'）" >&2; exit 1;;
esac

REPOS="${HARVEST_REPOS:-$DEFAULT_REPOS}"
OUTDIR="${HARVEST_OUTDIR:-$REPO_ROOT/docs/effect-log}"
DENY_NAMES=$(deny_names "$REPOS")
GEN_DATE=$(date -u +%Y-%m-%d)

TMP=$(mktemp) || exit 1
TMP_MD="$TMP.md"
trap 'rm -f "$TMP" "$TMP_MD"' EXIT INT TERM

# 生ログを収集（該当月のみ）。読み取り専用。
# JSON オブジェクト行のみ採用（非オブジェクトの有効 JSON〔123 / [] / "s"〕・壊れ行はスキップ）。
# 末尾に改行が無い最終行も救済（`|| [ -n "$line" ]`）。
FOUND_REPOS=0
SKIPPED=0
for r in $REPOS; do
  f="$r/.claude/state/harness-telemetry/$MONTH.jsonl"
  [ -f "$f" ] || continue
  FOUND_REPOS=$((FOUND_REPOS + 1))
  while IFS= read -r line || [ -n "$line" ]; do
    [ -z "$line" ] && continue
    if printf '%s\n' "$line" | jq -e 'type=="object"' >/dev/null 2>&1; then
      printf '%s\n' "$line" >> "$TMP"
    else
      SKIPPED=$((SKIPPED + 1))
    fi
  done < "$f"
done
[ "$SKIPPED" -gt 0 ] && echo "WARN: 非オブジェクト/壊れ行を $SKIPPED 件スキップしました" >&2

# 集計（jq slurp で 1 パス）。TMP はオブジェクト行のみなのでインデックスエラーは起きない。
SUMMARY=$(jq -s '{
  total: length,
  repos: ([.[] | .repo_bucket // empty] | unique | length),
  gate_total: (map(select(.tool=="pre-commit-gate")) | length),
  gate_blocked: (map(select(.gate.blocked==true)) | length),
  crit: (map(.findings.critical) | add // 0),
  warn: (map(.findings.warning) | add // 0),
  info: (map(.findings.info) | add // 0),
  confirmed: (map(.verified_confirmed) | add // 0),
  refuted: (map(.refuted) | add // 0)
}' "$TMP") || { echo "ERROR: 集計 jq に失敗しました" >&2; exit 1; }

get() { printf '%s' "$SUMMARY" | jq -r "(.$1) // 0"; }
TOTAL=$(get total); REPOS_N=$(get repos)
GATE_TOTAL=$(get gate_total); GATE_BLOCKED=$(get gate_blocked)
CRIT=$(get crit); WARN=$(get warn); INFO=$(get info)
CONFIRMED=$(get confirmed); REFUTED=$(get refuted)

# 誤修正率 = refuted / (confirmed + refuted)
DENOM=$((CONFIRMED + REFUTED))
if [ "$DENOM" -gt 0 ]; then
  FALSEFIX=$(awk "BEGIN{printf \"%.1f\", $REFUTED*100/$DENOM}")
  FALSEFIX_STR="${FALSEFIX}%（refuted ${REFUTED} / confirmed+refuted ${DENOM}）"
else
  FALSEFIX_STR="N/A（confirmed+refuted = 0）"
fi

# md へ補間する文字列フィールドは jq gsub で [A-Za-z0-9._-] に再サニタイズ（多層防御 層 2）。
# add は空群で null になり得るため必ず // 0 を付す。
gate_reason_rows() {
  jq -rs 'def s:(tostring|gsub("[^A-Za-z0-9._-]";""));
    map(select(.tool=="pre-commit-gate")) | group_by(.gate.reason_category)
    | map("| \(.[0].gate.reason_category|s) | \(map(select(.gate.blocked==true))|length) | \(map(select(.gate.blocked==false))|length) |")
    | .[]' "$TMP"
}
model_rows() {
  jq -rs 'def s:(tostring|gsub("[^A-Za-z0-9._-]";""));
    map(select((.model // "") != "")) | group_by(.model)
    | map("| \(.[0].model|s) | \(length) | \(map(.findings.critical)|add // 0) | \(map(.findings.warning)|add // 0) | \(map(.findings.info)|add // 0) | \(map(.verified_confirmed)|add // 0) | \(map(.refuted)|add // 0) |")
    | .[]' "$TMP"
}
diff_rows() {
  jq -rs 'def s:(tostring|gsub("[^A-Za-z0-9._-]";"")); def ord:{"xs":0,"s":1,"m":2,"l":3,"xl":4};
    group_by(.diff_size_bucket) | sort_by(ord[.[0].diff_size_bucket] // 99)
    | map("| \(.[0].diff_size_bucket|s) | \(length) |")
    | .[]' "$TMP"
}
GATE_ROWS=$(gate_reason_rows); [ -z "$GATE_ROWS" ] && GATE_ROWS="| （記録なし） | 0 | 0 |"
MODEL_ROWS=$(model_rows); [ -z "$MODEL_ROWS" ] && MODEL_ROWS="| （記録なし） | 0 | 0 | 0 | 0 | 0 | 0 |"
DIFF_ROWS=$(diff_rows); [ -z "$DIFF_ROWS" ] && DIFF_ROWS="| （記録なし） | 0 |"

# md 組み立て（集計値のみ。repo 実名・SHA・指摘本文は一切含めない）
{
  echo "# 効果ログ集計 ${MONTH}（Track B / Plans 4.5）"
  echo ""
  echo "- **生成**: \`scripts/harvest-effect-log.sh\`（$GEN_DATE 手動実行・集計値のみコミット）"
  echo "- **対象**: 個人リポジトリのみ（会社リポジトリは対象外／読み取り専用収穫）"
  echo "- **サニタイズ検証**: 固有名 0 件・SHA 0 件（機械 grep 済み・コミット前ゲート通過）。指摘本文はスキーマ上生ログに存在しない（構造的に 0）"
  echo "- **軸**: recall 証明（Track A）とは別軸の「実作業での実捕捉」継続証明"
  echo ""
  echo "## 収集サマリ"
  echo ""
  echo "- 総レコード数: **$TOTAL**"
  echo "- 収穫できたリポジトリ数（telemetry ファイル存在）: **$FOUND_REPOS**"
  echo "- レコード上のリポジトリ数（repo_bucket ユニーク）: **$REPOS_N**"
  echo ""
  echo "## ゲート阻止回数（pre-commit・決定的経路）"
  echo ""
  echo "- ゲート発火（記録）回数: **$GATE_TOTAL** / うち阻止（blocked）: **$GATE_BLOCKED**"
  echo ""
  echo "| reason_category | blocked | passed |"
  echo "|---|---|---|"
  printf '%s\n' "$GATE_ROWS"
  echo ""
  echo "## 重大度別検出量（code-review / pr-review-loop）"
  echo ""
  echo "| severity | count |"
  echo "|---|---|"
  echo "| critical | $CRIT |"
  echo "| warning | $WARN |"
  echo "| info | $INFO |"
  echo ""
  echo "## 誤修正率（検証パス）"
  echo ""
  echo "- confirmed: **$CONFIRMED** / refuted: **$REFUTED**"
  echo "- 誤修正率: **$FALSEFIX_STR**"
  echo ""
  echo "## モデル別内訳（LLM 経路のみ）"
  echo ""
  echo "| model | records | critical | warning | info | confirmed | refuted |"
  echo "|---|---|---|---|---|---|---|"
  printf '%s\n' "$MODEL_ROWS"
  echo ""
  echo "## diff_size 分布"
  echo ""
  echo "| bucket | records |"
  echo "|---|---|"
  printf '%s\n' "$DIFF_ROWS"
  echo ""
  echo "---"
  echo ""
  echo "**注記**: 集計は各リポジトリのローカル telemetry を都度収穫したスナップショット。"
  echo "hook が有効なリポジトリでのみ蓄積されるため、カバレッジは配布 hook の展開状況に依存する"
  echo "（未展開リポは 0 件計上。展開が進むほど母数が増える）。生ログは非コミット・集計値のみ本リポジトリに残す。"
} > "$TMP_MD"

# サニタイズ検証（コミット前ゲート）: 通過しなければ書き出さない
if ! verify_sanitized "$TMP_MD"; then
  echo "ERROR: サニタイズ検証に失敗しました。集計 md は書き出しません（$OUTDIR/$MONTH.md は変更なし）。" >&2
  exit 1
fi

mkdir -p "$OUTDIR" || exit 1
cp "$TMP_MD" "$OUTDIR/$MONTH.md" || exit 1
echo "OK: $OUTDIR/$MONTH.md を生成（$TOTAL レコード・$FOUND_REPOS リポジトリから収穫・サニタイズ検証 通過）"

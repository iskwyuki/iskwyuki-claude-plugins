#!/bin/sh
# 効果ログ emit（Plans 4.4 / Track B）。決定的に JSON 1 行を追記する。
# LLM に JSON を手書きさせず、本スクリプトが値を受けて JSON を組む（スキーマ: docs/effect-log/SCHEMA.md）。
# 出力先: ${HARNESS_TELEMETRY_DIR:-<repo>/.claude/state/harness-telemetry}/YYYY-MM.jsonl（gitignore 済み・非コミット）
set -u

TOOL=""; MODEL=""; CRIT=0; WARN=0; INFO=0; CONFIRMED=0; REFUTED=0
GATE_TYPE=""; GATE_BLOCKED="false"; GATE_REASON=""; DIFF_LINES=0; REPO_PATH=""

while [ $# -gt 0 ]; do
  case "$1" in
    --tool) TOOL="${2:-}"; shift 2;;
    --model) MODEL="${2:-}"; shift 2;;
    --critical) CRIT="${2:-0}"; shift 2;;
    --warning) WARN="${2:-0}"; shift 2;;
    --info) INFO="${2:-0}"; shift 2;;
    --confirmed) CONFIRMED="${2:-0}"; shift 2;;
    --refuted) REFUTED="${2:-0}"; shift 2;;
    --gate-type) GATE_TYPE="${2:-}"; shift 2;;
    --gate-blocked) GATE_BLOCKED="${2:-false}"; shift 2;;
    --gate-reason) GATE_REASON="${2:-}"; shift 2;;
    --diff-lines) DIFF_LINES="${2:-0}"; shift 2;;
    --repo-path) REPO_PATH="${2:-}"; shift 2;;
    *) shift;;
  esac
done

# 文字列フィールドを [A-Za-z0-9._-] に制限（JSON インジェクション・固有名混入の二重防止）
san() { printf '%s' "${1:-}" | tr -cd 'A-Za-z0-9._-'; }
TOOL=$(san "$TOOL"); MODEL=$(san "$MODEL")
GATE_TYPE=$(san "$GATE_TYPE"); GATE_REASON=$(san "$GATE_REASON")

# 数値フィールドのバリデーション（非数値は 0）
is_int() { case "${1:-}" in ''|*[!0-9]*) return 1;; *) return 0;; esac; }
is_int "$CRIT" || CRIT=0; is_int "$WARN" || WARN=0; is_int "$INFO" || INFO=0
is_int "$CONFIRMED" || CONFIRMED=0; is_int "$REFUTED" || REFUTED=0
is_int "$DIFF_LINES" || DIFF_LINES=0

# repo_bucket: basename をハッシュ化（実名を出さずリポジトリ間の区別を保つ）
if [ -n "$REPO_PATH" ]; then
  BASE=$(basename "$REPO_PATH")
  if command -v sha256sum >/dev/null 2>&1; then
    REPO_BUCKET=$(printf '%s' "$BASE" | sha256sum | cut -c1-12)
  elif command -v shasum >/dev/null 2>&1; then
    REPO_BUCKET=$(printf '%s' "$BASE" | shasum -a 256 | cut -c1-12)
  else
    REPO_BUCKET="nohash"
  fi
else
  REPO_BUCKET="unknown"
fi

# diff_size_bucket
if [ "$DIFF_LINES" -lt 10 ]; then DSB="xs"
elif [ "$DIFF_LINES" -lt 50 ]; then DSB="s"
elif [ "$DIFF_LINES" -lt 200 ]; then DSB="m"
elif [ "$DIFF_LINES" -lt 1000 ]; then DSB="l"
else DSB="xl"; fi

# gate.blocked を bool に正規化
case "$GATE_BLOCKED" in true|1|yes) GB=true;; *) GB=false;; esac

# 出力先の決定（テストは HARNESS_TELEMETRY_DIR で上書き）
OUTDIR="${HARNESS_TELEMETRY_DIR:-}"
if [ -z "$OUTDIR" ]; then
  if [ -n "$REPO_PATH" ]; then ROOT="$REPO_PATH"
  else ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "."); fi
  OUTDIR="$ROOT/.claude/state/harness-telemetry"
fi
mkdir -p "$OUTDIR" || exit 1

TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)
MONTH=$(date -u +%Y-%m)
OUTFILE="$OUTDIR/$MONTH.jsonl"

printf '{"timestamp":"%s","tool":"%s","model":"%s","repo_bucket":"%s","diff_size_bucket":"%s","findings":{"critical":%d,"warning":%d,"info":%d},"verified_confirmed":%d,"refuted":%d,"gate":{"type":"%s","blocked":%s,"reason_category":"%s"}}\n' \
  "$TS" "$TOOL" "$MODEL" "$REPO_BUCKET" "$DSB" "$CRIT" "$WARN" "$INFO" "$CONFIRMED" "$REFUTED" "$GATE_TYPE" "$GB" "$GATE_REASON" \
  >> "$OUTFILE"

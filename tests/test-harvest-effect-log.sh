#!/bin/sh
# tests: scripts/harvest-effect-log.sh（Plans 4.5）
# 集計の正しさ・C1（非オブジェクト行）回帰・文字列インジェクション無害化・
# サニタイズゲート（コミット前）・空データ頑健性を固定する。
set -u
FAIL=0
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
SCRIPT="$ROOT/scripts/harvest-effect-log.sh"
TMP=$(mktemp -d)
REPO="$TMP/sampleproj"                       # 定型文の部分文字列にならない安全な名前
DIR="$REPO/.claude/state/harness-telemetry"
OUT="$TMP/out"
mkdir -p "$DIR"

fail() { echo "FAIL: $1"; FAIL=1; }

# rec tool model repo_bucket diff_bucket crit warn info conf ref blocked reason
rec() {
  printf '{"tool":"%s","model":"%s","repo_bucket":"%s","diff_size_bucket":"%s","findings":{"critical":%s,"warning":%s,"info":%s},"verified_confirmed":%s,"refuted":%s,"gate":{"type":"","blocked":%s,"reason_category":"%s"}}\n' \
    "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$9" "${10}" "${11}"
}

# 1) 基本集計（4 集計項目）
{
  rec code-review claude-opus-4-8 aaaaaaaaaaaa s 2 1 0 2 1 false ""
  rec pre-commit-gate "" aaaaaaaaaaaa xs 0 0 0 0 0 true git-add-all
  rec pre-commit-gate "" bbbbbbbbbbbb xs 0 0 0 0 0 false none
} > "$DIR/2026-05.jsonl"
HARVEST_REPOS="$REPO" HARVEST_OUTDIR="$OUT" sh "$SCRIPT" 2026-05 >/dev/null 2>&1 || fail "1: exit non-zero"
MD="$OUT/2026-05.md"
[ -f "$MD" ] || fail "1: md not created"
grep -q '総レコード数: \*\*3\*\*' "$MD" || fail "1: total should be 3"
grep -q '阻止（blocked）: \*\*1\*\*' "$MD" || fail "1: blocked should be 1"
grep -q '| critical | 2 |' "$MD" || fail "1: critical 2"
grep -q '| claude-opus-4-8 | 1 |' "$MD" || fail "1: model row"
grep -q '33.3%' "$MD" || fail "1: false-fix 33.3% (refuted1/denom3)"
grep -q 'git-add-all' "$MD" || fail "1: gate reason row"

# 2) C1 回帰: 非オブジェクト/壊れ行スキップ・空欄を出さない
{
  rec code-review claude-opus-4-8 cccccccccccc s 1 0 0 1 0 false ""
  echo '123'; echo '[]'; echo '"x"'; echo 'broken'
} > "$DIR/2026-06.jsonl"
HARVEST_REPOS="$REPO" HARVEST_OUTDIR="$OUT" sh "$SCRIPT" 2026-06 >/dev/null 2>&1 || fail "2: exit non-zero"
grep -q '総レコード数: \*\*1\*\*' "$OUT/2026-06.md" || fail "2: total 1 after skipping non-objects"
grep -q '総レコード数: \*\*\*\*' "$OUT/2026-06.md" && fail "2: empty total leaked (C1 regression)"

# 3) インジェクション: model の | と改行が gsub 除去され列破壊しない
printf '{"tool":"code-review","model":"evil|x\\ninj","repo_bucket":"dddddddddddd","diff_size_bucket":"m","findings":{"critical":0,"warning":0,"info":0},"verified_confirmed":0,"refuted":0,"gate":{"type":"","blocked":false,"reason_category":""}}\n' > "$DIR/2026-08.jsonl"
HARVEST_REPOS="$REPO" HARVEST_OUTDIR="$OUT" sh "$SCRIPT" 2026-08 >/dev/null 2>&1 || fail "3: exit non-zero"
grep -q '| evilxinj | 1 |' "$OUT/2026-08.md" || fail "3: model not sanitized to evilxinj"
grep -qx 'inj' "$OUT/2026-08.md" && fail "3: injected newline created a stray line"

# 4) サニタイズゲート（コミット前）: リポ名/SHA 混入 → 失敗、clean → 成功
printf 'x sampleproj y\n' > "$TMP/leak-name.md"
HARVEST_REPOS="$REPO" sh "$SCRIPT" --verify "$TMP/leak-name.md" >/dev/null 2>&1 && fail "4: repo name leak not blocked"
printf 'sha 0123456789abcdef0123456789abcdef01234567\n' > "$TMP/leak-sha.md"
sh "$SCRIPT" --verify "$TMP/leak-sha.md" >/dev/null 2>&1 && fail "4: 40hex sha not blocked"
sh "$SCRIPT" --verify "$MD" >/dev/null 2>&1 || fail "4: clean md wrongly blocked"

# 5) 空データ → total 0・exit 0
HARVEST_REPOS="$TMP/none" HARVEST_OUTDIR="$OUT" sh "$SCRIPT" 2026-01 >/dev/null 2>&1 || fail "5: empty exit non-zero"
grep -q '総レコード数: \*\*0\*\*' "$OUT/2026-01.md" || fail "5: empty total should be 0"

rm -rf "$TMP"
if [ "$FAIL" -eq 0 ]; then echo "test-harvest-effect-log: ALL PASS"; else echo "test-harvest-effect-log: FAILED"; fi
exit "$FAIL"

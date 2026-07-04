#!/bin/sh
# tests: hooks/log-effect.sh（Plans 4.4）
set -u
FAIL=0
SCRIPT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/hooks/log-effect.sh"
TMP=$(mktemp -d)
export HARNESS_TELEMETRY_DIR="$TMP/telemetry"

fail() { echo "FAIL: $1"; FAIL=1; }

# 1) 基本 emit で 1 行追記され、フィールドが正しい
sh "$SCRIPT" --tool code-review --model claude-opus-4-8 \
  --critical 2 --warning 3 --info 1 --confirmed 4 --refuted 1 \
  --diff-lines 120 --repo-path /home/user/myrepo
OUT=$(ls "$HARNESS_TELEMETRY_DIR"/*.jsonl 2>/dev/null | head -1)
[ -n "$OUT" ] || fail "output file not created"
[ "$(wc -l < "$OUT" | tr -d ' ')" = "1" ] || fail "expected 1 line"
grep -q '"tool":"code-review"' "$OUT" || fail "tool field"
grep -q '"model":"claude-opus-4-8"' "$OUT" || fail "model field"
grep -q '"critical":2' "$OUT" || fail "critical field"
grep -q '"warning":3' "$OUT" || fail "warning field"
grep -q '"verified_confirmed":4' "$OUT" || fail "confirmed field"
grep -q '"diff_size_bucket":"m"' "$OUT" || fail "diff bucket m for 120 lines"
# repo_bucket は実名を含まない（サニタイズ）
grep -q 'myrepo' "$OUT" && fail "repo name leaked into log"

# 2) 追記される（2 行目）＋ gate 経路 ＋ 境界 bucket
sh "$SCRIPT" --tool pre-commit-gate --gate-type pre-commit \
  --gate-blocked true --gate-reason git-add-all --diff-lines 5 --repo-path /home/user/myrepo
[ "$(wc -l < "$OUT" | tr -d ' ')" = "2" ] || fail "expected 2 lines after append"
tail -1 "$OUT" | grep -q '"blocked":true' || fail "gate blocked true"
tail -1 "$OUT" | grep -q '"reason_category":"git-add-all"' || fail "reason category"
tail -1 "$OUT" | grep -q '"diff_size_bucket":"xs"' || fail "diff bucket xs for 5 lines"

# 3) 文字列インジェクションのサニタイズ
sh "$SCRIPT" --tool 'evil","x":"y' --diff-lines 0 --repo-path /r
tail -1 "$OUT" | grep -q 'evil","x"' && fail "injection not sanitized"

# 4) 非数値の findings は 0 に落ちる
sh "$SCRIPT" --tool code-review --critical NaN --diff-lines abc --repo-path /r
tail -1 "$OUT" | grep -q '"critical":0' || fail "non-numeric critical not coerced to 0"

rm -rf "$TMP"
if [ "$FAIL" -eq 0 ]; then echo "test-log-effect: ALL PASS"; else echo "test-log-effect: FAILED"; fi
exit "$FAIL"

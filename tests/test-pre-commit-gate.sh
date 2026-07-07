#!/bin/sh
# tests: hooks/pre-commit-gate.sh（Plans 4.4）
set -u
FAIL=0
GATE="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/hooks/pre-commit-gate.sh"
TMP=$(mktemp -d)
export HARNESS_TELEMETRY_DIR="$TMP/tele"

fail() { echo "FAIL: $1"; FAIL=1; }

# temp git リポジトリを用意
( cd "$TMP" && git init -q && git config user.email t@t && git config user.name t )
cd "$TMP"

payload() { printf '{"tool_name":"Bash","tool_input":{"command":"%s"}}' "$1"; }

# A) 明示 add ＋ 通常 commit（clean）→ 許可(exit 0)・blocked:false・1 行記録
echo "hello world" > a.txt
git add a.txt
payload "git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 0 ] || fail "A: expected exit 0, got $RC"
OUT=$(ls "$HARNESS_TELEMETRY_DIR"/*.jsonl 2>/dev/null | head -1)
[ -n "$OUT" ] || fail "A: no log written"
tail -1 "$OUT" | grep -q '"blocked":false' || fail "A: expected blocked false"
git commit -q -m x

# B) git add -A を含む command → ブロック(exit 2)・reason git-add-all
echo "more" > b.txt
payload "git add -A && git commit -m y" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "B: expected exit 2 (blocked), got $RC"
tail -1 "$OUT" | grep -q '"reason_category":"git-add-all"' || fail "B: reason git-add-all"

# C) staged に機密パターン → ブロック(exit 2)・reason secret-pattern
# キー例は動的生成する（このテストファイル自体がゲートの secret パターンに一致しないように分割）
printf 'aws_key = AKIA%s\n' "IOSFODNN7EXAMPLE" > sec.txt
git add sec.txt
payload "git commit -m z" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "C: expected exit 2 (secret), got $RC"
tail -1 "$OUT" | grep -q '"reason_category":"secret-pattern"' || fail "C: reason secret-pattern"
git rm -q --cached sec.txt >/dev/null 2>&1; rm -f sec.txt

# D) git commit を含まない command → no-op（exit 0・記録を増やさない）
BEFORE=$(wc -l < "$OUT" | tr -d ' ')
payload "ls -la" | sh "$GATE"; RC=$?
[ "$RC" -eq 0 ] || fail "D: expected exit 0 for non-commit"
AFTER=$(wc -l < "$OUT" | tr -d ' ')
[ "$BEFORE" = "$AFTER" ] || fail "D: non-commit should not be logged"

# E) 先頭ドットの明示パス add（.claude/ 配下）→ 許可(exit 0)（Issue #29 誤検知回帰）
payload "git add .claude/skills/pr/SKILL.md && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 0 ] || fail "E: explicit dot-path (.claude/) should be allowed, got $RC"

# F) 先頭ドットの明示パス add（.gitignore）→ 許可(exit 0)（Issue #29 誤検知回帰）
payload "git add .gitignore && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 0 ] || fail "F: explicit dot-path (.gitignore) should be allowed, got $RC"

# G) git add . の連結 → ブロック(exit 2)
payload "git add . && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "G: git add . should be blocked, got $RC"

# H) git add ./ （git add . と等価）→ ブロック(exit 2)
payload "git add ./ && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "H: git add ./ should be blocked, got $RC"

# I) セミコロン連結 git add -A; → ブロック(exit 2)
payload "git add -A; git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "I: git add -A; should be blocked, got $RC"

# J) 連続空白 git add  -A → ブロック(exit 2)（現行 case 一致の取りこぼし回帰）
payload "git add  -A && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "J: git add  -A (double space) should be blocked, got $RC"

# K) git add ..（親ディレクトリ全 add）→ ブロック(exit 2)（レビュー R1 回帰）
payload "git add .. && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "K: git add .. should be blocked, got $RC"

# L) サブシェル (git add -A) → ブロック(exit 2)（レビュー R2 回帰: 境界 ) ）
payload "(git add -A) && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "L: (git add -A) should be blocked, got $RC"

# M) 無空白リダイレクト git add -A>log → ブロック(exit 2)（レビュー R2 回帰: 境界 > ）
payload "git add -A>log && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 2 ] || fail "M: git add -A>log should be blocked, got $RC"

# N) 親ディレクトリの明示パス add → 許可(exit 0)（.. 対応の偽陽性防止）
payload "git add ../other/file.txt && git commit -m x" | sh "$GATE"; RC=$?
[ "$RC" -eq 0 ] || fail "N: explicit parent path (../other/file.txt) should be allowed, got $RC"

cd /
rm -rf "$TMP"
if [ "$FAIL" -eq 0 ]; then echo "test-pre-commit-gate: ALL PASS"; else echo "test-pre-commit-gate: FAILED"; fi
exit "$FAIL"

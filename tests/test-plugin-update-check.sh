#!/bin/bash
# tests: hooks/check-plugin-updates.sh（Issue #19: cwd＝セッションのリポジトリ単位の更新判定）
# ネットワーク非依存。fake HOME に installed_plugins.json と marketplace（string source→ローカル
# plugin.json）を用意し、cwd を変えて hook を実行して repo ごとの出し分けを検証する。
set -u
FAIL=0
HOOK="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/hooks/check-plugin-updates.sh"
TMP=$(mktemp -d)

fail() { echo "FAIL: $1"; FAIL=1; }

# --- fake 環境 ---
FAKE_HOME="$TMP/home"
PLUGINS="$FAKE_HOME/.claude/plugins"
MP="$PLUGINS/marketplaces/tmpmp"
CACHE="$TMP/cache"
mkdir -p "$PLUGINS" "$MP/.claude-plugin" "$MP/testplug/.claude-plugin" "$MP/userplug/.claude-plugin" "$CACHE"

# セッションを開くリポジトリ（realpath を一致させるため実ディレクトリを作る）
A="$TMP/repoA"; B="$TMP/repoB"; C="$TMP/repoC"
mkdir -p "$A/sub" "$B" "$C"

# marketplace 定義（string source → mp_dir/<source>/.claude-plugin/plugin.json を latest とみなす）
cat > "$MP/.claude-plugin/marketplace.json" <<JSON
{"plugins":[{"name":"testplug","source":"testplug"},{"name":"userplug","source":"userplug"}]}
JSON
printf '{"version":"2.0.0"}\n' > "$MP/testplug/.claude-plugin/plugin.json"   # testplug latest
printf '{"version":"3.0.0"}\n' > "$MP/userplug/.claude-plugin/plugin.json"   # userplug latest

# claude をスタブ（marketplace update を no-op 化して MP_ERR を出さない）
FAKE_BIN="$TMP/bin"; mkdir -p "$FAKE_BIN"
printf '#!/bin/sh\nexit 0\n' > "$FAKE_BIN/claude"; chmod +x "$FAKE_BIN/claude"

run() { # $1=cwd → hook を実行し systemMessage を含む JSON を返す
  printf '{"source":"startup","cwd":"%s"}' "$1" \
    | HOME="$FAKE_HOME" CLAUDE_PLUGIN_DATA="$CACHE" PATH="$FAKE_BIN:$PATH" bash "$HOOK"
}

# ============ Fixture 1: project プラグイン(A=1.0.0/B=2.0.0) ＋ user プラグイン(3.0.0) ============
cat > "$PLUGINS/installed_plugins.json" <<JSON
{"plugins":{
  "testplug@tmpmp":[
    {"scope":"project","projectPath":"$A","version":"1.0.0"},
    {"scope":"project","projectPath":"$B","version":"2.0.0"}
  ],
  "userplug@tmpmp":[
    {"scope":"user","version":"3.0.0"}
  ]
}}
JSON

# A) repoA（遅れている）→ 更新催促（1.0.0 → 2.0.0）
OUT=$(run "$A")
echo "$OUT" | grep -q '更新があります' || fail "A: repoA で更新催促が出ない: $OUT"
echo "$OUT" | grep -q '1.0.0' && echo "$OUT" | grep -q '2.0.0' || fail "A: 1.0.0→2.0.0 が出ない: $OUT"

# B) repoB（最新）→ すべて最新（最大版採用なら誤って最新扱いになるが、A が催促されている時点で最大版不使用が担保される）
OUT=$(run "$B")
echo "$OUT" | grep -q 'すべて最新' || fail "B: repoB で「すべて最新」が出ない: $OUT"
echo "$OUT" | grep -q '更新があります' && fail "B: repoB で誤って更新催促が出た: $OUT"

# per-repo キャッシュ: A と B で別ファイルが作られている
NCACHE=$(ls "$CACHE"/update-check-*.json 2>/dev/null | wc -l | tr -d ' ')
[ "$NCACHE" -ge 2 ] || fail "cache: repo ごとに別キャッシュが作られていない（$NCACHE 個）"

# C) repoA を再実行 → TTL 内でキャッシュ再掲（前回チェック）
OUT=$(run "$A")
echo "$OUT" | grep -q '前回チェック' || fail "C: repoA 再実行でキャッシュ再掲されない: $OUT"
echo "$OUT" | grep -q '1.0.0' || fail "C: 再掲に更新情報が含まれない: $OUT"

# D) repoA/sub（サブディレクトリ）→ 最長前方一致で repoA に一致し更新催促
OUT=$(run "$A/sub")
echo "$OUT" | grep -q '更新があります' || fail "D: サブディレクトリが projectPath に前方一致しない: $OUT"

# E) repoC（project 一致なし・user フォールバックあり）→ testplug はスキップ、userplug は最新
OUT=$(run "$C")
echo "$OUT" | grep -q 'すべて最新' || fail "E: repoC で user フォールバックが最新扱いにならない: $OUT"
echo "$OUT" | grep -q '更新があります' && fail "E: repoC で誤って更新催促が出た: $OUT"

# ============ Fixture 2: project プラグインのみ（user フォールバックなし）============
rm -f "$CACHE"/update-check-*.json
cat > "$PLUGINS/installed_plugins.json" <<JSON
{"plugins":{
  "testplug@tmpmp":[
    {"scope":"project","projectPath":"$A","version":"1.0.0"},
    {"scope":"project","projectPath":"$B","version":"2.0.0"}
  ]
}}
JSON

# F) repoC（どの install にも一致せず user フォールバックも無い）→ 未インストール（催促しない・無音にしない）
OUT=$(run "$C")
echo "$OUT" | grep -q '管理対象プラグインの install 記録がありません' || fail "F: 未インストール時のメッセージが出ない: $OUT"
echo "$OUT" | grep -q '更新があります' && fail "F: 未インストールなのに更新催促が出た: $OUT"

rm -rf "$TMP"
if [ "$FAIL" -eq 0 ]; then echo "test-plugin-update-check: ALL PASS"; else echo "test-plugin-update-check: FAILED"; fi
exit "$FAIL"

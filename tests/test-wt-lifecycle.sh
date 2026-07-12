#!/bin/sh
# tests: wt-new.sh → wt-rm.sh の統合スモーク（Plans 6.1 / §10）
# 一時 repo で「作成→設定引き継ぎ→plugin スキップ→破棄」を一巡させる。
# ここで踏むのは WT_SKIP_PLUGIN_REGISTER=1 の「オプトアウト」経路（plugin 副作用回避）。
# 非CC（claude/jq 不在）ゲートそのものは test-wt-identity.sh の wt_plugin_available で検証する。
set -u
FAIL=0
BASE="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
NEW="$BASE/assets/skills/wt-parallel/scripts/wt-new.sh"
RM="$BASE/assets/skills/wt-parallel/scripts/wt-rm.sh"

fail() { echo "FAIL: $1"; FAIL=1; }
[ -f "$NEW" ] || { echo "FAIL: wt-new.sh が無い"; echo "test-wt-lifecycle: FAILED"; exit 1; }
[ -f "$RM" ]  || { echo "FAIL: wt-rm.sh が無い";  echo "test-wt-lifecycle: FAILED"; exit 1; }

TMP=$(mktemp -d)
SRC="$TMP/src"
mkdir -p "$SRC/.claude"
(
  cd "$SRC"
  git init -q -b main 2>/dev/null || { git init -q; git checkout -q -b main; }
  git config user.email t@t; git config user.name t
  echo "hello" > README.md
  printf 'SECRET=1\n' > .env
  printf '{"x":1}\n' > .claude/settings.local.json
  git add README.md
  git commit -q -m init
)

export WT_SKIP_PLUGIN_REGISTER=1

# ── wt-new（マニフェスト無し）─────────────────
ERR="$TMP/new.err"
WT_PATH=$(cd "$SRC" && sh "$NEW" feature/test-branch 2>"$ERR"); RC=$?
[ "$RC" -eq 0 ] || fail "new: exit 0 期待 got $RC ($(cat "$ERR"))"
[ -d "$WT_PATH" ] || fail "new: worktree ディレクトリ未作成 ($WT_PATH)"
[ -f "$WT_PATH/.dev/slug" ] || fail "new: .dev/slug が無い"
grep -q "feature-test-branch" "$WT_PATH/.dev/slug" 2>/dev/null || fail "new: slug 内容不一致"
[ -f "$WT_PATH/.env" ] || fail "new: .env が引き継がれていない"
[ -f "$WT_PATH/.claude/settings.local.json" ] || fail "new: settings.local.json が引き継がれていない"
grep -q "WT_SKIP_PLUGIN_REGISTER" "$ERR" || fail "new: plugin スキップ通知が無い"
grep -qxF '.dev/' "$SRC/.git/info/exclude" 2>/dev/null || fail "new: .dev/ が exclude 未登録"
(cd "$SRC" && git worktree list --porcelain | grep -qF "$WT_PATH") || fail "new: worktree list に出ない"

# ── wt-rm ─────────────────────────────────
(cd "$SRC" && sh "$RM" "$WT_PATH" >/dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] || fail "rm: exit 0 期待 got $RC"
[ -d "$WT_PATH" ] && fail "rm: worktree ディレクトリが残存" || true
if (cd "$SRC" && git worktree list --porcelain | grep -qF "$WT_PATH"); then fail "rm: worktree list に残存"; fi

# ── メイン worktree の破棄は拒否 ─────────────
(cd "$SRC" && sh "$RM" "$SRC" >/dev/null 2>&1); RC=$?
[ "$RC" -ne 0 ] || fail "rm: メイン worktree の破棄は拒否されるべき"
[ -d "$SRC/.git" ] || fail "rm: メイン repo が壊れた"

# ── 回帰: スペースを含むパスの repo でも一巡する（Critical#1・awk $2 分割バグ）──
SP="$TMP/sp ace/src"
mkdir -p "$SP"
(
  cd "$SP"
  git init -q -b main 2>/dev/null || { git init -q; git checkout -q -b main; }
  git config user.email t@t; git config user.name t
  echo hi > R.md; git add R.md; git commit -q -m init
)
WSP=$(cd "$SP" && sh "$NEW" feature/sp 2>/dev/null); RC=$?
{ [ "$RC" -eq 0 ] && [ -d "$WSP" ]; } || fail "space: wt-new 失敗 (rc=$RC path=$WSP)"
(cd "$SP" && sh "$RM" "$WSP" >/dev/null 2>&1); RC=$?
[ "$RC" -eq 0 ] || fail "space: wt-rm 失敗 (rc=$RC)"
[ -d "$WSP" ] && fail "space: worktree 残存" || true

# ── 回帰: 相対 worktree_dir を絶対化し正しい位置に作る（Critical#2・基準ズレ）──
RELOUT=$(cd "$SRC" && sh "$NEW" feature/relbr "" ../relwt-x 2>/dev/null)
case "$RELOUT" in /*) ;; *) fail "rel: stdout が絶対パスでない ($RELOUT)" ;; esac
[ -d "$RELOUT" ] || fail "rel: worktree 未作成 ($RELOUT)"
[ -f "$RELOUT/.dev/slug" ] || fail "rel: .dev/slug が worktree 内に無い（基準ズレ）"
(cd "$SRC" && sh "$RM" "$RELOUT" >/dev/null 2>&1) || fail "rel: wt-rm 失敗"

cd /; rm -rf "$TMP"
if [ "$FAIL" -eq 0 ]; then echo "test-wt-lifecycle: ALL PASS"; else echo "test-wt-lifecycle: FAILED"; fi
exit "$FAIL"

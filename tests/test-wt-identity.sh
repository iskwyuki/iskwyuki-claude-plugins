#!/bin/sh
# tests: assets/skills/wt-parallel/scripts/wt-identity.sh の純粋関数（Plans 6.1 / §10）
# slug 正規化・strict-subset パーサ（scalar/list）・.dev/ 除外の冪等性・plugin 可用性判定を
# 副作用から切り離して検証する。既存 tests/test-pre-commit-gate.sh の型を踏襲。
set -u
FAIL=0
LIB="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)/assets/skills/wt-parallel/scripts/wt-identity.sh"

fail() { echo "FAIL: $1"; FAIL=1; }
assert_eq() { [ "$1" = "$2" ] || fail "$3 (got '$1' want '$2')"; }

[ -f "$LIB" ] || { echo "FAIL: lib が無い: $LIB"; echo "test-wt-identity: FAILED"; exit 1; }
. "$LIB"

# ── slug 正規化 ─────────────────────────────
assert_eq "$(wt_slugify 'feature/Foo Bar')" "feature-foo-bar" "slug: path+space+case"
assert_eq "$(wt_slugify 'FIX-#29!!')"        "fix-29"          "slug: 記号圧縮+trim"
assert_eq "$(wt_slugify '  --xx--  ')"       "xx"              "slug: 前後ハイフン/空白 trim"
assert_eq "$(wt_slugify '@@@')"              "wt"              "slug: 空になったら wt にフォールバック"

TMP=$(mktemp -d)

# ── strict-subset: トップレベルスカラ ───────────
cat > "$TMP/m.yaml" <<'EOF'
base_ref: origin/main
start: "pnpm dev"
other: 'single'  # trailing comment
notmine_base_ref: nope
EOF
assert_eq "$(wt_yaml_scalar "$TMP/m.yaml" base_ref)" "origin/main" "scalar: 素の値"
assert_eq "$(wt_yaml_scalar "$TMP/m.yaml" start)"    "pnpm dev"    "scalar: ダブルクォート剥がし"
assert_eq "$(wt_yaml_scalar "$TMP/m.yaml" other)"    "single"      "scalar: シングルクォート+コメント"
assert_eq "$(wt_yaml_scalar "$TMP/m.yaml" missing)"  ""            "scalar: 不在は空"
assert_eq "$(wt_yaml_scalar "$TMP/nope.yaml" start)" ""            "scalar: ファイル不在は空"

# ── strict-subset: ブロックリスト ──────────────
cat > "$TMP/l.yaml" <<'EOF'
inherit:
  - backend/.env
  - frontend/.env
start: x
EOF
GOT=$(wt_yaml_list "$TMP/l.yaml" inherit | tr '\n' ',')
assert_eq "$GOT" "backend/.env,frontend/.env," "list: 2 要素・次キーで停止"
assert_eq "$(wt_yaml_list "$TMP/l.yaml" missing)" "" "list: 不在キーは空"

# ── .dev/ 除外の冪等追記 ─────────────────────
wt_ensure_dev_ignored "$TMP/gitcommon"
wt_ensure_dev_ignored "$TMP/gitcommon"
CNT=$(grep -cxF '.dev/' "$TMP/gitcommon/info/exclude" 2>/dev/null || echo 0)
assert_eq "$CNT" "1" "exclude: .dev/ は一度だけ追記（冪等）"

# ── plugin 可用性判定 ───────────────────────
if ( WT_SKIP_PLUGIN_REGISTER=1; wt_plugin_available ); then fail "plugin: WT_SKIP=1 で無効化されるべき"; fi
if ( PATH=/nonexistent-xyz; wt_plugin_available ); then fail "plugin: 壊れた PATH（非 CC）で無効化されるべき"; fi
if command -v claude >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
  wt_plugin_available || fail "plugin: claude+jq があれば有効のはず"
fi

# ── plugin 抽出（project 有効 ∧ user 未有効のみ・§10 単体テスト対象）──
if command -v jq >/dev/null 2>&1; then
  printf '{"enabledPlugins":{"user-shared@mk":true}}\n'                      > "$TMP/user.json"
  printf '{"enabledPlugins":{"proj-a@mk":true,"proj-off@mk":false}}\n'       > "$TMP/proj.json"
  printf '{"enabledPlugins":{"proj-b@mk":true,"user-shared@mk":true}}\n'     > "$TMP/proj.local.json"
  GOT=$(wt_plugins_to_register "$TMP/user.json" "$TMP/proj.json" "$TMP/proj.local.json" | tr '\n' ',')
  assert_eq "$GOT" "proj-a@mk,proj-b@mk," "plugins: project 有効かつ user 未有効のみ（user共有と false は除外）"
  assert_eq "$(wt_plugins_to_register "$TMP/user.json" "$TMP/nope.json" | tr '\n' ',')" "" "plugins: project 設定不在は空"
else
  echo "SKIP: jq 不在のため wt_plugins_to_register テストを省略"
fi

# ── wt_inherit_file: 正常コピー ＋ パストラバーサル拒否 ──
mkdir -p "$TMP/ir/root/s" "$TMP/ir/wt"
echo A > "$TMP/ir/root/s/f"
wt_inherit_file "$TMP/ir/root" "$TMP/ir/wt" "s/f" 2>/dev/null
[ -f "$TMP/ir/wt/s/f" ] || fail "inherit: 正常な相対パスがコピーされない"
W=$(wt_inherit_file "$TMP/ir/root" "$TMP/ir/wt" "../evil" 2>&1)
case "$W" in *スキップ*) ;; *) fail "inherit: ../ を含むパスが拒否されない" ;; esac
W=$(wt_inherit_file "$TMP/ir/root" "$TMP/ir/wt" "/etc/hostname" 2>&1)
case "$W" in *スキップ*) ;; *) fail "inherit: 絶対パスが拒否されない" ;; esac

cd /; rm -rf "$TMP"
if [ "$FAIL" -eq 0 ]; then echo "test-wt-identity: ALL PASS"; else echo "test-wt-identity: FAILED"; fi
exit "$FAIL"

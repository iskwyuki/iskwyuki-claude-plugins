#!/bin/sh
# wt-parallel 共通ライブラリ（source して使う）。
# slug 正規化・.dev/ 永続化・git 除外の冪等追記・マニフェスト strict-subset パーサ
# （scalar/list）・plugin 可用性判定など、副作用の無い/冪等な部品を提供する。
# 直接実行しても何も起きない（関数定義のみ・グローバルな set はしない）。
#
# 注意（§12.4 / §5.1）: yq に依存しない。ここで扱うのは strict-subset の一部
#   （トップレベルスカラ + ブロックリスト）のみ。2 階層マップ（env/hooks/health/ports）
#   と範囲外構文の loud-error 判定は Stage 2（Task 6.3）で追加する。

# ── ログ（人向けは stderr。stdout は機械可読出力に空ける）────────────
wt_info() { printf 'wt-parallel: %s\n'        "$*" >&2; }
wt_warn() { printf 'wt-parallel: [warn] %s\n' "$*" >&2; }
wt_die()  { printf 'wt-parallel: [error] %s\n' "$*" >&2; exit 1; }

# ── slug 正規化 ────────────────────────────────────────────
# ブランチ名 → 英小文字/数字/ハイフンのみ。連続する非英数字は 1 個のハイフンに圧縮し、
# 前後のハイフンを除去、40 文字に切り詰める。空になったら "wt" にフォールバック。
wt_slugify() (
  s=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' \
      | sed -e 's/[^a-z0-9][^a-z0-9]*/-/g' -e 's/^--*//' -e 's/--*$//' \
      | cut -c1-40 | sed -e 's/--*$//')
  [ -n "$s" ] || s=wt
  printf '%s' "$s"
)

# ── .dev/ 永続化 ───────────────────────────────────────────
wt_persist_slug() (
  devdir=$1; slug=$2
  mkdir -p "$devdir"
  printf '%s\n' "$slug" > "$devdir/slug"
)
wt_read_slug() (
  devdir=$1
  [ -f "$devdir/slug" ] || return 0
  head -1 "$devdir/slug"
)

# ── .dev/ の git 除外を冪等に確保（§12.2 確定: git-native exclude 追記）──────
# 引数は git common-dir（例: /path/.git）。全 worktree 共通の info/exclude に .dev/ を
# 追記する。tracked な .gitignore を汚さず、全 worktree に一括で効く。既に在れば何もしない。
wt_ensure_dev_ignored() (
  common=$1
  excl="$common/info/exclude"
  mkdir -p "$common/info" 2>/dev/null || true
  [ -f "$excl" ] || : > "$excl"
  if grep -qxF '.dev/' "$excl" || grep -qxF '.dev' "$excl"; then
    return 0
  fi
  printf '%s\n' '.dev/' >> "$excl"
)

# ── 引き継ぎ 1 ファイル（root → worktree）────────────────────────
# rel が worktree 外へ出る（絶対パス・`..` セグメント）場合は loud-warn で拒否（パストラバーサル防止）。
# src 非存在は無警告スキップ（§Q16）。cp / mkdir 失敗は握りつぶさず warn する。
wt_inherit_file() (
  root=$1; wt=$2; rel=$3
  case "$rel" in /*) wt_warn "引き継ぎをスキップ（絶対パス不可）: $rel"; return 0 ;; esac
  case "/$rel/" in *"/../"*) wt_warn "引き継ぎをスキップ（.. を含むパス不可）: $rel"; return 0 ;; esac
  [ -f "$root/$rel" ] || return 0
  mkdir -p "$(dirname "$wt/$rel")" || { wt_warn "引き継ぎ失敗（mkdir）: $rel"; return 0; }
  if cp "$root/$rel" "$wt/$rel"; then wt_info "引き継ぎ: $rel"; else wt_warn "引き継ぎ失敗（cp）: $rel"; fi
)

# ── strict-subset パーサ: トップレベルスカラ ─────────────────────
# `key: value`（インデント無し）の value を返す。クォート（' "）を剥がし、
# 素の値は行末コメントを落とす。不在・ファイル無しは空文字。
wt_yaml_scalar() (
  file=$1; key=$2
  [ -f "$file" ] || return 0
  line=$(grep -E "^${key}:[[:space:]]*" "$file" 2>/dev/null | head -1)
  [ -n "$line" ] || return 0
  val=${line#"${key}:"}
  val=$(printf '%s' "$val" | sed -e 's/^[[:space:]]*//')
  case "$val" in
    \"*) val=$(printf '%s' "$val" | sed -e 's/^"//' -e 's/".*$//') ;;
    \'*) val=$(printf '%s' "$val" | sed -e "s/^'//" -e "s/'.*$//") ;;
    *)   val=$(printf '%s' "$val" | sed -e 's/[[:space:]]*#.*$//' -e 's/[[:space:]]*$//') ;;
  esac
  printf '%s' "$val"
)

# ── strict-subset パーサ: ブロックリスト ────────────────────────
# `key:`（値なし）に続くインデント付き `- item` 行を 1 行ずつ返す。次のキー/空行で停止。
# Stage 1 ではクォート剥がしまではしない（inherit のパス想定）。
wt_yaml_list() (
  file=$1; key=$2
  [ -f "$file" ] || return 0
  awk -v k="$key" '
    $0 ~ ("^" k ":[[:space:]]*$") { collecting=1; next }
    collecting==1 {
      if ($0 ~ /^[[:space:]]+-[[:space:]]*/) {
        item=$0
        sub(/^[[:space:]]+-[[:space:]]*/, "", item)
        sub(/[[:space:]]*#.*$/, "", item)
        sub(/[[:space:]]*$/, "", item)
        if (item != "") print item
      } else {
        collecting=0
      }
    }
  ' "$file"
)

# ── settings ファイルから enabledPlugins=true のキーを列挙（jq 前提）────────
wt_enabled_plugins() (
  f=$1
  [ -f "$f" ] || return 0
  jq -r '(.enabledPlugins // {}) | to_entries[] | select(.value==true) | .key' "$f" 2>/dev/null || true
)

# ── 登録すべき plugin を列挙（純粋関数・§10 単体テスト対象）──────────────
# project 設定（複数可）で有効かつ user スコープで未有効のものだけを 1 行ずつ返す。
# 使い方: wt_plugins_to_register <user_settings> <proj_settings>...
wt_plugins_to_register() (
  user_settings=$1; shift
  user_enabled=$(wt_enabled_plugins "$user_settings")
  for pf in "$@"; do wt_enabled_plugins "$pf"; done | sort -u | while IFS= read -r plug; do
    [ -n "$plug" ] || continue
    printf '%s\n' "$user_enabled" | grep -qxF "$plug" && continue   # user スコープ済みは除外
    printf '%s\n' "$plug"
  done
)

# ── plugin 操作を実施してよいか（非CC/jq不在/オプトアウトで false）──────────
wt_plugin_available() {
  [ "${WT_SKIP_PLUGIN_REGISTER:-0}" = "1" ] && return 1
  command -v claude >/dev/null 2>&1 || return 1
  command -v jq     >/dev/null 2>&1 || return 1
  return 0
}

#!/bin/sh
# wt-rm: worktree 破棄（plugin 対称解除 → git worktree remove）（Task 6.1 ＋ 6.4 の対称解除を先取り）
#
# usage: wt-rm.sh <worktree_dir>
#   - .dev/plugins に記録された project スコープ plugin を対称に uninstall（ダングリング防止）。
#   - メイン worktree・未登録パスは拒否（§9 安全不変条件）。
#   - Stage 1 では pre_rm フックは未実装（Task 6.4 で追加）。
set -u
DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
. "$DIR/wt-identity.sh"

usage() { printf 'usage: wt-rm.sh <worktree_dir>\n' >&2; exit 2; }
WT_DIR=${1:-}; [ -n "$WT_DIR" ] || usage
[ -d "$WT_DIR" ] || wt_die "worktree ディレクトリが存在しません: $WT_DIR"
WT_ABS=$(CDPATH= cd -- "$WT_DIR" && pwd -P) || wt_die "パス解決に失敗: $WT_DIR"

LIST=$(git -C "$WT_ABS" worktree list --porcelain 2>/dev/null) || wt_die "git worktree ではありません: $WT_ABS"
# `worktree <path>` の path はスペースを含み得るため $2 分割ではなくプレフィックスを剥がす
MAIN_WT=$(printf '%s\n' "$LIST" | awk '/^worktree /{sub(/^worktree /,""); print; exit}')

# 登録済み linked worktree であることを確認（未登録パスの誤削除防止）
if ! printf '%s\n' "$LIST" | awk '/^worktree /{sub(/^worktree /,""); print}' | grep -qxF "$WT_ABS"; then
  wt_die "登録済みの worktree ではありません: $WT_ABS"
fi
# メイン worktree の破棄は拒否
[ "$WT_ABS" != "$MAIN_WT" ] || wt_die "メイン worktree は破棄できません: $WT_ABS"

# ── plugin 対称解除（.dev/plugins に記録された分だけ）──────────
if [ -f "$WT_ABS/.dev/plugins" ]; then
  if wt_plugin_available; then
    while IFS= read -r plug; do
      [ -n "$plug" ] || continue
      if (cd "$WT_ABS" && claude plugin uninstall "$plug" --scope project >/dev/null 2>&1); then
        wt_info "plugin 解除: $plug"
      else
        wt_warn "plugin 解除に失敗（続行）: $plug"
      fi
    done < "$WT_ABS/.dev/plugins"
  else
    wt_warn "plugin 解除をスキップ（claude / jq 不在 or オプトアウト）。.dev/plugins に登録記録あり"
  fi
fi

# ── worktree 破棄（引き継ぎ .env 等の untracked を含むため --force）──────
# メイン worktree コンテキストから実行する（自分自身の cwd 内では remove できないため）。
if (cd "$MAIN_WT" && git worktree remove --force "$WT_ABS") >&2; then
  wt_info "破棄完了: $WT_ABS"
else
  wt_die "git worktree remove に失敗しました: $WT_ABS"
fi

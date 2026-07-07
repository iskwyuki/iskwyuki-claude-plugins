#!/bin/sh
# pre-commit ゲート（Plans 4.4 / Track B）。PreToolUse(Bash) hook から呼ばれる。
# git commit を含む command をインターセプトし、機密混入・git add -A を決定的に判定する。
# 明確な事故のみ deny（誤爆防止）、blocked/passed とも効果ログに記録する。
set -u
HOOK_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)

PAYLOAD=$(cat)

# tool_input.command を抽出（jq があれば jq、無ければ素朴フォールバック）
if command -v jq >/dev/null 2>&1; then
  CMD=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""' 2>/dev/null)
else
  CMD=$(printf '%s' "$PAYLOAD" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
fi

# git commit を含まなければ何もしない（記録なし・許可）
case "$CMD" in
  *"git commit"*) ;;
  *) exit 0;;
esac

BLOCKED=false
REASON="none"

# 1) git add -A / . / ./ / .. / --all の検出（CLAUDE.md「git add は明示パスのみ」）
# トークン境界を要求し、.claude/ や .gitignore 等の先頭ドット明示パスを誤マッチしない（Issue #29）
# 境界には ; & | ) > も含む（サブシェル・リダイレクト連結の取りこぼし防止）
if printf '%s\n' "$CMD" | grep -qE 'git add[[:space:]]+(-A|--all|-all|\.\.?/?)([[:space:];&|)>]|$)'; then
  BLOCKED=true; REASON="git-add-all"
fi

# 2) staged 差分の汎用機密パターン（会社固有名はハードコードしない）
STAGED=$(git diff --cached 2>/dev/null || true)
DIFF_LINES=$(printf '%s\n' "$STAGED" | grep -c '^[+-]' 2>/dev/null || echo 0)
if [ "$BLOCKED" = false ] && [ -n "$STAGED" ]; then
  if printf '%s' "$STAGED" | grep -qE '(-----BEGIN [A-Z ]*PRIVATE KEY-----|AKIA[0-9A-Z]{16}|gh[pousr]_[A-Za-z0-9]{20,}|xox[baprs]-[A-Za-z0-9-]{10,})'; then
    BLOCKED=true
    REASON="secret-pattern"
  fi
fi

# 効果ログ記録（決定的経路）— log-effect.sh は同ディレクトリ
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo ".")
if [ -f "$HOOK_DIR/log-effect.sh" ]; then
  sh "$HOOK_DIR/log-effect.sh" --tool pre-commit-gate --gate-type pre-commit \
    --gate-blocked "$BLOCKED" --gate-reason "$REASON" \
    --diff-lines "$DIFF_LINES" --repo-path "$ROOT" >/dev/null 2>&1 || true
fi

if [ "$BLOCKED" = true ]; then
  echo "pre-commit ゲート: コミットを停止しました（理由: ${REASON}）。CLAUDE.md の運用ルール（git add は明示パスのみ／機密分離）を確認してください。" >&2
  exit 2
fi
exit 0

#!/bin/bash
# SessionStart hook: インストール済みプラグインの更新有無をチェックして通知する。
# 「実施・TTLスキップ・失敗・検知」のすべてで systemMessage を 1 行以上出す（無音にしない）。
# 無音は「更新がない」のか「チェックが失敗している」のか区別できないため。
# 失敗のみの結果はキャッシュ 1 時間で失効させ、次回セッション開始時に自動で再チェックする
# （一時的なネットワーク失敗が TTL いっぱい再掲され続けるのを防ぐ）。
set -u

INPUT=$(cat 2>/dev/null || true)
# startup 以外（resume / clear / compact）では動かない
if printf '%s' "$INPUT" | grep -q '"source"'; then
  printf '%s' "$INPUT" | grep -Eq '"source"[[:space:]]*:[[:space:]]*"startup"' || exit 0
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo '{"systemMessage": "⚠ プラグイン更新チェック: python3 が見つからないためスキップ"}'
  exit 0
fi

emit() {
  python3 -c 'import json,sys; print(json.dumps({"systemMessage": sys.argv[1]}, ensure_ascii=False))' "$1"
}

CACHE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/iskwyuki-claude-plugins}"
mkdir -p "$CACHE_DIR" 2>/dev/null || { emit "⚠ プラグイン更新チェック: キャッシュディレクトリを作成できないためスキップ"; exit 0; }
CACHE_FILE="$CACHE_DIR/update-check.json"
TTL_HOURS="${PLUGIN_UPDATE_CHECK_TTL_HOURS:-12}"

# TTL 内なら前回結果を 1 行で再掲して終了
now=$(date +%s)
if [ -f "$CACHE_FILE" ]; then
  summary=$(python3 - "$CACHE_FILE" "$now" "$TTL_HOURS" <<'PY' 2>/dev/null
import json, sys
cache = json.load(open(sys.argv[1]))
now, ttl = int(sys.argv[2]), int(sys.argv[3])
age = now - int(cache.get("checked_at", 0))
ups = cache.get("updates", [])
errs = cache.get("errors", [])
# 失敗のみのキャッシュは最長 1 時間で失効させ、次回セッションで自動再チェックする
ttl_eff = min(ttl, 1) if (errs and not ups) else ttl
if age < ttl_eff * 3600:
    h, m = age // 3600, (age % 3600) // 60
    ago = f"{h}時間{m}分前" if h else f"{m}分前"
    if ups:
        body = ", ".join(f"{u['plugin']} {u['installed']}→{u['latest']}" for u in ups)
        print(f"プラグイン更新あり（前回チェック: {ago}）: {body}。適用: /update-plugins")
    elif errs:
        print(f"⚠ プラグイン更新チェック: 前回（{ago}）一部失敗: " + "; ".join(errs) + "。今すぐ再チェック: /update-plugins")
    else:
        print(f"✓ プラグイン更新チェック: 前回（{ago}）実施・更新なし（TTL {ttl}h 内のため再チェックせず）")
PY
)
  if [ -n "${summary:-}" ]; then
    emit "$summary"
    exit 0
  fi
fi

MP_ERR=""
if ! claude plugin marketplace update >/dev/null 2>&1; then
  MP_ERR="marketplace 定義の更新に失敗（比較対象が古い可能性）"
fi

MP_ERR="$MP_ERR" CACHE_FILE="$CACHE_FILE" python3 <<'PY'
import base64
import json
import os
import subprocess
import sys
import time

home = os.path.expanduser("~")
plugins_root = os.path.join(home, ".claude", "plugins")
cache_file = os.environ["CACHE_FILE"]
errors = []
if os.environ.get("MP_ERR"):
    errors.append(os.environ["MP_ERR"])

def finish(updates, checked):
    try:
        json.dump(
            {"checked_at": int(time.time()), "updates": updates, "errors": errors},
            open(cache_file, "w"), ensure_ascii=False,
        )
    except Exception:
        pass
    parts = []
    ctx = None
    if updates:
        lines = "\n".join(f"  - {u['plugin']}: {u['installed']} → {u['latest']}" for u in updates)
        parts.append(f"プラグインに更新があります:\n{lines}\n適用: /update-plugins（反映には再起動が必要）")
        ctx = ("インストール済み Claude Code プラグインに更新があります: "
               + "; ".join(f"{u['plugin']} {u['installed']}→{u['latest']}" for u in updates)
               + "。ユーザーが更新を望んだ場合は update-plugins skill の手順に従うこと。")
    else:
        parts.append(f"✓ プラグイン更新チェック完了: {checked} プラグインすべて最新")
    if errors:
        parts.append("⚠ 一部チェック失敗: " + "; ".join(errors) + "。対処手順: /update-plugins")
    out = {"systemMessage": "\n".join(parts)}
    if ctx:
        out["hookSpecificOutput"] = {"hookEventName": "SessionStart", "additionalContext": ctx}
    print(json.dumps(out, ensure_ascii=False))
    sys.exit(0)

try:
    installed = json.load(open(os.path.join(plugins_root, "installed_plugins.json")))["plugins"]
except Exception as e:
    errors.append(f"installed_plugins.json を読めません: {type(e).__name__}")
    finish([], 0)

updates = []
checked = 0
for key, installs in installed.items():
    if not installs:
        continue
    name, _, mp = key.partition("@")
    current = sorted({i.get("version", "") for i in installs})[-1]
    mp_dir = os.path.join(plugins_root, "marketplaces", mp)
    try:
        mp_def = json.load(open(os.path.join(mp_dir, ".claude-plugin", "marketplace.json")))
    except Exception:
        errors.append(f"{key}: marketplace 定義を読めません")
        continue
    entry = next((p for p in mp_def.get("plugins", []) if p.get("name") == name), None)
    if entry is None:
        errors.append(f"{key}: marketplace 定義にエントリが見つかりません")
        continue
    src = entry.get("source")
    latest = None
    if isinstance(src, str):
        # marketplace リポジトリ内のプラグイン: clone 済みの plugin.json を読む
        try:
            pj = os.path.join(mp_dir, src, ".claude-plugin", "plugin.json")
            latest = json.load(open(pj)).get("version")
        except Exception:
            errors.append(f"{key}: plugin.json を読めません")
            continue
    elif isinstance(src, dict) and src.get("source") == "github" and "repo" in src:
        if src.get("sha"):
            # sha ピンは意図的な固定とみなしチェック対象外（カウントには含める）
            checked += 1
            continue
        path = f"repos/{src['repo']}/contents/.claude-plugin/plugin.json"
        if src.get("ref"):
            path += f"?ref={src['ref']}"
        try:
            out = subprocess.run(
                ["gh", "api", path, "--jq", ".content"],
                capture_output=True, text=True, timeout=15,
            )
        except FileNotFoundError:
            errors.append(f"{key}: gh コマンドが見つかりません")
            continue
        except subprocess.TimeoutExpired:
            errors.append(f"{key}: upstream への問い合わせがタイムアウト")
            continue
        if out.returncode != 0:
            errors.append(f"{key}: gh api 失敗（認証切れ・ネットワーク等）")
            continue
        try:
            latest = json.loads(base64.b64decode(out.stdout)).get("version")
        except Exception:
            errors.append(f"{key}: upstream plugin.json の解析に失敗")
            continue
    else:
        # url / git-subdir / npm 等は未対応（対応するまで明示しておく）
        errors.append(f"{key}: source 形式 {src!r} は未対応")
        continue
    checked += 1
    if latest and current and latest != current:
        updates.append({"plugin": key, "installed": current, "latest": latest})

finish(updates, checked)
PY
exit 0

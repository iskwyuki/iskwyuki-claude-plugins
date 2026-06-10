#!/bin/bash
# SessionStart hook: インストール済みプラグインの更新有無をチェックして通知する。
# - TTL（既定 12h、PLUGIN_UPDATE_CHECK_TTL_HOURS で変更可）内は何もしない
# - 失敗時は黙って exit 0（セッション開始を妨げない）
# - sha ピン留めされた外部ソースは意図的な固定とみなしチェック対象外
set -u

INPUT=$(cat 2>/dev/null || true)
# startup 以外（resume / clear / compact）では動かない
if printf '%s' "$INPUT" | grep -q '"source"'; then
  printf '%s' "$INPUT" | grep -Eq '"source"[[:space:]]*:[[:space:]]*"startup"' || exit 0
fi

command -v python3 >/dev/null 2>&1 || exit 0

CACHE_DIR="${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/iskwyuki-claude-plugins}"
mkdir -p "$CACHE_DIR" 2>/dev/null || exit 0
CACHE_FILE="$CACHE_DIR/update-check.json"
TTL_HOURS="${PLUGIN_UPDATE_CHECK_TTL_HOURS:-12}"

now=$(date +%s)
if [ -f "$CACHE_FILE" ]; then
  last=$(python3 -c "import json,sys; print(int(json.load(open(sys.argv[1])).get('checked_at',0)))" "$CACHE_FILE" 2>/dev/null || echo 0)
  [ $((now - last)) -lt $((TTL_HOURS * 3600)) ] && exit 0
fi

# マーケットプレイス定義を最新化（失敗しても続行）
claude plugin marketplace update >/dev/null 2>&1 || true

CACHE_FILE="$CACHE_FILE" python3 <<'PY'
import base64
import json
import os
import subprocess
import sys
import time

home = os.path.expanduser("~")
plugins_root = os.path.join(home, ".claude", "plugins")
cache_file = os.environ["CACHE_FILE"]

try:
    installed = json.load(open(os.path.join(plugins_root, "installed_plugins.json")))["plugins"]
except Exception:
    sys.exit(0)

updates = []
for key, installs in installed.items():
    if not installs:
        continue
    name, _, mp = key.partition("@")
    current = sorted({i.get("version", "") for i in installs})[-1]
    mp_dir = os.path.join(plugins_root, "marketplaces", mp)
    latest = None
    try:
        mp_def = json.load(open(os.path.join(mp_dir, ".claude-plugin", "marketplace.json")))
        entry = next((p for p in mp_def.get("plugins", []) if p.get("name") == name), None)
        if entry is None:
            continue
        src = entry.get("source")
        if isinstance(src, str):
            # marketplace リポジトリ内のプラグイン: clone 済みの plugin.json を読む
            pj = os.path.join(mp_dir, src, ".claude-plugin", "plugin.json")
            latest = json.load(open(pj)).get("version")
        elif isinstance(src, dict) and src.get("source") == "github" and "repo" in src and not src.get("sha"):
            # 外部 GitHub ソース: upstream の plugin.json を gh api で取得（sha ピンは対象外）
            path = f"repos/{src['repo']}/contents/.claude-plugin/plugin.json"
            if src.get("ref"):
                path += f"?ref={src['ref']}"
            out = subprocess.run(
                ["gh", "api", path, "--jq", ".content"],
                capture_output=True, text=True, timeout=15,
            )
            if out.returncode == 0:
                latest = json.loads(base64.b64decode(out.stdout)).get("version")
    except Exception:
        latest = None
    if latest and current and latest != current:
        updates.append({"plugin": key, "installed": current, "latest": latest})

try:
    json.dump({"checked_at": int(time.time()), "updates": updates}, open(cache_file, "w"))
except Exception:
    pass

if updates:
    lines = "\n".join(f"  - {u['plugin']}: {u['installed']} → {u['latest']}" for u in updates)
    summary = "; ".join(f"{u['plugin']} {u['installed']}→{u['latest']}" for u in updates)
    print(json.dumps({
        "systemMessage": (
            f"プラグインに更新があります:\n{lines}\n"
            "適用: /update-plugins（または claude plugin update <plugin>。反映には再起動が必要）"
        ),
        "hookSpecificOutput": {
            "hookEventName": "SessionStart",
            "additionalContext": (
                f"インストール済み Claude Code プラグインに更新があります: {summary}。"
                "ユーザーが更新を望んだ場合は update-plugins skill の手順に従うこと。"
            ),
        },
    }, ensure_ascii=False))
PY
exit 0

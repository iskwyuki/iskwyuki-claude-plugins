# breezing 安全策 — worktree 衝突とコミット分離の機械検証

claude-code-harness の breezing / parallel 実行で並列 Worker を使う際の必須安全策。品質資産イニシアチブ（Plans.md 2.4）で資産化した。

## 問題: Worker worktree はセッション単位で共有される

claude-code-harness の Worker を並列起動すると、`isolation: "worktree"` を指定しても全 Worker が同一の worktree に着地する。

```
<リポジトリ>/.harness-worktrees/<セッションID>/   ← 全 Worker が共有
ブランチ: harness/worker/<セッションID>            ← これも共有
```

worktree・ブランチの割当がエージェント単位ではなく**セッション単位**のため、並列 Worker 間で git index が競合し、**あるタスクのコミットに別タスクのファイルが混入**しうる。

### 実測記録

| 日付 | 環境 | 結果 |
|---|---|---|
| 2026-06-11 | portfolio（初回観測） | 並列実行で Task のコミットに別 Task のファイルが混入。Worker の self_review（エビデンス必須）が検出して自己回復したが、構造的には危険 |
| 2026-07-04 | 本リポジトリ、harness 4.16.4（再現確認） | `isolation: "worktree"` 指定の並列エージェント 2 体が同一 `.harness-worktrees/<セッションID>`・同一ブランチ `harness/worker/<セッションID>` に着地することを実測。**現行版でも再現する** |

## 対策（Lead の必須手順）

### 1. cherry-pick 前のコミット分離の機械検証

Lead は Worker のコミットを取り込む前に、**目視ではなく機械的に**「1 タスク = 期待ファイルのみ」を検証する。bash で実行し、期待ファイルは**グロブ禁止・明示パスのみ**で列挙する（シェル展開により、ディスク上に実在する混入ファイルが期待集合へ自動編入されるのを防ぐ）:

```bash
# 変更ファイル一覧を取得（ref 解決失敗・merge commit は不合格として中断 = fail-closed）
changed=$(git -c core.quotePath=false show --name-only --format= "<commit>") \
  || { echo "abort: ref 解決失敗"; exit 1; }
[ -n "$changed" ] || { echo "abort: 変更ファイル一覧が空（ref 誤り or merge commit）"; exit 1; }

# 期待集合にない変更ファイル（= 混入）を列挙する
comm -23 <(printf '%s\n' "$changed" | sort) <(printf '%s\n' <期待ファイル...> | sort)
```

判定基準: ガードを通過した上で、出力が空なら合格（混入なし）。1 行でも出力されたらそのファイルは混入として扱う。期待リストが空のときは全変更ファイルが出力される fail-safe 特性を持つ。

> 注意: `grep -v -f <期待リスト>` 方式は採らない。`-x` なしでは部分文字列一致（期待 `docs/a.md` が混入 `mydocs/a.md` にもマッチ）、空リストでは全行マッチとなり、いずれも混入を静かに見逃す（2026-07-04 実測）。

### 2. 混入時: コミットを信用せず、ファイル単位で適用し直す

混入を検出したら、そのコミットの cherry-pick は行わない。該当タスクのファイルだけを checkout / apply で feature ブランチへ適用し直す:

```bash
git checkout <commit> -- <そのタスクのファイルのみ...>
git commit -m "<タスク内容>"
```

### 3. 確実な隔離が必要な場合: 直列化 or 明示 worktree

- 同一ファイル群に触るタスクは**並列にしない**（直列化）
- 並列が必要なら、Lead がタスクごとに一意な worktree を明示的に掘る（harness 4.x の非 claude backend が採る `WT_ID = <task>-<timestamp>-<PID>` 方式と同趣旨。PID 成分は Lead 直列実行のため省略。同秒衝突時は `git worktree add -b` が明示的に失敗する = fail-closed）:

```bash
ts=$(date +%s)
git worktree add -b "work/<task-id>-${ts}" ".claude/worktrees/<task-id>-${ts}"
```

### 4. 統合は常に PR ブランチ経由（main 直 cherry-pick 禁止）

検証済みコミットも main へ直接 cherry-pick せず、PR ブランチへ積んで統合する（[role-division.md](role-division.md) の統合方針）。worktree 内での commit がブロックされる環境では、検証済みパッチの適用は Lead が行う。

## upstream 報告の判断（Plans.md 2.4 DoD）

**判断: 投稿は見送る**（2026-07-04）。報告先候補は [Chachamaru127/claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)、issue 文面は準備済み（未投稿）。

見送りの理由:

- **実測で確認できたのは「共有」まで**。並列 `isolation:"worktree"` エージェントが同一 worktree・同一ブランチ（session 単位）に着地することは再現済み（上表）。だが**「コミットへの他タスクファイル混入」という実害は本セッションでは再現していない**（根拠は 2026-06-11 の観測メモリのみで、そのときも Worker の self_review が検出・自己回復した）。
- worktree の**再利用は hook の意図的な設計**（"Reuse a valid existing worktree"）であり、共有それ自体はバグと断定できない。
- breezing の標準フローは Worker を**逐次実行**するため、そもそも同時に index を触らない。混入が起きうるのは `--parallel N` の同時実行に限られ、その実害は未再現。

以上より、実害を再現せずに公開 issue（バグ報告）を出すのは誤報リスクがあると判断し、投稿を見送った。利用側の緩和策（本書の Lead 手順）で運用上は十分カバーできる。将来 `--parallel` で実際の混入を再現できたら、その証跡を添えてバグ報告として再検討する。

## 関連

- [role-division.md](role-division.md) — 統合方針（PR ブランチ経由・直 cherry-pick 禁止）の正
- 初回観測の記録: portfolio `.claude/memory/patterns.md`「並列 Worker の worktree 衝突は Lead がコミット分離を機械検証する」

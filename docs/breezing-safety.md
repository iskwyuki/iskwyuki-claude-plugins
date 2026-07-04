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

Lead は Worker のコミットを取り込む前に、**目視ではなく機械的に**「1 タスク = 期待ファイルのみ」を検証する:

```bash
# 期待集合にない変更ファイル（= 混入）を列挙する
comm -23 <(git -c core.quotePath=false show --name-only --format= <commit> | sort) \
         <(printf '%s\n' <期待ファイル...> | sort)
```

判定基準: 出力が空なら合格（混入なし）。1 行でも出力されたらそのファイルは混入として扱う。期待リストが空のときは全変更ファイルが出力される fail-safe 特性を持つ。

> 注意: `grep -v -f <期待リスト>` 方式は採らない。`-x` なしでは部分文字列一致（期待 `docs/a.md` が混入 `mydocs/a.md` にもマッチ）、空リストでは全行マッチとなり、いずれも混入を静かに見逃す（2026-07-04 実測）。

### 2. 混入時: コミットを信用せず、ファイル単位で適用し直す

混入を検出したら、そのコミットの cherry-pick は行わない。該当タスクのファイルだけを checkout / apply で feature ブランチへ適用し直す:

```bash
git checkout <commit> -- <そのタスクのファイルのみ...>
git commit -m "<タスク内容>"
```

### 3. 確実な隔離が必要な場合: 直列化 or 明示 worktree

- 同一ファイル群に触るタスクは**並列にしない**（直列化）
- 並列が必要なら、Lead がタスクごとに一意な worktree を明示的に掘る（harness 4.x の非 claude backend が採る `WT_ID = <task>-<timestamp>-<PID>` 方式と同等）:

```bash
ts=$(date +%s)
git worktree add -b "work/<task-id>-${ts}" ".claude/worktrees/<task-id>-${ts}"
```

### 4. 統合は常に PR ブランチ経由（main 直 cherry-pick 禁止）

検証済みコミットも main へ直接 cherry-pick せず、PR ブランチへ積んで統合する（[role-division.md](role-division.md) の統合方針）。worktree 内での commit がブロックされる環境では、検証済みパッチの適用は Lead が行う。

## upstream 報告の判断（Plans.md 2.4 DoD）

**判断: 報告を実施する**（2026-07-04）。

根拠:

1. 現行版（4.16.4）でも再現することを実測で確認済み（上表）
2. 根本原因は worktree 割当の粒度（セッション単位）にあり、利用側の運用では緩和はできても解消できない
3. upstream 自身も非 claude backend（cursor / codex）ではタスク単位の一意 worktree（`<task>-<timestamp>-<PID>`）を採用しており、claude backend の Worker 経路だけが取り残されている — 修正方針の提案として成立する

報告状況は本節に追記する（実施記録: 下記）。

- 2026-07-04: issue 文面を準備。投稿はユーザー確認後に実施し、URL をここに追記する

## 関連

- [role-division.md](role-division.md) — 統合方針（PR ブランチ経由・直 cherry-pick 禁止）の正
- 初回観測の記録: portfolio `.claude/memory/patterns.md`「並列 Worker の worktree 衝突は Lead がコミット分離を機械検証する」

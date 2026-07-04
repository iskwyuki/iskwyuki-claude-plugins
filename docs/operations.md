# 運用方針（モデル・レビュー・マージ）

品質資産イニシアチブ（Plans.md 2.1 / 3.4）で確定した運用方針の集約。本書は**モデル運用方針**を主軸とし、レビュー方針・マージ方針は既存の正（[role-division.md](role-division.md) / [breezing-safety.md](breezing-safety.md)）を参照する。

## モデル運用方針

### 基本思想

開発品質を**モデル非依存のハーネス資産**（プラグイン・rules・ゲート・物差し）へ焼き込む。特定モデルの賢さに依存せず、観点（レビュー rules・agents）と検証構造（全件報告＋反証パス）を資産として残すことで、モデルが交代しても品質を保つ。

### 実装モデルの選択

- 実装（コードを書く手）は状況に応じて選ぶ。複雑タスクは推論深度を上げる。
- Opus 4.8 では **effort**（`low` / `medium` / `high` / `xhigh`）が推論深度の主レバー。「浅い推論」を観測したら prompt を盛らず effort を上げる。
- harness のバックエンド（claude / codex / cursor）は実装ロールにのみ適用する **role-scoped**。**Reviewer / Advisor は常に brain（Opus）固定**で、実装したバックエンドが自分の出力をレビューしない。

### モデル交代時の品質担保

- モデルや資産を変えたら、[quality-baseline](quality-baseline/README.md) の基準セット（既知バグの正解リスト）に同一手順でレビューを流し、検出率を比較する。劣化・改善を定量で捉えてから採用する。
- 初回基準は Fable 5 ＋ 資産一式（2026-06 計測）。

## レビュー方針

正は [role-division.md](role-division.md)。要点のみ再掲する。

- 人が明示的に呼ぶレビューは自前 `/code-review`（lite / standard / full）。**全件報告（recall）＋反証検証パス（precision）を必ずセット**で運用し、修正は検証済み Critical に限る。
- PR 単位の自律レビューは `/pr-review-loop`（最大 2 周・ローカル完結）。
- harness サイクル内の verdict ゲート（harness-review / reviewer agent）は harness 側の実行規律。明示レビュー用途には使わない。
- `/review`（自前・簡易）は 0.6.0 で廃止済み（`/code-review lite` が代替）。

## マージ方針

正は [role-division.md](role-division.md) の統合方針。要点のみ再掲する。

- **統合は常に PR ブランチ経由**。main への直接コミットは Plans.md 等の運用ステータス更新に限る（直 cherry-pick 禁止）。
- **セルフマージ**は「DoD 充足・構文検証・機密分離（会社固有情報が公開ファイルに無い）」の自己点検を通過した場合のみ。
- breezing の並列 Worker 取り込みは、Lead が cherry-pick 前にコミット分離を機械検証する（[breezing-safety.md](breezing-safety.md)）。
- **条件付き自動マージ**（CI green ＋ 検証済み Critical ゼロ ＋ 収束）への昇格は、pr-review-loop の誤修正率計測（Plans.md 3.1）の結果を見て判断する。計測が済むまでマージは手動を維持する。

## 関連

- [role-division.md](role-division.md) — harness と自前資産の役割分担（レビュー/マージの正）
- [breezing-safety.md](breezing-safety.md) — 並列 Worker の worktree 衝突対策
- [quality-baseline/README.md](quality-baseline/README.md) — レビュー品質の計測（物差し）

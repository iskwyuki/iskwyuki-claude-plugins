# harness と自前資産の役割分担（2026-06-12 確定）

品質資産イニシアチブ（Plans.md 2.1）で確定した、claude-code-harness（外部・同梱）と自前資産（assets/）の責務分担。grill セッションでの確定内容を正とする。

## 役割分担

| 領域 | 担当 | 補足 |
|---|---|---|
| 計画・実行規律 | **harness**（harness-plan / harness-work / breezing） | Plan→Work→Review のサイクル管理、Plans.md のマーカー運用 |
| サイクル内の verdict ゲート | **harness**（harness-review / reviewer agent） | 実行規律の一部として harness 側に残す。APPROVE / REQUEST_CHANGES の判定はここ |
| 人が明示的に呼ぶレビュー | **自前 `/code-review`**（lite / standard / full） | 全件報告＋検証パス。レビューの「中身」の品質は自前資産で磨く |
| PR 単位の自律レビュー | **自前 `/pr-review-loop`** | レビュー→検証→修正→再レビューのループ。マージは手動を維持（第 1 ラウンド計測で昇格見送り。[pr-review-loop-metrics.md](pr-review-loop-metrics.md)） |
| レビュー品質の計測 | **自前 docs/quality-baseline/** | モデル・資産変更時の検出率比較（baseline-protocol v1） |

## 重複 skill の処遇

| skill | 処遇 | 理由 |
|---|---|---|
| `/review`（自前・簡易） | **削除**（0.6.0） | `/code-review lite` が完全に代替。skill 一覧の重複は選別ミラー方針（外部 skill 同梱時と同じ基準）に従い排除 |
| `/code-review`（自前） | 残す | 明示レビューの正 |
| harness-review | 残す | harness サイクル内ゲート専用。明示レビュー用途では使わない |
| `/pr-review-loop`（自前） | 残す | PR 単位の自律ループの正 |
| reviewer agent（自前 assets/agents/） | 残す | 「レビューして」等の自然言語レビュー要求の受け皿（設計・アーキ観点） |

## 統合方針

- **統合は常に PR ブランチ経由**。main への直接コミットは Plans.md 等の運用ステータス更新のみ許可
- **main への直 cherry-pick は禁止**。breezing の Lead は cherry-pick 前にコミット分離を機械検証し、PR を作って統合する（worktree 衝突対策の詳細: [breezing-safety.md](breezing-safety.md)）
- セルフマージは「DoD 充足・構文検証・機密分離」の自己点検を通過した場合のみ（2026-06-14 確立）

## 関連

- 計測の方法論: [docs/quality-baseline/README.md](quality-baseline/README.md)
- 確定の経緯: Plans.md 2.1（2026-06-12 grill セッション）

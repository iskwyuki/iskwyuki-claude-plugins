# iskwyuki-claude-plugins 運用ルール

- 統合は常に PR ブランチ経由。main への直接コミットは Plans.md 等の運用ステータス更新のみ可（直 cherry-pick 禁止）
- セルフマージは「DoD 充足・構文検証・機密分離（会社固有情報が公開ファイルに無い）」の自己点検後のみ
- レビューは `/code-review`（lite / standard / full）。`/review` は 0.6.0 で廃止済み。harness-review は harness サイクル内ゲート専用
- 配信 asset（assets/ / skills/ / hooks/）を変更したら `.claude-plugin/plugin.json` の version を bump する
- 会社リポジトリ由来の固有情報（リポジトリ名・SHA・コード）はコミットしない。ローカル manifest（`~/dev/quality-baseline-private/`）のみに記録
- **`git add -A` / `git add .` は禁止。コミットは明示パス指定のみ**（ランタイム状態ファイルの公開混入事故 2026-06-14 の再発防止。`.claude/state/` 等は .gitignore 済みだが二重防御とする）

詳細: [docs/operations.md](docs/operations.md)（モデル・レビュー・マージ方針） / [docs/role-division.md](docs/role-division.md) / [docs/breezing-safety.md](docs/breezing-safety.md) / [docs/pr-review-loop-metrics.md](docs/pr-review-loop-metrics.md)（自動マージ昇格判断） / [docs/quality-baseline/README.md](docs/quality-baseline/README.md)

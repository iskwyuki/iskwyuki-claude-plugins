---
description: Pull Requestの作成（テンプレート付き）
trigger: "when the user asks to create a pull request"
disable-model-invocation: true
---

# PR作成スキル

GitHub CLIを使用してPull Requestを作成する。

## 手順

1. 事前チェックを並列実行する
   - `git status` で未コミットの変更を確認
   - `git log main..HEAD --oneline` でコミット履歴を確認
   - `git diff main...HEAD --stat` で変更ファイル一覧を確認
2. 未コミットの変更があれば、先にコミットするか確認する
3. コミット履歴と差分を分析し、PRタイトルと本文を生成する

### PRテンプレート

```markdown
## 概要
{変更の目的と概要を1〜3行で}

## 変更内容
{主な変更点を箇条書きで}

## テスト
- [ ] {テスト項目}

## 備考
{レビュアーへの補足があれば}
```

4. 生成内容をユーザーに提示し、修正があれば反映する
5. リモートへプッシュしてから `gh pr create` で作成する
6. 作成したPRのURLを表示する
7. PR 作成後、`pr-review-loop` skill を自動で起動し、レビュー → 検証 → 修正 → 再レビューのループを回す（ユーザーが「レビュー不要」と明示した場合のみスキップ）。ループ収束後もマージはユーザーの手動操作に委ねる

## 注意事項

- PRタイトルは70文字以内に収める
- mainブランチへの直接PRが適切か確認する（ベースブランチの確認）
- ドラフトPRにするか確認する

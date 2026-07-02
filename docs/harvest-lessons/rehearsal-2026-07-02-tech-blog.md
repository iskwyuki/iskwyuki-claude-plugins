# harvest-lessons パイプライン・リハーサル記録（tech-blog）

- 実施日: 2026-07-02（Plans.md Task 1.3）
- 対象: iskwyuki/tech-blog（個人リポジトリ、105 コミット）
- 実行: Fable 5 ＋ assets/skills/harvest-lessons/SKILL.md の手順どおり
- 目的: 1.4（会社リポジトリ実走）の前に 収穫→検証→rules 化→サニタイズ検証 の一連を実走し手順を確立する

## 実走した手順と結果

### Step 1: 修正履歴の収集

- `git log --oneline`（全 105 コミット）、fix 系 grep、`git log --no-merges --name-only | sort | uniq -c` でホットスポット抽出
- ホットスポット: `dev-test-post.md`（34 回）、`qiita-publish/action.yml`（23 回）、merge コミット 10 件

### Step 2–3: パターン分類と裏取り

| # | パターン | 根拠（裏取り済み） | 分類 |
|---|---|---|---|
| 1 | 生成物 `.remote/` を追跡→8 回更新→`git rm` で解消 | f1152b0 / c0fd94e / 3c0f014、現在は未追跡を確認 | 再発パターン |
| 2 | CI bot の main 自動コミットと push 競合 | merge 10 件、action.yml:59 が現行挙動と確認 | 再発パターン |
| 3 | Zenn slug 制約違反のファイル名 | 0301c74（9 字 → 13 字へリネーム） | 予防可能 |
| 4 | 公開後の訂正 3 連発 | 7d3bed4 / 81fc4d0 / 95e98fd、preview script の存在を確認 | 再発パターン |
| 5 | workflow/action の main 直試行錯誤 | 「調整」「test」コミット群 | 再発パターン |
| — | 記事内容の推敲・version bump・README 更新 | — | ノイズ（一度きり・設計判断のため除外） |

### Step 4–5: rules 化

- 振り分け: 全件 `.claude/rules/`（#1 は将来 hooks 候補、#3 は CI grep 化候補と注記）
- 成果物: tech-blog コミット **`77163e1`**（`.claude/rules/articles.md` ＋ `sync-pipeline.md`、事例コミット ID 付き）

### サニタイズ検証（機械チェック）

1. **固有名チェック**: 会社関連語・トークン形式（`ghp_` / `github_pat_` / `sk-ant-`）を grep → **0 件**
2. **コード一致チェック**: 生成 rules の 20 字以上の各行を `git grep -F` で対象リポジトリ全体と照合 → **0 件**
3. 報告様式: 「サニタイズ検証済み: 固有名 0 件・コード一致 0 件」を commit message と本記録に明記

## 1.4（会社リポジトリ本番）への手順差分

リハーサルとの相違点。ここだけ守れば同じパイプラインがそのまま使える:

1. **Step 1 の取得方法が変わる**: clone 禁止。`GH_TOKEN=$(gh auth token -u <会社アカウント>) gh api` の read-only API のみで commits / diffs を取得する（ワンショット方式、`gh auth switch` 不使用）
2. **事例の書き方が反転する**: 個人リポジトリではコミット ID・ファイル名の引用が推奨だが、会社由来は**抽象化必須** — コミット ID・リポジトリ名・識別子名・ドメイン語彙を一切書かず概念に言い換える（例:「外部 API 呼び出しはタイムアウトとリトライ方針を明示」）。迷ったら保存しない
3. **保存先が変わる**: 対象リポジトリに rules を書けないため、汎用化した教訓を配信元（本リポジトリ）の assets / docs へ保存する
4. **固有名チェックリストはローカルで**: 会社固有語のチェックリストはローカル manifest（~/dev/quality-baseline-private/）で管理し、チェック実行もローカルで行う。記録には件数（0 件）のみ残す
5. **実行環境**: Mac のみ（ワンショットトークンと manifest が Mac にのみ存在）

## 汎用資産への昇格候補（/push-asset）

- 「生成物ディレクトリは最初のコミット前に .gitignore へ。追跡済みは ignore 追加では外れないので `git rm --cached`」— 複数リポジトリで通用（tech-blog の .remote、2026-06-14 のランタイム状態混入事故と同型）。次回 assets 更新時に code-review / commit skill の観点への追記を検討

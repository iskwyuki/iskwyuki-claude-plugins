# iskwyuki-claude-plugins Plans.md — 品質資産イニシアチブ

作成日: 2026-06-11

**目的**: Fable 5 がサブスク枠で使えるうちに、開発品質をモデル非依存のハーネス資産（プラグイン・rules・ゲート・物差し）へ焼き込む。

**期限**: Fable 5 のサブスク枠は **2026-07-07 まで**（2026-07-02 更新。旧期限 2026-06-22 は経過し、その後 Fable 5 が再度利用可能になった）。Fable 5 依存タスク（1.3 / 1.4 / 1.5）をこの期限までに消化することを最優先とし、モデル非依存タスク（Phase 2 / 3）は期限後でも継続可。1.4 の SSO 認可・read アクセスは確認済み（2026-07-02 再検証、生存）。

**前提（完了済み）**: 配布基盤 v0.4.2（harness 同梱・settings 自動展開・更新モニタ全状態出力）/ harvest-lessons（サニタイズ必須）/ code-review 全件報告＋検証パス＋rules-checker / pr-review-loop / portfolio での実証一式（pre-commit ゲート・rules 3点・breezing 1サイクル・PR #26 マージ）。

**推奨着手順**: 1.3 → 1.4 → 1.5 → 2.2 → 2.4 → 2.3 → Phase 3（2026-07-02 改訂。旧順序 2.2 → 2.3 → 1.3/1.5 は期限内全消化前提だった）。改訂理由: Fable 5 の可用性は一度失われた実績があるため、生成物の質がモデルに依存する資産生成（harvest / メモリ初期化）を先行し、モデル非依存の配管（bootstrap 汎用化・展開）を後続とするヘッジ。1.1 / 1.2 / 2.1 は完了済み。

**関連メモリ**（portfolio プロジェクトの memory）: 品質資産イニシアチブ / harness worktree 衝突 / ツール直前テキスト非表示問題。

---

## Phase 1: Fable 5 が使えるうちにしかできないこと（最優先）

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 1.1 | 品質の物差し作り（基準レビューセット）。ケース源は会社リポジトリ 2 つ（ローカル manifest 参照）を主、portfolio を従とする（2026-06-13 確定。個人リポジトリは更新頻度が低くデータが薄いため）。修正履歴から「バグ修正コミット直前」の diff を 5〜10 件選定して既知バグの正解リストを作り、Fable 5 の /code-review 結果とともに保存。保存先（2026-06-12 grill 確定、物差しは全リポジトリ共通資産）: 本体（個人ケース raw diff・正解リスト・レビュー結果・再実行手順 README・集計フォーマット）は本リポジトリの docs/quality-baseline/。会社ケースはローカル専用 manifest（~/dev/quality-baseline-private/、git 管理外）に repo 名＋SHA＋正解リストのみ保存し、raw diff は再実行時に gh 認証で都度取得。固有名を含まない集計数字のみ比較レポートに合流可。選定基準（2026-06-12 grill 確定）: レビューで検出可能な実装バグ限定（仕様誤解・環境起因・自明タイポ除外）、5 カテゴリ（ロジック/型・null/状態管理・hydration/非同期/設定・ビルド）×難易度分散、修正コミット SHA＋親 SHA を記録して再現可能に。会社分は 1.4 と同じ gh auth（SSO）前提を共有。会社側読み取りは「痕跡を残さない」運用（read-only API のみ・clone なし・write 系一切なし、2026-06-13 確定） [tdd:skip:docs-only] | 5 件以上のケース＋正解リスト＋Fable 5 レビュー結果が保存され、後日「別モデル＋資産」で同一セットを流して検出率比較できる再実行手順が README にある。正解リストは「ファイル＋関数（行範囲）＋根本原因 1 行＋重大度」で記録し、判定は「同一ファイルかつ同一根本原因で検出成功（行・表現ズレ許容）」、集計は 検出/部分検出/見逃し＋追加指摘（要真偽判定）の 4 区分（2026-06-12 grill 確定） | - | cc:完了 |
| 1.2 | 既存 skills の Fable 5 推敲。commit / pr / issue / test / todo / pull-assets / push-asset の各 SKILL.md を「原則＋チェックリスト＋過去事例」形式へ統一し、旧モデル向けの細かすぎる手順を削除（公式ガイドの推奨。code-review / reviewer は対応済み。review は 2.1 で削除確定のため対象外） [tdd:skip:docs-only] | 全 7 skill の見直し PR がマージされ version bump 済み。削った指示と残した指示の判断理由が PR 本文にある | - | cc:完了 |
| 1.3 | harvest-lessons のパイプライン・リハーサル（2026-06-13 縮小確定: 収穫の主軸が会社側に移ったため）。tech-blog 1 本で収穫→検証→rules 化→サニタイズ検証の一連の流れを実走し、1.4 本番前に手順を確立する（Antenna は余裕があれば追加） [tdd:skip:docs-only] | tech-blog に .claude/rules/ 追加コミットが入り、パイプライン動作確認（サニタイズ検証含む）の記録がある | - | cc:完了 [0185d3d] |
| 1.4 | harvest-lessons の会社リポジトリ実走。データ源の主軸（2026-06-13 確定）。SSO 認可・対象 2 リポジトリの read アクセス確認は完了済み（名称・アクセス手順はローカル manifest ~/dev/quality-baseline-private/ 参照）。読み取り専用で収穫 → サニタイズ検証 [tdd:skip:docs-only] | 教訓が汎用化されて保存され、報告に「サニタイズ検証済み: 固有名 0 件・コード一致 0 件」が明記されている | 1.3 | cc:完了 [86d829b] |
| 1.5 | メモリのブートストラップ。対象は Antenna ＋ tech-blog で確定（2026-06-12 grill、1.3 と同一）。過去セッション・git 履歴から教訓を抽出し、各リポジトリの auto-memory を初期化（公式推奨手法） [tdd:skip:docs-only] | portfolio 以外の 2 リポジトリ以上で MEMORY.md＋個別メモリが作成されている | - | cc:完了 |

## Phase 2: 体制の完成

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 2.1 | harness と自前資産の役割分担の文書化。方針は 2026-06-12 grill で確定済み: harness = 計画・実行規律（plan/work/breezing、サイクル内 verdict ゲートの harness-review / reviewer agent を含む）、自前 = 明示レビュー /code-review（lite/standard/full）＋ pr-review-loop（マージは 3.1 計測まで手動維持）、/review は削除（/code-review lite が代替。assets と SETUP.md から除去）、統合は常に PR ブランチ（main 直 cherry-pick 禁止。Lead はコミット分離の機械検証後に PR — 2.4 と連動）。残作業は docs / CLAUDE.md への明文化と /review 除去 [tdd:skip:docs-only] | 方針文書がマージされ、/review の削除を含む重複 skill の処遇が明記されている | - | cc:完了 |
| 2.2 | pre-commit 品質ゲートの汎用化。「.githooks/pre-commit ＋ package manager の prepare 配線」規約を bootstrap skill に組み込み、リポジトリ構成（package.json / pyproject.toml / Cargo.toml 等）を検出して雛形を生成 [tdd:skip:docs-only] | bootstrap 実行で Node / Python 系リポジトリにゲート雛形が生成され、portfolio の手書き版と整合している | - | cc:完了 [d281c86] |
| 2.3 | 他リポジトリへの bootstrap 展開。対象は Antenna / tech-blog / security-lab / post-syncer の 4 つで確定（2026-06-12 grill。後者 2 つは旧 plugin の更新が主目的、security-lab は 0.2.0 滞留の解消含む） [tdd:skip:docs-only] | 各リポジトリに plugin 現行版（0.8.x 以降）＋settings.json＋assets＋品質ゲートの導入コミットが入っている | 2.2 | cc:完了 [d00b109/66060ef/aa561c9/#65] |
| 2.4 | breezing 安全策の資産化。worktree 衝突（Worker の worktree はセッション単位で並列時に共有される）への対策「Lead は cherry-pick 前にコミット分離を機械検証する」を配信元 docs に明文化。upstream（Chachamaru127/claude-code-harness）への issue 報告も要否判断 [tdd:skip:docs-only] | docs 追加がマージされ、upstream 報告の実施/見送りの判断が記録されている | - | cc:完了 [0248f2a] |

## Phase 3: 実戦投入と仕上げ

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 3.1 | pr-review-loop の初実走と誤修正率の計測。実 PR で回し、false-fix 率を見て条件付き自動マージ（CI green ＋ 検証済み Critical ゼロ ＋ 収束）への昇格を判断 [tdd:skip:docs-only] | 実 PR 3 件で実走し、各回の指摘数・棄却数・誤修正数が記録され、昇格判断が文書化されている | 2.1 | cc:完了 [f3a14ec] |
| 3.2 | 目視 DoD の自動化（portfolio）。Playwright 最小 smoke: 主要ページのコンソールエラー・ハイドレーション警告検知＋テーマ切替 [tdd:required] | pnpm スクリプト 1 本で smoke が実行でき、ハイドレーション警告を意図的に仕込むと fail することを確認済み | - | cc:完了 [8d46e90] |
| 3.3 | 定期運転の設定。harvest-lessons の月次実行と基準レビューセット比較の定期化（2026-07-02 確定: **会社リポジトリの定期取得は恒久禁止**〔アクセスは資産作成フェーズ限りの特別許可で終了〕。対象は個人リポジトリのみ。実装は scripts/quality-monthly.sh ＋ NAS systemd user timer 毎月1日 09:57、レポートは NAS の .claude/state/monthly-reports/） [tdd:skip:docs-only] | schedule が登録され初回実行が確認されている | 1.1, 1.3 | cc:完了 [2114f4f] |
| 3.4 | 運用ドキュメント整備。モデル運用方針・レビュー方針・マージ方針を docs へ（2.1 の確定内容を反映） [tdd:skip:docs-only] | docs がマージされ、CLAUDE.md からの参照が貼られている | 2.1 | cc:完了 [cea99b3] |

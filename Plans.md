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

## Phase 4: 効果エビデンスの継続取得（recall 証明 ＋ 効果ログ）

**背景（2026-07-04 確定）**: Phase 1-3 で「配管が動く」ことは実証したが、初期化の核心「弱いモデル＋資産＝Fable 級品質」の定量証明は未達。物差し（1.1）は会社ケース 12＋公開ケース 1（PF-1）で構築され検出率 61.5%（Fable 5・2026-06-13）を得たが、会社ケースは 2026-07-02 に恒久凍結され再走不能、公開は実質 1 件で recall の継続証明基盤が痩せている。

**方針（2 本立て）**:
- **Track A（recall 証明・ground-truth ベース）**: 物差しの再走で「モデル交代時の検出率」を測る。初期証明は会社 12 ケースの**本日限りの単発再許可**で取得（恒久の定期取得禁止は維持。これは 3.3 の禁止に対する初期 baseline 比較のための一度きり例外）。以後の継続は公開ケースのみ ── ゆえに公開ケースの蓄積が必須。
- **Track B（効果ログ・real-usage テレメトリ）**: 資産の実行時に**決定的な発火点（pre-commit ゲート＝シェル）を主**として構造化ログを emit し、生ログは `.claude/state/`（非コミット）に、**サニタイズ集計値のみ**を本リポジトリで能動的に都度取得。recall（正解基準）とは別に「実作業での実捕捉」を継続証明する。
- **反映**: Artifact ページは CSP でライブ不可のため、集計更新時に「日付つき測定値」として手動再デプロイ。現在地を「recall 定量証明」＋「効果ログ累積」の 2 本立てへ書き換える。

**推奨着手順**: 4.1 → 4.4 → 4.2 → 4.5 → 4.3 → 4.6 **全完了（2026-07-05）**。recall 定量証明（4.1 会社初期＋4.3 公開継続）と効果ログ累積（4.5）の 2 本立てを Artifact（同 URL）に反映済み。**Phase 4 完了＝Plans 全 19 タスク完了**。以後の継続計測は月次ジョブ（3.3・公開のみ）と効果ログ収穫（4.5）で回り、Artifact は集計更新時に手動再デプロイ。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 4.1 | **【本日限り・最優先・会社アクセス時限】** recall 初期定量証明。`~/dev/quality-baseline-private/` の会社 12 ケース（CO-1..CO-12）の導入コミット diff を gh(SSO/ワンショット)で取得し、非 Fable モデル（最低 1: 強＝Opus 4.8、可能なら弱＝Sonnet/Haiku で degradation を bracket）で **baseline-protocol v1 厳守**（blind subagent・観点 2 agent 縮約・導入コミット後の履歴/PR/Issue 参照禁止・検証パスは採点側）で再走 → 4 区分採点 → Fable 61.5% と検出率比較。会社側は read-only・clone なし・痕跡残さない（1.1/1.4 と同運用）。恒久の定期取得禁止（3.3）は維持し、これは初期 baseline 比較のための単発例外 [tdd:skip:docs-only] | `results/2026-07-04-<model>-assets-0.10.1.md` に 12 ケース判定＋集計（検出率・部分込み・難易度別・カテゴリ別）が記録され、Fable baseline との比較が本リポジトリにコミット。サニタイズ検証（公開 results に固有名 0 件・SHA 0 件・コード 0 件）を明記。**本日中に実行**（アクセス失効前） | - | cc:完了 [647eb4d]（Opus 4.8: 検出 7/13・部分込み 10/13=Fable と同率、Haiku bracket 3ケースで degradation 確認。単発例外の会社アクセスは痕跡残さず完了、private manifest/メモリに実行記録追記） |
| 4.2 | 公開ケースの蓄積。個人リポジトリ（portfolio / Antenna / tech-blog / keiba 等）のバグ修正履歴から PF-2〜PF-N を選定基準（実装バグ限定・linter/型チェッカーで機械検出可能なもの除外・5 カテゴリ×難易度分散・導入 SHA＋親 SHA 記録）に沿って新規構築。公開ゆえ raw diff も `cases/` に含めてよい。以後の継続 recall 比較の土台 [tdd:skip:docs-only] | `cases/` に PF-* が計 8 件以上（既存 PF-1 含む）、INDEX.md 更新、各ケース SHA 記録で再現可能 | - | cc:完了 [8ff0735]（portfolio/Antenna から PF-2〜8 を新規構築＝公開計8件。9候補を subagent 並列分析→選定基準で7採用・4除外〔環境flaky/純CSS/仕様削除/doc-drift〕。カテゴリ×難易度分散、INDEX 全20件、会社固有名0。較正床〔易〕の補充は今後の課題） |
| 4.3 | 公開ケースでの継続 recall 計測。4.2 の公開セットに現行モデル（強・弱）を baseline-protocol v1 で流し `results/` に記録、3.3 の月次ジョブへ配線（会社禁止のまま公開のみ対象） [tdd:skip:docs-only] | 公開ケースでの現行モデル baseline が `results/` にあり、月次再走が 3.3 に組み込まれ初回実行が確認されている | 4.2 | cc:完了 [87606fd]（公開 8 ケースを baseline-protocol v1・blind 2 agent 縮約で計測。Opus 4.8〔強〕全 8＋Haiku 4.5〔弱〕代表 3。検出 3/8・部分込み 5/8。設定・ビルドは PF-8〔standalone 突合〕を Critical 検出＝歴史的 0/3 から改善、diff 外前提〔PF-1/6〕・実行時ミスマッチ〔PF-7〕は強でも未発火。Haiku bracket 3/3 保持だが各 1/2 agent 辛勝＝弱は自信ある偽陰性。会社アクセス 0・固有名/SHA 0 件。月次再走を quality-monthly.sh に配線〔公開のみ・draft は NAS・反映手動〕。lite review Critical/Warning 0） |
| 4.4 | 効果ログのスキーマ確定＋決定的 emit。JSONL スキーマ（timestamp / tool / model / repo_bucket(サニタイズ) / diff_size_bucket / findings{critical,warning,info} / verified_confirmed / refuted / gate{type,blocked,reason_category}）を確定。**pre-commit ゲート（シェル＝決定的）に blocked 記録**を追加し、`/code-review`・`/pr-review-loop` は末尾で `scripts/log-effect.sh` を呼ぶ（LLM に JSON 手書きさせない）。生ログは `.claude/state/harness-telemetry/*.jsonl`（gitignore 済み・非コミット） [tdd:required] | ゲート発火・code-review・pr-review-loop 実行で `.claude/state` に 1 行追記される（決定的経路＝ゲートは実測確認）。配信 asset 変更につき plugin.json version bump | - | cc:完了 [d529249]（決定的 pre-commit ゲート＋log-effect.sh〔配信のため scripts/→hooks/ に配置〕＋両 skill best-effort emit。TDD 全 PASS・ゲート発火で .claude/state に 1 行記録を実測。誤爆防止で deny は git add -A/機密のみ・記録は全 commit。配信 hook 化で全プロジェクト展開、plugin.json 0.11.0） |
| 4.5 | 効果ログの収穫＋サニタイズ集計。収穫スクリプト（3.3 拡張 or 新規）が各リポジトリの生ログを読み集計し、`docs/effect-log/YYYY-MM.md` に**集計値のみ**コミット。サニタイズ検証（固有名 / SHA / 指摘本文 0 件を機械 grep）をコミット前ゲートにする [tdd:skip:docs-only] | `docs/effect-log/` に初回集計（ゲート阻止回数・重大度別検出量・誤修正率・モデル別内訳）が入り、サニタイズ検証済み（固有名 0 件）が明記 | 4.4 | cc:完了 [c0e52a2]（scripts/harvest-effect-log.sh〔非配信〕＝個人リポのみ読み取り収穫→集計値のみ docs/effect-log/2026-07.md。サニタイズ検証を書き出し前ゲート化〔固有名=対象リポ実名/SHA=40hex の機械 grep、違反時 exit 1〕。初回 5 レコード。code-review standard で C1〔非オブジェクト行→空欄 md commit〕修正・model 等の再サニタイズ〔多層防御〕・denylist 動的生成を対応し tests/test-harvest-effect-log.sh 追加。plugin.json bump なし〔scripts/・docs/ は非配信〕） |
| 4.6 | Artifact ページを 2 本立てに更新。「現在地」を「recall 定量証明（4.1 会社初期＋4.3 公開継続）」と「効果ログ累積（4.5）」に書き換え、集計由来の数値で同 URL に再デプロイ。物差し凍結の経緯と、更新方式（手動・日付つき測定値・CSP でライブ不可）を正直に注記 [tdd:skip:docs-only] | 同 URL に再デプロイされ、recall 比較表（モデル×検出率）と効果ログ集計が反映、更新方式が明記されている | 4.1, 4.5 | cc:完了 [c49d933]（既存 Artifact 9b06eaf4… の「現在地」を 2 本立てに書換・同 URL 再デプロイ・WebFetch で検証。Track A=recall 比較表〔Fable 61.5%/76.9%→Opus会社 53.8%/76.9%→Opus公開 37.5%/62.5%〕＋物差し凍結・弱モデル bracket 注記、Track B=効果ログ〔総5・ゲート4/0・誤修正率0%〕。更新方式〔手動・日付つき・CSP でライブ不可〕を正直に注記。HTML を docs/artifact/ に SSOT 化。既存 blueprint デザイン保持・非配信ゆえ bump なし） |

## Phase 5: 運用バグ修正

**背景（2026-07-07・Issue #29）**: 配信 hook `hooks/pre-commit-gate.sh` の git-add-all 判定が case の部分文字列マッチのため、明示パス指定の `git add .claude/...` / `git add .gitignore` を `"git add ."` に誤マッチしてブロックする（Antenna で実害 2 回）。誤検知は add/commit 分割バイパスを常態化させ、ゲート実効性を下げる。

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 5.1 | pre-commit-gate の git-add-all 誤検知修正（Issue #29）。case 部分一致を grep -E のトークン境界判定に置換: `git add[[:space:]]+(-A|--all|-all|\.(/)?)([[:space:]]|;|&|\||$)`。Issue 記載案に対し 2 点補強 — (a) `git add ./`（`git add .` と等価）の抜けを `\.(/)?` でカバー、(b) 連続空白 `git add  -A` を `[[:space:]]+` でカバー。回帰テストを tests/test-pre-commit-gate.sh に追加（許可: `.claude/` 配下・`.gitignore` の明示パス add ／ ブロック: `git add .`・`git add ./`・`git add -A;` 連結・従来ケース B 維持）。配信 asset 変更につき plugin.json 0.14.0 → 0.14.1 [tdd:required] | 回帰テスト（誤検知 2 ケースが先に fail することを確認後に修正）を含む全テスト PASS、plugin.json bump 済み、PR マージで Issue #29 close。consumer 反映は update-plugins 経由である旨を Issue クローズコメントに明記 | - | cc:完了 [ae977d5]（TDD Red 証跡→20 ケース ALL PASS。レビューループ 2 周で旧実装比の後退 6 系統〔`..`・境界 `)>`・結合フラグ・引用符/バッククォート・多段ドットパス・テスト〕を追加回収、全指摘を実コマンド 3 者比較で confirmed 検証。0.14.1、PR #30 マージ・Issue #29 close・update-plugins 明記済み） |

## Phase 6: worktree 並列開発ツールの汎用化配信

**背景（2026-07-09・grill 進行中）**: 業務で使う worktree 並列起動キット（他リポジトリから抽出した約 1,200 行・ローカル参照）を**設計参考**に、git worktree による複数 issue 並列開発の土台を汎用化し配信 asset 化する。kit は共有 Postgres・実データ複製 DB・process-compose 起動が app スタック（uv/pnpm）固有だが、**worktree ライフサイクル（作成・設定/plugin 引き継ぎ・破棄・ポート採番）は汎用化可能**。app 固有部分はマニフェスト（`.wt-parallel.yaml`）＋フックに externalize する。

**確定した設計方針（grill Q1–Q10、2026-07-09）**:
- **Q1 導入形態**: 配信 asset として汎用化（このリポジトリ自身は起動対象 app を持たないため、価値の主軸は他 app プロジェクトへの pull 配布）
- **Q2 由来の扱い**: kit は設計仕様書としてのみ参照しゼロから再実装。**kit 固有識別子・由来リポジトリ名は docs / コミット / コメントに一切残さない**（このリポジトリの機密分離ルール）
- **Q3 externalize 方式**: 宣言的マニフェスト（`.wt-parallel.yaml`）1 本に集約。DB seed 等の動的処理はマニフェスト内のフックコマンド文字列として持たせる（別ファイル群にしない）
- **Q4 スコープ**: 起動オーケストレーションまで担う（`wt-up` 相当）。ただし **DB 複製は pre-start フックに委任**（Postgres 密結合の安全ガードは汎用化すると危険なため）。孤児 DB 掃除（kit 側の専用スクリプト）相当は汎用版に持たない
- **Q5 配置**: skill 同梱（`assets/skills/<name>/scripts/*.sh`）。pull-assets の既存機構で `.claude/skills/<name>/scripts/` に配布。リポジトリ直下は汚さず既存 `scripts/` と衝突しない。実行は skill 経由（絶対パス案内）
- **Q6 skill 構成**: 2 skill。作成入口（手動発火・`disable-model-invocation`・**AskUserQuestion 不使用でテキスト番号付き確認**）と、ライフサイクル正本（モデル自動参照可）
- **Q7 plugin 登録**: kit の enabledPlugins → project スコープ install ロジックを標準機能として再実装（app 非依存・Claude Code 状態のみ依存・非 CC/jq 不在で自動スキップ）。環境変数（例 `WT_SKIP_PLUGIN_REGISTER=1`）でオプトアウト可
- **Q8 表現力**: 最小コア。マニフェストは実質「単一 start コマンド + health URL」。汎用スクリプトは start をバックグラウンド実行 → ログを `.dev/logs/` へ → health を 200 までポーリング → 緑で return。**マルチプロセス/依存順序は start コマンドの責務**（process-compose を必須にしない）
- **Q9 フォールバック**: マニフェスト任意・起動 opt-in。マニフェスト無しなら `wt-new` は作成＋引き継ぎ＋plugin 登録のみ実行し起動系は案内して正常終了（**このリポジトリ自身で dogfood 可能**）
- **Q10 命名**: `wt-parallel` 系。作成入口 `/wt-new`、正本 `wt-parallel`、マニフェスト `.wt-parallel.yaml`

**設計確定（grill Q11–Q19、2026-07-09）＋設計仕様書**: 詳細は [docs/wt-parallel-design.md](docs/wt-parallel-design.md)（設計正本）。Q11 コマンド体系 `wt-new`/`wt-up`/`wt-down`/`wt-rm`＋`wt-identity`、Q12 health は url/command 両対応（既定 60s）、Q13 フック 4 種（post-create/pre-start/post-start/pre-rm）、Q14 ポートは offset のみ採番・意味づけは app、Q15 env マップで start/health.url/フックへ共通注入、Q16 引き継ぎは settings.local.json＋.env デフォルト＋`inherit:` 追加、Q17 起点は env>マニフェスト>origin/HEAD>現在ブランチ、Q18 純粋関数単体＋統合スモーク、Q19 skill 集約＋docs 1 ページ。dogfooding は配信元 symlink（`.claude/skills -> ../assets/skills`）でカバー済み [[source-repo-symlink-not-plugin]]。

**実装前 or 実装中に確定する残論点**（設計書§12）: ~~マニフェスト YAML パーサ（`yq` 依存 vs 自前）~~ **確定（2026-07-09）: 最小自前パース（strict subset・`yq` 非依存）。対応部分集合は設計書 §5.1**／~~`.dev/` の gitignore 自動追記の方式~~ **確定（2026-07-09・6.1 実装時）: `wt-new` が git-native exclude（`.git/info/exclude`）へ冪等追記（tracked な `.gitignore` を汚さない）**／health url の `${...}` 安全展開の実装詳細（6.3・起動系で確定）。

**暫定タスク分割（3 ステージ・段階リリース。各ステージ完了時に配信 asset 変更につき plugin.json bump）**:

| Task | 内容 | DoD | Depends | Status |
|------|------|-----|---------|--------|
| 6.1 | **[Stage 1: 土台]** `wt-new` / `wt-rm` / `wt-identity`（slug 採番・`.dev/` 永続化）＋設定引き継ぎ（`.env` / `.claude/settings.local.json`）＋plugin 登録引き継ぎ＋作成入口 skill `/wt-new`（テキスト確認・AskUserQuestion 不使用）。マニフェスト無しで動作（起動系は opt-in 案内）。このリポジトリ自身で dogfood [tdd:required] | マニフェスト無しのリポジトリで worktree 作成→設定/plugin 引き継ぎ→破棄が一巡し、`git worktree add` 直叩きを使わずに済む。回帰テストで plugin 登録の非 CC スキップを確認。plugin.json bump | - | cc:完了（TDD Red→Green。純粋関数 test-wt-identity＋統合スモーク test-wt-lifecycle 全 PASS、自リポジトリで wt-new→wt-rm 往復を dogfood 実走。plugin 対称解除＋`WT_SKIP_PLUGIN_REGISTER` オプトアウトを 6.4 から先取り〔破棄一巡の clean 化のため〕。`.dev/` は git-native exclude 冪等追記。0.15.0）|
| 6.2 | **[Stage 1]** マニフェストスキーマ（`.wt-parallel.yaml`）確定。start コマンド・health URL・ポート採番の基底/注入 env 変数名・引き継ぎファイル・フック種別を最小セットで設計し `.wt-parallel.yaml.example` とスキーマ注記を用意 [tdd:skip:docs-only] | スキーマ例とフィールド仕様が docs 化され、6.3 の実装が参照できる。最小マニフェスト（start + health のみ 10 行以内）で起動できる設計であることを明記 | - | cc:完了（`.wt-parallel.yaml.example`〔S1/S2 凡例・10 行以内の最小例つき〕＋設計書 §5.1 strict-subset 文法＋wt-parallel SKILL.md にフィールド仕様。yq 非依存パースを明記）|
| 6.3 | **[Stage 2: 起動]** `wt-up`（start バックグラウンド起動→`.dev/logs/` ログ集約→health ポーリング→緑で return）／`wt-down`＋ポート自動採番（基底+offset の空きポート探索・`.dev/` 永続化）＋pre-start/post-start フック実行＋正本 skill `wt-parallel` [tdd:required] | マニフェストを持つサンプル（単一プロセス）で `wt-up`→health 緑待ち→URL/ログパス提示→`wt-down` が通る。ポート衝突が自動回避される。plugin.json bump | 6.2 | cc:完了（TDD Red→Green。wt-identity に 2階層マップ/flow list パーサ・マニフェスト loud-error 検証・空きポート offset 採番・env 式展開サンドボックス〔§12.3: 値は `wt_expand_value` で `${VAR}`/`$VAR`/`$((算術))` のみ・`$(...)`/backtick 拒否、start/hooks は sh -c 実行と責務分離〕を追加。統合スモーク test-wt-startup で command-health フル一巡＋python3/curl 時は実 HTTP・実ポート衝突回避を E2E 検証。reviewer APPROVE〔critical/major 0〕＋minor 4 件反映。ネスト `.claude/state/` 混入を検知し gitignore 二重防御追加。0.16.0）|
| 6.4 | **[Stage 2]** `wt-rm` の plugin 登録対称解除（`claude plugin uninstall --scope project`）＋環境変数オプトアウト（`WT_SKIP_PLUGIN_REGISTER`）＋安全不変条件のガイド（ソース DB を drop しない等は pre-start フックの書き方 doc として提供） [tdd:required] | `wt-rm` 後に `installed_plugins.json` にダングリングが残らないことを確認。オプトアウト時に plugin 登録がスキップされる回帰テスト。plugin.json bump | 6.1 | cc:完了（対称解除・オプトアウトは 6.1 先取り済み。6.4 で Stage 2 の wt-rm を完成: 破棄前の停止〔wt-down 連携・§6 [stop]〕＋`pre_rm` フック実行〔WT_SLUG/WT_OFFSET+env 注入・失敗は警告どまりで破棄続行〕を追加。SKILL.md に安全ガイド〔`${WT_SLUG}` 限定でソース/共有 DB を消さない〕。test-wt-teardown 新規: pre_rm 実行＋注入・stop・stub claude での対称解除〔ダングリング無し〕・pre_rm 失敗継続を決定的検証。reviewer 待ち。0.17.0）|
| 6.5 | **[Stage 3: 実証・横展開]** 実 app プロジェクト 1 つ（Antenna 等・起動対象あり）に `.wt-parallel.yaml` を置き起動込みで実走。docs 整備（`docs/wt-parallel.md`）・利用者向け README への導線追加・pull-assets 配布確認 [tdd:skip:docs-only] | 実 app プロジェクトで worktree 作成→起動→health 緑→停止→破棄が一巡した記録がある。docs マージ・CLAUDE.md/README から参照 | 6.3 | cc:TODO |

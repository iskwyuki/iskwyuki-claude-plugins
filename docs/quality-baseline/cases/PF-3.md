# PF-3: 「最新」モードの無フィルタ全期間取得とアーカイブ単日絞込の非対称（同日記事の不一致）

- リポジトリ: [iskwyuki/Antenna](https://github.com/iskwyuki/Antenna)（公開）
- 導入コミット（レビュー対象）: `aa81bee`（日付スイッチャーを追加）
- 修正コミット: `77b6d8d`（「最新に戻る」と特定日アーカイブで同日の記事が一致しない不整合を修正）
- カテゴリ: ロジック
- 重大度: Medium
- 難易度: 中

## 正解

| ファイル | 関数 | 根本原因 |
|---|---|---|
| `src/app/page.tsx` / `src/lib/digest.ts` | fetchDigestByTopics / fetchLatestByContentType | 「最新」モード（`/`・date 未指定）は `date=undefined` を各 fetch に渡し `fetchedAt` フィルタを一切かけず `publishedAt desc` で全期間から拾う一方、`/?date=X` は `jstDayRange` で単日絞込するため、複数バッチ実行日があると「最新」と「アーカイブ」で表示集合がズレる |

## 検出の核心

導入 diff（page.tsx + digest.ts）内に非対称性が可視化されている — 最新モードは `opts.date` が undefined → `articleWhere = undefined`（フィルタなし・全期間）、explicit な `?date` は単一 JST 日で絞込。この「最新＝無フィルタ全期間 vs アーカイブ＝単日絞込」の食い違いに気づけば検出可能（バッチ日が複数存在し得るというドメイン前提の理解が要る）。型は valid で tsc / eslint / biome / build は通過。

## 再現コマンド

```bash
git -C ~/dev/Antenna show aa81bee   # レビュー対象 diff（PF-4 と同一の導入コミット・別バグ）
git -C ~/dev/Antenna show 77b6d8d   # 修正の裏付け
```

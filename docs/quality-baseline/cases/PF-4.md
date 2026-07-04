# PF-4: 日付パラメータの形式のみ検証（暦として無効な値の実行時例外）

- リポジトリ: [iskwyuki/Antenna](https://github.com/iskwyuki/Antenna)（公開）
- 導入コミット（レビュー対象）: `aa81bee`（日付スイッチャーを追加。PF-3 と同一導入コミット・別バグ）
- 修正コミット: `d15a7ba`（日付スイッチャーの date パラメータに無効日付バリデーションを追加）
- カテゴリ: ロジック
- 重大度: Medium
- 難易度: 中

## 正解

| ファイル | 関数 | 根本原因 |
|---|---|---|
| `src/app/page.tsx` / `src/lib/digest.ts` | date パース / jstDayRange | `dateRegex.test()` は文字列の「形式」しか検証せず、`2026-13-45` のような暦として無効な値を通す。下流の `jstDayRange` が `new Date(\`${dateStr}T00:00:00+09:00\`)` を組み立てると Invalid Date（NaN）になり、そのまま Prisma の `fetchedAt: { gte, lt }` 範囲クエリに渡って実行時に throw する |

## 検出の核心

導入 diff で `const date = sp.date && dateRegex.test(sp.date) ? sp.date : undefined`（page.tsx）が**形式のみ**検証している点に気づき、`jstDayRange` が ISO 文字列を組み立てて範囲外値が Invalid Date になる下流の流れを追えること。型は `string` で正しく正規表現も構文有効なため tsc / eslint / biome / build は通過し、無効値は実行時（Prisma の DateTime 検証）でのみ露見する。通常の UI 導線では正常日付しか生成されないエッジ起因。

## 再現コマンド

```bash
git -C ~/dev/Antenna show aa81bee   # レビュー対象 diff（PF-3 と同一の導入コミット・別バグ）
git -C ~/dev/Antenna show d15a7ba   # 修正の裏付け
```

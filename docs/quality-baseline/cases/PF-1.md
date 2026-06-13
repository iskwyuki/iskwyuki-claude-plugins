# PF-1: generateStaticParams の locale セグメント欠落（本番 500）

- リポジトリ: [iskwyuki/portfolio](https://github.com/iskwyuki/portfolio)（公開）
- 導入コミット（レビュー対象）: `55982a7`（ブログ機能を実装）
- 修正コミット: `4dc276b`（Vercel 500 エラー修正）
- カテゴリ: 設定・ビルド（SSG/ルーティング）
- 重大度: High
- 難易度: 中

## 正解

| ファイル | 関数 | 根本原因 |
|---|---|---|
| `src/app/[locale]/blog/[slug]/page.tsx` | `generateStaticParams` | `[locale]` 動的セグメント配下のページなのに `{ slug }` のみ返し locale を列挙しないため、SSG パラメータが動的セグメントと一致せず本番で 500 になる |

## 検出の核心

導入 diff ではファイルパス `src/app/[locale]/blog/[slug]/page.tsx` と `generateStaticParams` の返却形（`posts.map((post) => ({ slug: post.slug }))`）が同一 diff 内に見えている。パスの動的セグメント 2 つと返却キー 1 つの不一致に気づけるかが分かれ目。

## 修正後の形（参考）

```ts
return routing.locales.flatMap((locale) =>
  posts.map((post) => ({ locale, slug: post.slug }))
)
```

## 再現コマンド

```bash
git -C ~/dev/portfolio show 55982a7   # レビュー対象 diff
git -C ~/dev/portfolio show 4dc276b   # 修正の裏付け
```

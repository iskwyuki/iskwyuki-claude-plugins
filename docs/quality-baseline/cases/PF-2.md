# PF-2: document シェルを locale 動的セグメント配下に置いた再マウント（言語切替で白飛び）

- リポジトリ: [iskwyuki/portfolio](https://github.com/iskwyuki/portfolio)（公開）
- 導入コミット（レビュー対象）: `2fc222e`（next-intl・next-themes で `[locale]` 構成へ移行）
- 修正コミット: `cde262c`（言語切替時の白飛びを解消・layout 階層を再構成）
- カテゴリ: 状態管理
- 重大度: Medium
- 難易度: 難

## 正解

| ファイル | 関数 | 根本原因 |
|---|---|---|
| `src/app/[locale]/layout.tsx`（新規） / `src/app/layout.tsx`（削除） | LocaleLayout | `<html>`/`<body>`/`ThemeProvider` を locale 動的セグメント（`[locale]/layout.tsx`）配下に置き、root layout を不在にしたため、locale 切替でセグメント param が変わると document シェルごと再マウントされ、背景が一瞬失われる（ダークモードで白フラッシュ） |

## 検出の核心

導入 diff で「新規追加された最上位 layout のパスが `src/app/[locale]/layout.tsx` であり、そこに html/body が入っている（＝root `src/app/layout.tsx` が削除されている）」ことに気づくこと。動的セグメント layout に document シェルを置くと locale 変更で再マウントされる、という Next.js の framework 挙動を結び付ける必要がある。コードは tsc / eslint / biome / `next build` すべて通過し警告も出ない。レビュー対象は layout 2ファイル（globals.css・lockfile 等はノイズなので除外推奨）。

## 再現コマンド

```bash
git -C ~/dev/portfolio show 2fc222e -- src/app/layout.tsx 'src/app/[locale]/layout.tsx'   # レビュー対象（layout 2ファイルにスコープ）
git -C ~/dev/portfolio show cde262c   # 修正の裏付け
```

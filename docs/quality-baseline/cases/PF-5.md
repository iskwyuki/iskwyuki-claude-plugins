# PF-5: サーバ専用シークレットを Client Component の prop に渡し RSC ペイロードで露出

- リポジトリ: [iskwyuki/Antenna](https://github.com/iskwyuki/Antenna)（公開）
- 導入コミット（レビュー対象）: `2ba141b`（Phase 4 レビュー指摘対応。環境変数 API キー認証を追加した際に露出が生じた）
- 修正コミット: `21db603`（BATCH_API_KEY のクライアント露出を解消・Server Action 化）
- カテゴリ: セキュリティ・認可
- 重大度: High
- 難易度: 中

## 正解

| ファイル | 関数 | 根本原因 |
|---|---|---|
| `src/app/settings/page.tsx` / `src/components/settings/BatchRunner.tsx` | SettingsPage → BatchRunner | Server Component が `process.env.BATCH_API_KEY`（サーバ専用シークレット）を `"use client"` の `BatchRunner` へ prop（`apiKey`）として渡し、RSC ペイロード経由でブラウザに配信・露出させた。皮肉にも「API キー認証を追加する」というセキュリティ強化コミットが、追加したはずの認証を自壊させている |

## 検出の核心

渡し先 `BatchRunner.tsx` 冒頭が `"use client"`（Client Component）であることを確認し、`process.env.BATCH_API_KEY` のような秘密値を server→client の prop に渡すと Next.js が RSC ペイロードとしてクライアントへシリアライズ配信する、という App Router の server/client 境界の知識を適用する。型は `apiKey?: string` で valid、`NEXT_PUBLIC_` 接頭辞もないため命名シグナルすら無く、tsc / eslint / biome では機械検出不可。レビュー対象は settings/page.tsx ＋ BatchRunner.tsx にスコープ（導入コミット全体は lockfile を含み肥大）。

## 再現コマンド

```bash
git -C ~/dev/Antenna show 2ba141b -- src/app/settings/page.tsx src/components/settings/BatchRunner.tsx   # レビュー対象（2ファイルにスコープ）
git -C ~/dev/Antenna show 21db603   # 修正の裏付け
```

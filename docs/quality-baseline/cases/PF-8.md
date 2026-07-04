# PF-8: 本番 Dockerfile が standalone 出力を要求するのに next.config で未指定（prod ビルド破綻）

- リポジトリ: [iskwyuki/Antenna](https://github.com/iskwyuki/Antenna)（公開）
- 導入コミット（レビュー対象）: `a847e34`（MVP 初期実装。PF-6 と同一導入コミット・別バグ）
- 修正コミット: `bb0f2b6`（standalone 出力設定追加）
- カテゴリ: 設定・ビルド
- 重大度: High
- 難易度: 中

## 正解

| ファイル | 対象 | 根本原因 |
|---|---|---|
| `Dockerfile` / `next.config.ts` | runner ステージ / next 設定 | 本番 Dockerfile は `.next/standalone` を COPY し `node server.js` で起動するが、`next.config.ts` に `output: "standalone"` が無いため standalone 出力（server.js 含む）が生成されず、prod ビルドが COPY 段で破綻する |

## 検出の核心

導入 diff に Dockerfile の runner ステージ（`COPY --from=builder /app/.next/standalone ./` ＋ `CMD ["node","server.js"]`）と `next.config.ts`（実質空設定）が両方含まれる。この2ファイルを突き合わせ、「Next.js の standalone 出力は `output:"standalone"` 指定時のみ生成される」という前提知識で「Dockerfile が要求する成果物を config が生成しない」不整合に気づける。tsc / eslint / biome では検出できず、prod イメージのビルド時に初めて顕在化。レビュー対象は Dockerfile ＋ next.config.ts に絞る（導入コミット全体は約2,900行）。

## 再現コマンド

```bash
git -C ~/dev/Antenna show a847e34 -- Dockerfile next.config.ts   # レビュー対象（2ファイルにスコープ）
git -C ~/dev/Antenna show bb0f2b6   # 修正の裏付け
```

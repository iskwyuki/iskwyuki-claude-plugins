# PF-7: WebSearch を伴う子プロセス呼び出しに実処理時間より短いタイムアウト（abort→リトライ再実行）

- リポジトリ: [iskwyuki/Antenna](https://github.com/iskwyuki/Antenna)（公開）
- 導入コミット（レビュー対象）: `9b21908`（業界トレンド収集。WebSearch + 180 秒呼び出しを追加）
- 修正コミット: `06cfe64`（claude -p のタイムアウトを全処理 600 秒に統一）
- カテゴリ: 非同期
- 重大度: Medium
- 難易度: 中

## 正解

| ファイル | 対象 | 根本原因 |
|---|---|---|
| `agent/daily.ts` / `lib/claude.ts` | Phase 3 の WebSearch 呼び出し / spawnClaude | WebSearch / WebFetch を伴う opus の `claude -p` 呼び出しに、実処理時間（数分規模）より短い `timeoutMs: 180_000` を設定。`spawnClaude` のタイムアウトが AbortController で in-flight の子プロセスを kill し retryable 扱いで全処理を再実行するため、成功しかけの収集が abort→リトライ再実行され、Opus トークンを浪費しダイジェストが欠損する |

## 検出の核心

導入 diff 内で `allowedTools: ["WebSearch","WebFetch"]` と `timeoutMs: 180_000` が同居している点に注目し、Web 検索＋複数記事の WebFetch ＋ opus の構造化出力が 180 秒超になるのが常態であること、かつタイムアウトが in-flight の子プロセスを kill してリトライ再実行する挙動を結び付ける必要がある。`180_000` は一見妥当に見え、tsc / eslint / biome では「この処理には短すぎる」という意味的・実行時ミスマッチを検出できない。

## 再現コマンド

```bash
git -C ~/dev/Antenna show 9b21908   # レビュー対象 diff（Phase 3 の WebSearch 呼び出し追加）
git -C ~/dev/Antenna show 06cfe64   # 修正の裏付け
```

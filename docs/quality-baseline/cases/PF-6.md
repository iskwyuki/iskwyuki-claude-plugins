# PF-6: Makefile の dev ターゲットだけ DB 前提依存が欠落（仲間外れパターン）

- リポジトリ: [iskwyuki/Antenna](https://github.com/iskwyuki/Antenna)（公開）
- 導入コミット（レビュー対象）: `a847e34`（MVP 初期実装。PF-8 と同一導入コミット・別バグ）
- 修正コミット: `5cf841f`（Makefile の dev ターゲットに db 依存を追加）
- カテゴリ: 設定・ビルド
- 重大度: Low〜Medium
- 難易度: 中

## 正解

| ファイル | 対象 | 根本原因 |
|---|---|---|
| `Makefile` | `dev` ターゲット | 他の DB 依存ターゲット（migrate / seed / collect）は `db` 前提に連鎖するのに、`dev` だけ `db` 前提依存を宣言していない。`next dev` は Server Component / API 経由で Prisma に接続するため、`make dev` 単独実行時に DB 未起動なら接続失敗する。`make setup` が db を先に起動するため happy path では隠蔽される |

## 検出の核心

導入 diff 内で migrate:db / seed:migrate / collect:migrate と db 連鎖する中、`dev:` だけ前提が無い「仲間外れ」パターンに気づくこと。決定打は、同コミットの `.claude/commands/dev.md` 手順1が「DB 起動確認（未起動なら起動）」を明示しているのに Makefile `dev` はその手順を省略している矛盾。Makefile の意味的な依存欠落は linter / 型検査で捕捉できない。レビュー対象は `Makefile` ＋ `.claude/commands/` に絞ると信号対雑音比が改善する（導入コミット全体は約2,900行）。

## 再現コマンド

```bash
git -C ~/dev/Antenna show a847e34 -- Makefile .claude/commands/   # レビュー対象（Makefile + commands にスコープ）
git -C ~/dev/Antenna show 5cf841f   # 修正の裏付け
```

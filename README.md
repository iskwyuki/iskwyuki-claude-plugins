# iskwyuki-claude-plugins

📐 **[配布ハーネスの設計図（インタラクティブ）](https://claude.ai/code/artifact/9b06eaf4-9178-4bbd-a7a7-c5c4e0b6f0ba)** — 配信元→bootstrap→各リポジトリの流れ・適用マトリクス・資産インベントリ・現在地を視覚的にまとめたページ。

iskwyuki 個人用 Claude Code アセットの配信基盤。

複数リポジトリで共通利用する skills / agents / (将来的な) hooks / commands を中央管理し、Claude Code の Plugin Marketplace 機構で継続配信します。

## 配信の2レイヤー

性質の異なる 2 つの仕組みでアセットを配ります。**harness は ① で自動的に入り、`pull-assets`（②）では入りません。**

| レイヤー | 運ぶもの | 入り方 |
|---|---|---|
| **① Plugin 機構** | iskwyuki 本体 + **claude-code-harness** | `/plugin install` 一発（harness は `dependencies` で自動同梱） |
| **② asset 機構** | iskwyuki 固有の skills / agents | `/pull-assets` でプロジェクトの `.claude/` にコピー |

harness は「プラグイン」であって「asset」ではないため ① で入ります。`pull-assets`（②）の対象では**ありません**。詳細は [SETUP.md](./SETUP.md) を参照。

## 使い方

セットアップ手順は [SETUP.md](./SETUP.md) を参照してください。

### 初回導入

各プロジェクトのルートで以下を 1 回だけ実行:

```
/plugin marketplace add iskwyuki/iskwyuki-claude-plugins
/plugin install iskwyuki-claude-plugins@iskwyuki-claude-plugins
/iskwyuki-claude-plugins:bootstrap
git add .claude/ && git commit -m "chore: iskwyuki-claude-plugins 初回同期"
```

bootstrap 完了後、プロジェクトの `.claude/` 配下に `pull-assets` / `push-asset` を含む全 asset が展開され、以降は短縮名で運用できます。

> 依存プラグインとして [claude-code-harness](https://github.com/Chachamaru127/claude-code-harness)（Plan→Work→Review の自律開発サイクル）が同梱されており、本プラグインのインストール時に自動でインストール・有効化されます。

> また、[mattpocock/skills](https://github.com/mattpocock/skills)（MIT）から harness と役割も生成物も衝突しない `/grill-me` / `/zoom-out` / `/prototype` を、[vercel-labs/skills](https://github.com/vercel-labs/skills)（MIT）から `/find-skills` を選別して `assets/skills/` にミラーしています。上流追従は GitHub Action が毎日チェックし、差分があれば同期 PR を自動作成します。

### プラグイン更新モニタ

同梱の SessionStart hook が、セッション開始時にインストール済みプラグインの更新有無をチェックして通知します（TTL 12時間。ただし失敗を含む結果は 1 時間で失効し自動再チェック）。実施・スキップ・失敗・検知のすべての状態を 1 行で表示します。更新の適用・失敗時の対処・巻き戻しは `/iskwyuki-claude-plugins:update-plugins` を参照。

## リポジトリ構造

```
.
├── .claude-plugin/
│   ├── marketplace.json     # Plugin Marketplace 定義
│   └── plugin.json          # plugin 定義
├── skills/
│   ├── bootstrap/           # /iskwyuki-claude-plugins:bootstrap (初回導入の踏み台)
│   └── update-plugins/      # /iskwyuki-claude-plugins:update-plugins (更新の適用・巻き戻し)
├── hooks/
│   ├── hooks.json           # SessionStart: プラグイン更新チェック
│   └── check-plugin-updates.sh
├── assets/
│   ├── skills/
│   │   ├── pull-assets/     # /pull-assets (配信元 → プロジェクト)
│   │   ├── push-asset/      # /push-asset (プロジェクト → 配信元)
│   │   ├── commit/ pr/ issue/ test/ todo/ code-review/
│   └── agents/
│       └── codebase-analyst.md planner.md researcher.md reviewer.md
├── SETUP.md                 # セットアップ手順 (利用者向け)
└── README.md
```

## 運用フロー

- **配信元の更新をプロジェクトに取り込む**: `/iskwyuki-claude-plugins:update-plugins`（marketplace update → plugin update → asset 同期 → commit 案内をワンステップ実行）
- **プロジェクトで作った asset を他リポジトリにも展開**: `/push-asset skills <name>` → 配信元で commit & push → 他リポジトリで `/iskwyuki-claude-plugins:update-plugins`

詳細は [SETUP.md](./SETUP.md) を参照。

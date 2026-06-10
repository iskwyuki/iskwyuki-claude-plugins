# iskwyuki-claude-plugins

iskwyuki 個人用 Claude Code アセットの配信基盤。

複数リポジトリで共通利用する skills / agents / (将来的な) hooks / commands を中央管理し、Claude Code の Plugin Marketplace 機構で継続配信します。

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

### プラグイン更新モニタ

同梱の SessionStart hook が、セッション開始時にインストール済みプラグインの更新有無をチェックして通知します（TTL 12時間、ネットワーク失敗時は無音でスキップ）。更新の適用・巻き戻しは `/update-plugins` を参照。

## リポジトリ構造

```
.
├── .claude-plugin/
│   ├── marketplace.json     # Plugin Marketplace 定義
│   └── plugin.json          # plugin 定義
├── skills/
│   └── bootstrap/           # /iskwyuki-claude-plugins:bootstrap (初回導入の踏み台)
├── hooks/
│   ├── hooks.json           # SessionStart: プラグイン更新チェック
│   └── check-plugin-updates.sh
├── assets/
│   ├── skills/
│   │   ├── pull-assets/     # /pull-assets (配信元 → プロジェクト)
│   │   ├── push-asset/      # /push-asset (プロジェクト → 配信元)
│   │   ├── review/ commit/ pr/ issue/ test/ todo/ code-review/ update-plugins/
│   └── agents/
│       └── codebase-analyst.md planner.md researcher.md reviewer.md
├── SETUP.md                 # セットアップ手順 (利用者向け)
└── README.md
```

## 運用フロー

- **配信元の更新をプロジェクトに取り込む**: `/plugin marketplace update` → `/pull-assets` → commit
- **プロジェクトで作った asset を他リポジトリにも展開**: `/push-asset skills <name>` → 配信元で commit & push → 他リポジトリで `/pull-assets`

詳細は [SETUP.md](./SETUP.md) を参照。

# Z-CMS — 公式 Docker イメージ

[English](../README.md) | [Tiếng Việt](README.vi.md) | **日本語**

[Z-CMS](https://github.com/zscontributor/z-cms) — テーマエンジンと署名付きプラグイン
マーケットプレイスを備えたマルチテナント CMS — をビルド済み Docker イメージで実行します。
このリポジトリは、稼働中インスタンスへの最短ルートです。公式イメージ、完全な
`docker compose` スタック、主要サーバー向けのリバースプロキシ設定（Traefik、Caddy、
Nginx、Apache、Portainer）、そして運用ガイドを提供します。

- **ソースコード:** [github.com/zscontributor/z-cms](https://github.com/zscontributor/z-cms)
- **イメージ:** Docker Hub の [`zcms`](https://hub.docker.com/u/zcms)
- **ドキュメント:** [docs.z-cms.org](https://docs.z-cms.org)

---

## 構成コンポーネント

| レイヤー | サービス | イメージ | ポート |
| --- | --- | --- | --- |
| 公開サイト | `site-runtime` | `zcms/site-runtime` | 3000 |
| 管理画面 | `admin-web` | `zcms/admin-web` | 3001 |
| コア API | `cms-api` | `zcms/cms-api` | 4100 |
| バックグラウンドジョブ | `worker` | `zcms/worker` | — |
| プラグインサンドボックス | `plugin-runtime` | `zcms/plugin-runtime` | 4200 |
| マイグレーション/シード | `migrate` | `zcms/migrate` | —（1 回だけ実行） |
| データベース | `postgres` | `postgres:17-alpine` | 5432 |
| キャッシュ / キュー | `redis` | `redis:8-alpine` | 6379 |
| メディアストレージ | `rustfs` | `rustfs/rustfs` | 9000/9001 |

イメージは **マルチアーキテクチャ**（`linux/amd64` + `linux/arm64`）で公開されており、
x86 サーバーでも ARM（Apple Silicon、AWS Graviton）でも動作します。

## 必要要件

- **Docker Engine 24+** と **Compose v2** プラグイン（`docker compose version`）。
- 余裕をもって起動するには ~**2 vCPU / 4 GB RAM** のホスト。
- 公開運用には、ホストを指す **ドメイン名** と、インターネットから到達可能な
  ポート **80 + 443**。

## クイックスタート（localhost・約 5 分）

```bash
git clone https://github.com/zscontributor/z-cms-docker-offical-image.git zcms
cd zcms

# 1. 強力なランダムシークレット付きの .env を作成
cp .env.example .env
./scripts/generate-secrets.sh --write

# 2. スタックを起動（公式イメージを自動取得）
docker compose up -d

# 3. 最初の管理者 + デモサイトを作成（1 回だけ）
./scripts/first-run-seed.sh
```

アクセス先:

- 公開サイト → <http://localhost:3000>
- 管理画面 → <http://localhost:3001/admin>（`.env` の `SEED_ADMIN_EMAIL` /
  `SEED_ADMIN_PASSWORD` でログイン）
- API ドキュメント → <http://localhost:4100/api/v1/docs>
- 受信メール（Mailpit） → <http://localhost:8025>

> **ポートは `3100` / `3101` ではなく `3000` / `3001` です。** これらのイメージは
> Z-CMS を本番モード（`next start`）で実行するため、標準の `3000`（サイト）と
> `3001`（管理）にバインドします。[ソース](https://github.com/zscontributor/z-cms)
> の開発サーバー（`next dev`）は、開発マシンで既に使われがちなポートと衝突しない
> よう、意図的に `3100` / `3101` へ再マッピングされています。API（`4100`）は両者で
> 同じです。そのため、ソースの開発スタック（`3100` / `3101`）と、この Docker
> スタック（`3000` / `3001`）を同じマシンで同時に実行してもポートが競合しません。

停止: `docker compose down`（データも削除するには `-v` を付与）。

## ドメイン + HTTPS での本番運用

まず `.env` をドメインと HTTPS 向けに変更します:

```dotenv
DOMAIN=your-domain.com
PUBLIC_SCHEME=https
ROOT_DOMAIN=your-domain.com
ACME_EMAIL=you@your-domain.com
CMS_API_URL=https://your-domain.com
ADMIN_WEB_URL=https://your-domain.com
SITE_RUNTIME_URL=https://your-domain.com
S3_PUBLIC_URL=https://your-domain.com/zcms-media
```

ドメインの `A`/`AAAA` DNS レコードをホストに向けたうえで、リバースプロキシを選びます。
各プロキシは `docker-compose.yml` に重ねるオーバーレイファイルです:

```bash
# Traefik — 自動 HTTPS、Docker ネイティブ
docker compose -f docker-compose.yml -f compose/traefik.yml up -d

# Caddy — 最もシンプルな自動 HTTPS
docker compose -f docker-compose.yml -f compose/caddy.yml up -d

# Nginx
docker compose -f docker-compose.yml -f compose/nginx.yml up -d

# Apache (httpd)
docker compose -f docker-compose.yml -f compose/apache.yml up -d
```

続いて、シードを 1 回だけ実行します（同じ `-f` フラグを付けます）:

```bash
./scripts/first-run-seed.sh -f docker-compose.yml -f compose/traefik.yml
```

**Portainer:** [compose/portainer.stack.yml](../compose/portainer.stack.yml) を
Portainer の Web エディタにそのまま貼り付けます（自動 HTTPS の Caddy 同梱、ホスト
ファイルのマウント不要）。ファイル冒頭に設定すべき環境変数の一覧があります。

ドメイン上のパスによるルーティング: `/api` → `cms-api`、`/admin` → `admin-web`、
`/zcms-media` → メディア、その他すべて → `site-runtime`。

## 設定

すべては `.env` で制御します（`.env.example` からコピー。各変数にコメントあり）。要点:

- **シークレット** — `./scripts/generate-secrets.sh` を実行します。一部のキーは
  **データを失わずに変更できません**（`TOTP_ENCRYPTION_KEY` を変更すると登録済みの
  2FA がすべて無効化されます）。一度だけ設定し、必ずバックアップしてください。
- **公開 URL** — `DOMAIN`、`PUBLIC_SCHEME`、各 `*_URL` / `S3_PUBLIC_URL` は
  ブラウザからの到達方法と一致させる必要があります。ずれると CSP がアセットを
  ブロックします。
- **`FIRST_PARTY_PUBLIC_KEY`** — 公式イメージの署名鍵です。`.env.example` の
  デフォルト値は公式イメージと一致しているため、自分でビルド・署名しない限りは
  そのままにします。
- **マーケットプレイス** — デフォルトは空（完全オフライン。組み込みは動作します）。
  マーケットプレイスからインストールするには `MARKETPLACE_URL` を設定し、
  `MARKETPLACE_PUBLIC_KEY` をピン留めします。

詳細リファレンス: [docs/configuration.md](../docs/configuration.md)。

## 運用

| 作業 | コマンド |
| --- | --- |
| ログ表示 | `docker compose logs -f cms-api` |
| 新バージョンへ更新 | `ZCMS_VERSION` を設定し `docker compose pull && docker compose up -d` |
| DB バックアップ | `docker compose exec postgres pg_dump -U zcms zcms > backup.sql` |
| 管理者パスワード再設定 | `SEED_ADMIN_PASSWORD` を設定し `./scripts/first-run-seed.sh` |

アップグレード: [docs/upgrading.md](../docs/upgrading.md) ·
バックアップと復元: [docs/backup-restore.md](../docs/backup-restore.md) ·
本番チェックリスト: [docs/production-checklist.md](../docs/production-checklist.md) ·
アーキテクチャとセキュリティモデル: [docs/architecture.md](../docs/architecture.md)。

## よくあるトラブル

- **自分のドメインでサイトに何も表示されない** — デモシードは最初のサイトを
  `localhost` ホスト名にひも付けます。`/admin` にログインし、**Sites** で
  プライマリドメインを実際のホスト名に設定してください。
- **画像/サムネイルが読み込めない（403）** — `S3_PUBLIC_URL` がブラウザの使う
  オリジンと一致していません。`https://your-domain.com/zcms-media` にします。
- **組み込みテーマ/プラグインが読み込まれない** — `FIRST_PARTY_PUBLIC_KEY` が
  イメージの署名鍵と一致していません。公式イメージには `.env.example` の
  デフォルト値を使ってください。
- **インストール直後にログインできない** — シード
  （`./scripts/first-run-seed.sh`）を実行していないか、`NODE_ENV=production` が
  脆弱/空の `SEED_ADMIN_PASSWORD` を拒否しています。強力なパスワードを設定して
  再実行してください。

## ライセンス

MIT — [LICENSE](../LICENSE) を参照。Z-CMS © Z-SOFT Co., Ltd.

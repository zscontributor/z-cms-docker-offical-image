# Z-CMS — Docker image chính thức

[English](../README.md) | **Tiếng Việt** | [日本語](README.ja.md)

Chạy [Z-CMS](https://github.com/zscontributor/z-cms) — CMS đa tenant với engine
theme và marketplace plugin có ký số — từ các Docker image dựng sẵn. Repo này là
con đường nhanh nhất để có một instance đang chạy: image chính thức, một stack
`docker compose` đầy đủ, cấu hình reverse proxy làm sẵn (Traefik, Caddy, Nginx,
Apache, Portainer) và hướng dẫn vận hành.

- **Mã nguồn:** [github.com/zscontributor/z-cms](https://github.com/zscontributor/z-cms)
- **Image:** [`zcms`](https://hub.docker.com/u/zcms) trên Docker Hub
- **Tài liệu:** [docs.z-cms.org](https://docs.z-cms.org)

---

## Các thành phần

| Lớp | Service | Image | Cổng |
| --- | --- | --- | --- |
| Site công khai | `site-runtime` | `zcms/site-runtime` | 3000 |
| Trang quản trị | `admin-web` | `zcms/admin-web` | 3001 |
| Core API | `cms-api` | `zcms/cms-api` | 4100 |
| Job nền | `worker` | `zcms/worker` | — |
| Sandbox plugin | `plugin-runtime` | `zcms/plugin-runtime` | 4200 |
| Migrate/seed | `migrate` | `zcms/migrate` | — (chạy 1 lần) |
| CSDL | `postgres` | `postgres:17-alpine` | 5432 |
| Cache / queue | `redis` | `redis:8-alpine` | 6379 |
| Lưu trữ media | `rustfs` | `rustfs/rustfs` | 9000/9001 |

Image publish **đa kiến trúc** (`linux/amd64` + `linux/arm64`) — chạy trên cả server
x86 lẫn ARM (Apple Silicon, AWS Graviton).

## Yêu cầu

- **Docker Engine 24+** kèm plugin **Compose v2** (`docker compose version`).
- Host ~**2 vCPU / 4 GB RAM** để khởi động thoải mái.
- Để chạy public: một **tên miền** trỏ về host và mở cổng **80 + 443**.

## Bắt đầu nhanh (localhost, ~5 phút)

```bash
git clone https://github.com/zscontributor/z-cms-docker-offical-image.git zcms
cd zcms

# 1. Tạo .env với secret ngẫu nhiên mạnh
cp .env.example .env
./scripts/generate-secrets.sh --write

# 2. Khởi động stack (tự kéo image chính thức)
docker compose up -d

# 3. Tạo admin đầu tiên + site demo (chạy một lần)
./scripts/first-run-seed.sh
```

Mở thử:

- Site công khai → <http://localhost:3000>
- Quản trị → <http://localhost:3001/admin> (đăng nhập bằng `SEED_ADMIN_EMAIL` /
  `SEED_ADMIN_PASSWORD` trong `.env`)
- API docs → <http://localhost:4100/api/v1/docs>
- Email thử (Mailpit) → <http://localhost:8025>

> **Cổng `3000` / `3001`, không phải `3100` / `3101`.** Các image này chạy Z-CMS ở
> chế độ production (`next start`) nên bind cổng chuẩn `3000` (site) và `3001`
> (admin). Bản [source](https://github.com/zscontributor/z-cms) chạy dev
> (`next dev`) thì được **cố ý** remap sang `3100` / `3101` để tránh đụng các cổng
> thường đã bị chiếm trên máy dev. API (`4100`) thì giống nhau ở cả hai. Nhờ vậy
> bạn có thể chạy **đồng thời** stack dev từ source (`3100` / `3101`) **và** stack
> Docker này (`3000` / `3001`) trên cùng một máy mà không xung đột cổng.

Dừng: `docker compose down` (thêm `-v` để xoá luôn dữ liệu).

## Chạy production với tên miền + HTTPS

Trước tiên sửa `.env` sang tên miền và HTTPS:

```dotenv
DOMAIN=ten-mien.com
PUBLIC_SCHEME=https
ROOT_DOMAIN=ten-mien.com
ACME_EMAIL=ban@ten-mien.com
CMS_API_URL=https://ten-mien.com
ADMIN_WEB_URL=https://ten-mien.com
SITE_RUNTIME_URL=https://ten-mien.com
S3_PUBLIC_URL=https://ten-mien.com/zcms-media
```

Trỏ bản ghi DNS `A`/`AAAA` của tên miền về host, rồi chọn một reverse proxy — mỗi
proxy là một file overlay chồng lên `docker-compose.yml`:

```bash
# Traefik — tự động HTTPS, hợp với Docker
docker compose -f docker-compose.yml -f compose/traefik.yml up -d

# Caddy — HTTPS tự động, cấu hình đơn giản nhất
docker compose -f docker-compose.yml -f compose/caddy.yml up -d

# Nginx
docker compose -f docker-compose.yml -f compose/nginx.yml up -d

# Apache (httpd)
docker compose -f docker-compose.yml -f compose/apache.yml up -d
```

Sau đó chạy seed một lần (kèm đúng các cờ `-f`):

```bash
./scripts/first-run-seed.sh -f docker-compose.yml -f compose/traefik.yml
```

**Portainer:** dán trọn file [compose/portainer.stack.yml](../compose/portainer.stack.yml)
vào web editor của Portainer (đã kèm Caddy tự động HTTPS, không cần mount file host).
Phần đầu file liệt kê các biến môi trường cần đặt.

Định tuyến theo path trên tên miền của bạn: `/api/v1` → `cms-api`, `/admin` →
`admin-web`, `/zcms-media` → media, còn lại → `site-runtime`. Chỉ `/api/v1`, không
phải cả `/api`: `site-runtime` tự phục vụ các đường dẫn `/api` khác (ví dụ
`/api/contact/submit`, `/api/forms/<id>/submit` — nơi biểu mẫu công khai gửi dữ liệu).

## Cấu hình

Mọi thứ nằm trong `.env` (chép từ `.env.example`, có chú thích từng biến). Lưu ý:

- **Secret** — chạy `./scripts/generate-secrets.sh`. Một số key **không thể đổi mà
  không mất dữ liệu** (`TOTP_ENCRYPTION_KEY` làm mất toàn bộ 2FA đã đăng ký). Đặt một
  lần và sao lưu.
- **URL công khai** — `DOMAIN`, `PUBLIC_SCHEME`, các `*_URL` / `S3_PUBLIC_URL` phải
  khớp cách trình duyệt truy cập, nếu không CSP sẽ chặn tài nguyên.
- **`FIRST_PARTY_PUBLIC_KEY`** — key mà image chính thức được ký. Giá trị mặc định
  trong `.env.example` đã khớp image chính thức; giữ nguyên trừ khi bạn tự dựng & ký.
- **Marketplace** — mặc định để trống (chạy hoàn toàn offline, built-in vẫn hoạt
  động). Đặt `MARKETPLACE_URL` **và** ghim `MARKETPLACE_PUBLIC_KEY` để cài từ
  marketplace.

Tham khảo đầy đủ: [docs/configuration.md](../docs/configuration.md).

## Vận hành

| Việc | Lệnh |
| --- | --- |
| Xem log | `docker compose logs -f cms-api` |
| Cập nhật bản mới | đặt `ZCMS_VERSION`, rồi `docker compose pull && docker compose up -d` |
| Sao lưu CSDL | `docker compose exec postgres pg_dump -U zcms zcms > backup.sql` |
| Đặt lại mật khẩu admin | đặt `SEED_ADMIN_PASSWORD`, rồi `./scripts/first-run-seed.sh` |

Nâng cấp: [docs/upgrading.md](../docs/upgrading.md) ·
Sao lưu & phục hồi: [docs/backup-restore.md](../docs/backup-restore.md) ·
Checklist lên production: [docs/production-checklist.md](../docs/production-checklist.md) ·
Kiến trúc & mô hình bảo mật: [docs/architecture.md](../docs/architecture.md).

## Xử lý sự cố thường gặp

- **Site không hiện gì trên tên miền của bạn** — seed demo gắn site đầu tiên vào một
  hostname `localhost`. Đăng nhập `/admin` → **Sites** → đặt primary domain thành tên
  miền thật.
- **Ảnh/thumbnail không tải (403)** — `S3_PUBLIC_URL` chưa khớp origin trình duyệt
  dùng. Phải là `https://ten-mien.com/zcms-media`.
- **Built-in theme/plugin không nạp** — `FIRST_PARTY_PUBLIC_KEY` không khớp key ký
  image. Dùng giá trị mặc định trong `.env.example` với image chính thức.
- **Đăng nhập lỗi ngay sau khi cài** — chưa chạy seed
  (`./scripts/first-run-seed.sh`), hoặc `SEED_ADMIN_PASSWORD` yếu/để trống bị
  production từ chối — đặt mật khẩu mạnh rồi chạy lại.

## Giấy phép

MIT — xem [LICENSE](../LICENSE). Z-CMS © Z-SOFT Co., Ltd.

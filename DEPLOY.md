# Deploy — Render

Klaxon, Render üzerinde **PostgreSQL** ile çalışacak şekilde yapılandırılmıştır. İki yol var; **A (Blueprint)** en hızlısıdır.

> Ön koşul: Kod GitHub'a push'lanmış olmalı ve bir [Render](https://render.com) hesabınız olmalı.

## 0) RAILS_MASTER_KEY'i hazırda tutun

`config/master.key` dosyası git'e **gönderilmez** (gizli anahtar). İçeriğini kopyalayın; Render'da ortam değişkeni olarak gireceksiniz:

```bash
cat config/master.key    # 32 karakterlik değeri kopyalayın
```

## A) Blueprint ile (render.yaml)

1. Render panelinde **New + → Blueprint**.
2. Bu repoyu seçin. Render `render.yaml`'i okur: bir **web servisi** + bir **PostgreSQL** veritabanı oluşturur.
3. Sorulduğunda **`RAILS_MASTER_KEY`** değerini (0. adımdaki değer) girin. (`DATABASE_URL` otomatik bağlanır.)
4. **Apply** deyin. İlk deploy `bin/render-build.sh`'i çalıştırır: `bundle install → assets:precompile → db:migrate → db:seed`.
5. Dağıtım bitince verilen `*.onrender.com` URL'sini açın. Giriş: `responder@klaxon.test` / `password`.

## B) Elle (Blueprint kullanmadan)

1. **New + → PostgreSQL** oluşturun (free plan). Oluşan **Internal Database URL**'yi kopyalayın.
2. **New + → Web Service** → repoyu seçin. Ayarlar:
   - **Runtime:** Ruby
   - **Build Command:** `./bin/render-build.sh`
   - **Start Command:** `bundle exec puma -C config/puma.rb`
   - **Health Check Path:** `/up`
3. **Environment** sekmesinde şu değişkenleri ekleyin:
   | Key | Value |
   |---|---|
   | `DATABASE_URL` | (1. adımdaki Postgres URL) |
   | `RAILS_MASTER_KEY` | (0. adımdaki değer) |
   | `RAILS_ENV` | `production` |
   | `RAILS_SERVE_STATIC_FILES` | `true` |
   | `WEB_CONCURRENCY` | `2` |
4. **Create Web Service** → ilk deploy başlar.

## Deploy sonrası

- Canlı URL'yi **README.md** üstüne ve ödevin teslim alanına ekleyin.
- Sorun olursa Render **Logs** sekmesine bakın (genelde eksik `RAILS_MASTER_KEY` veya `DATABASE_URL`).

## Notlar

- `pg` gem'i yalnızca production grubundadır; yerelde kurulmaz (`.bundle/config` → `without production`, git'e gönderilmez). Render production grubunu kurar.
- Free PostgreSQL planı bir süre sonra uykuya geçebilir; sunum öncesi bir kez açıp uyandırın.
- Demo seed verisi (görevli kullanıcı + servisler + örnek olaylar) her deploy'da idempotent olarak yüklenir.

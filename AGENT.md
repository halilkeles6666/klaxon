# AGENT.md

Bu dosya, Klaxon üzerinde çalışan bir yapay zekâ kodlama ajanı (ör. Claude Code) ve insan geliştirici için ortak çalışma rehberidir. Projenin kurucusuyla (öğrenci) ve bir AI ajanla **birlikte** yazılmıştır; projenin mimarisini, değişmezlerini ve nasıl güvenle değiştirileceğini anlatır.

## Proje özeti

Klaxon, PagerDuty'den ilham alan bir **olay yönetimi (incident response)** uygulamasının **aort dilimidir**: alarm → olay → onaylanmazsa eskalasyon → onay → çözüm. Ürünün tamamı değil, müşterinin para ödemesinin asıl nedeni olan çekirdek akış hedeflenir.

- **Dil/çatı:** Ruby 3.4, Rails 8 (importmap, Hotwire, Propshaft).
- **Veritabanı:** SQLite (development/test/CI), PostgreSQL (production/Render).
- **Test:** Minitest + fixtures; zaman kuralları `travel_to` ile test edilir.

## Komutlar

```bash
bundle install
bin/rails db:prepare db:seed      # şema + örnek veri
bin/rails server                  # http://localhost:3000
bin/rails test                    # tüm testler
bin/rails test test/models/escalation_test.rb   # tek dosya
bin/rubocop                       # stil (omakase)
bin/brakeman --no-pager           # güvenlik taraması
```

## Mimari ve dosya haritası

| Katman | Dosya | Sorumluluk |
|---|---|---|
| Alan modeli (çekirdek) | `app/models/incident.rb` | Durum makinesi (`TRANSITIONS`, `transition_to!`), eskalasyon zaman kuralı (`escalate_at`, `apply_escalations!`), dedup (`Incident.ingest`) |
| Zaman kuralı (veri) | `app/models/escalation_policy.rb` | `ack_timeout_minutes`, `max_level` — servis başına politika |
| | `app/models/service.rb` | İzlenen servis + routing_key; politikayı taşır |
| | `app/models/alert.rb` | Tek bir alarm sinyali; çok sayıda alarm tek olaya gruplanabilir |
| | `app/models/incident_event.rb` | Olay zaman çizelgesi girdileri |
| | `app/models/user.rb` | Görevli/admin; Rails 8 `has_secure_password` |
| Public giriş | `app/controllers/alerts_controller.rb` | Alarm alma (girişsiz) — aort diliminin giriş noktası |
| Görevli paneli | `app/controllers/incidents_controller.rb`, `notes_controller.rb` | Kuyruk, detay, onayla/çöz/yeniden-aç, not |
| Kimlik doğrulama | `app/controllers/concerns/authentication.rb` | Rails 8 üretimi session tabanlı auth |

## Değişmezler (bunları bozma)

1. **Durum değişiklikleri yalnızca `Incident#transition_to!` (veya `acknowledge!`/`resolve!`/`reopen!`) üzerinden** yapılır; `TRANSITIONS` tablosuna uymayan geçişler reddedilir. `status`'u doğrudan `update` ile değiştirme.
2. **Eskalasyon yalnızca `triggered` (onaylanmamış) ve `escalation_level < max_level` iken ilerler.** `apply_escalations!` idempotenttir (her okumada güvenle çağrılabilir). Onaylama saati durdurur.
3. **Dedup açık olaylar üzerinden çalışır:** yeni alarm, aynı `(service, dedup_key)` için **çözülmemiş** bir olay varsa ona gruplanır; yoksa yeni olay açar. Mantık tek yerde: `Incident.ingest`.
4. **Zaman dilimi tek ve açık:** `config.time_zone = "Istanbul"`. Testlerde `Time.zone.local(...)` ve `travel_to` kullan. Eskalasyon süreleri **takvim (wall-clock) dakikasıdır** — olay müdahalesi 24/7'dir.

## Test yaklaşımı

- **Zaman kuralı** (`test/models/escalation_test.rb`) ve **durum geçişleri + dedup** (`test/models/incident_test.rb`) `travel_to` ile deterministik test edilir.
- Uçtan uca akış: `test/integration/aorta_slice_test.rb` (alarm al → olay → onayla → çöz; ayrıca dedup ve okuma-anında eskalasyon).
- **Kural:** yeni bir zaman/durum davranışı eklediğinde önce başarısız bir test yaz, sonra geçir. Ajanın "yaptım" demesine değil, yeşil testlere güven.

## Nasıl genişletilir (örnekler)

- **Eskalasyon süresini değiştir:** ilgili `EscalationPolicy.ack_timeout_minutes` (veri). Formül: `Incident#escalate_at`.
- **Daha fazla seviye:** `EscalationPolicy.max_level`.
- **"Düşük aciliyette eskale etme" gibi kural:** `Incident#escalatable?` metoduna koşul ekle.
- **Yeni durum:** `Incident::TRANSITIONS` tablosuna düğüm + kenar; yan etki gerekiyorsa `apply_status_side_effects`.
- **Yeni servis/politika:** `db/seeds.rb` içine ekle (veya UI eklenebilir — şu an yok).

## Dağıtım

Render üzerinde; `render.yaml` + `bin/render-build.sh`. Ayrıntı: `DEPLOY.md`. Production'da `pg` kullanılır (`DATABASE_URL`), `RAILS_MASTER_KEY` elle ayarlanır.

## AI ajanla çalışma notu

Bu repo, bir AI kodlama ajanıyla birlikte üretildi. İzlenen ilke: **ajanın ürettiği her şey çalıştırılarak doğrulandı** — testler gerçekten koşturuldu (uydurma rapor yok), sunucu ayağa kaldırılıp sayfalar gerçek HTTP ile denendi. Ajana bir özellik yaptırırken, bitişte mutlaka `bin/rails test` yeşil olmalı ve ilgili akış elle/HTTP ile bir kez görülmelidir.

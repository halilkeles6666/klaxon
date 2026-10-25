# Klaxon

> Bir olay (incident) yaşam döngüsünün **aort dilimi**: bir izleme aracı alarm gönderir → olay açılır (veya açık olaya gruplanır) → onaylanmazsa **eskalasyon zaman kuralı** devreye girer → görevli onaylar ve çözer.
> İlham kaynağı: **PagerDuty** (markanın adı/logosu bu uygulamada kullanılmaz; yalnızca burada, README'de referans olarak geçer).

> **2. hafta — otonom faza geçiş.** Klaxon artık yalnızca insan→insan bir olay yönetimi değil; **agent→agent otonom self-healing** bir kontrol düzlemi. Ayrı ve canlı bir firma sitesi ([**Nimbus**](https://github.com/halilkeles6666/nimbus)) gerçek arıza üretir; Klaxon bunu **LLM (Jev / TypeSafe System One) ile** saptar, olayı devralır, uzaktan **gerçekten düzeltir**; çözemezse o an nöbetçi olan mühendisi **Telegram'dan** uyandırır. Ayrıntılı günlük: [**CHALLENGE_LOG.md**](CHALLENGE_LOG.md) · coding-agent kuralları: [**AGENT.md**](AGENT.md). Bu faz aşağıda [Faz 3](#faz-3--otonom-ajanajan-self-healing-jev) bölümünde.

<!-- CI rozeti: repo adını 'klaxon'dan farklı yaparsan aşağıdaki yolu güncelle -->
![CI](https://github.com/halilkeles6666/klaxon/actions/workflows/ci.yml/badge.svg)

- **Canlı uygulamalar:** Klaxon (kontrol düzlemi) **https://klaxon-wgno.onrender.com** · Nimbus (izlenen firma sitesi) **https://nimbus-ijkz.onrender.com** (Render)
- **Demo giriş:** `responder@klaxon.test` / `password`
- **Teknoloji:** Ruby 3.4 · Rails 8 · SQLite (dev/test) · PostgreSQL (production) · Minitest · **TypeSafe Jev (System One) · ActiveJob (:async)**

---

## İçindekiler
1. [Faz 1 — Fortune 500 araştırması](#faz-1--fortune-500-araştırması-kaynaklı)
2. [SaaS seçimi ve Fortune 500 kanıtı](#saas-seçimi-ve-fortune-500-kanıtı)
3. [Faz 2 — Maliyet tahmini](#faz-2--maliyet-tahmini)
4. [Aort dilimi](#aort-dilimi-uçtan-uca-çalışan-ana-iş-akışı)
5. [100 puan: çözülen kullanıcı acısı](#100-puan--çözülen-kullanıcı-acısı)
6. [Faz 3 — Otonom ajan→ajan self-healing (Jev)](#faz-3--otonom-ajanajan-self-healing-jev)
7. [Zaman kuralı ve durum geçişi — kod nerede](#zaman-kuralı-ve-durum-geçişi--kod-nerede)
8. [Kurulum, test ve çalıştırma](#kurulum-test-ve-çalıştırma)
9. [Yapamadıklarım](#yapamadıklarım)

---

## Faz 1 — Fortune 500 araştırması (kaynaklı)

> Not: Fortune 500 listesi **piyasa değerine değil, yıllık gelire** göre sıralanır. Her rakamın yanında kaynağı vardır.

| Soru | Değer (yaklaşık / aralık) | Kaynak |
|---|---|---|
| **a. Değerleme / büyüklük aralığı** | Gelire göre: en büyük **Walmart ≈ 681 milyar $**, listeye giriş eşiği (#500) **≈ 7,4 milyar $**. Medyan gelir ≈ 16,6 milyar $. Grubun **toplam piyasa değeri ≈ 46 trilyon $**. | [Fortune 2025 duyurusu][f1], [AOL — en büyük 10][f2], [eqvista — medyan][f3] |
| **b. Çalışan sayısı aralığı** | 500 firma **toplam ≈ 31 milyon** çalışan; tek tek firmalar ~7 binden en büyük işveren **Walmart ≈ 2,1 milyon**'a kadar. | [Fortune 2025 duyurusu][f1] |
| **c. Bir firmanın kullandığı SaaS ürünü sayısı** | Büyük kurumlar (10.000+ çalışan) ortalama **~473 SaaS uygulaması**; 2.000+ çalışanlı firmalar **~231**, genel ortalama **~101** (metodolojiye göre değişir). | [CloudNuro / Zylo derlemesi][s1], [Torii][s2] |
| **d. SaaS aboneliklerine yıllık ödenen para** | Ortalama kurum **yılda ≈ 52 milyon $** (2024'te ≈ 45 milyon $); yazılım bütçesinin ~%70'i. | [CloudNuro derlemesi][s1], [Statista anketi][s3] |

> Rakamların çoğu satıcı/ikincil derlemelerdir ve metodolojiye göre değişir; birincil raporlar (Zylo SaaS Management Index, Okta *Businesses at Work*, Statista) daha kesin veri için işaret edilmiştir.

[f1]: https://fortunemedia.mediaroom.com/2025-06-02-Fortune-Announces-2025-Fortune-500-List
[f2]: https://www.aol.com/10-largest-us-companies-revenue-140205973.html
[f3]: https://eqvista.com/fortune-500-companies-in-the-us/
[s1]: https://www.cloudnuro.ai/blog/saas-statistics
[s2]: https://www.toriihq.com/articles/saas-statistics
[s3]: https://www.statista.com/statistics/1472733/organizations-saas-annual-spend-globally

---

## SaaS seçimi ve Fortune 500 kanıtı

**Seçilen ürün: PagerDuty** (olay yönetimi / on-call & incident response platformu).

Ödevin kriterlerini neden karşılıyor:

- **Fortune 500 firmalarının para ödediği kanıtı (birincil kaynak):** PagerDuty'nin SEC'e verdiği **FY2025 10-K** raporunda, müşterileri arasında **Fortune 500'ün yaklaşık yarısı ve Fortune 100'ün yaklaşık üçte ikisi** olduğu, toplam **15.114 ödeyen müşteri** bulunduğu belirtilir ([SEC 10-K FY2025][pd-10k25]). Daha eski **FY2020 10-K** da "Fortune 500'ün üçte birinden fazlası" ifadesini kullanır ([SEC 10-K FY2020][pd-10k20]). Yani tek bir firma değil, **yüzlerce** Fortune 500 firması bu ürüne para ödüyor.
- **İsimli örnekler:** PagerDuty'nin kendi tanıtım metninde müşteriler arasında **GE, Cisco, Netflix, Electronic Arts, Shopify, Lululemon** gibi (çoğu Fortune 500) şirketler sayılır (ikincil, PagerDuty metninin yeniden yayını) ([reprint][pd-boiler]). Ayrıca PagerDuty'nin kendi vaka çalışması sayfaları vardır (ör. perakendeci [John Lewis][pd-jl]).
- **Ölçek (~300k+ satır, gerçek kurumsal ürün):** PagerDuty 2009'dan beri geliştirilen, 2019'da halka açılmış, **FY2024 geliri ≈ 431 milyon $** olan ([SEC 10-K/A FY2024][pd-10k24]) çok ürünlü bir platformdur (alarm yönetimi, on-call çizelgeleme, eskalasyon, Event Intelligence/AIOps, otomasyon, analitik, mobil uygulamalar, 700+ entegrasyon) — oyuncak değil (bkz. Faz 2).
- **Bol gerçek kullanıcı yorumu:** G2 ve Capterra'da binlerce yorum — acı madenciliği için zengin kaynak (bkz. 100 puan bölümü).

[pd-10k25]: https://www.sec.gov/Archives/edgar/data/1568100/000156810025000023/pd-20250131.htm
[pd-10k24]: https://www.sec.gov/Archives/edgar/data/1568100/000156810024000021/pd-20240131.htm
[pd-10k20]: https://www.sec.gov/Archives/edgar/data/1568100/000156810020000013/pagerdutyq42020-10k.htm
[pd-boiler]: https://jobs.institutedata.com/company/134281/pagerduty/
[pd-jl]: https://www.pagerduty.com/customer/john-lewis/

---

## Faz 2 — Maliyet tahmini

### PagerDuty'nin yaklaşık satır sayısı ve tahmin yöntemi

PagerDuty kapalı kaynaktır; satır sayısı **dolaylı olarak** tahmin edildi:

- **Yöntem:** (1) ürün yaşı (2009'dan beri, 15+ yıl), (2) mühendis sayısı (halka açık şirket, yüzlerce mühendis), (3) özellik yüzeyi (olay yönetimi, on-call çizelgeleme, çok seviyeli eskalasyon, Event Intelligence/AIOps gürültü azaltma, otomasyon/runbook, analitik, mobil uygulamalar, 700+ entegrasyon, API), (4) kıyas: açık kaynak on-call/alerting araçları (ör. Grafana OnCall, Cabot) tek başına on binlerce satırdır; çok ürünlü bir SaaS bunların kat kat üstündedir.
- **Tahmin:** Yalnızca **olay+eskalasyon çekirdeği birkaç yüz bin satır**; tüm platform (AIOps, otomasyon, analitik, mobil, entegrasyonlar) rahatlıkla **1 milyon satırın üzerinde**. Ödevin "~300.000 satırlık gerçek kurumsal ürün" ölçeğini fazlasıyla karşılar.

### Çekirdeği bugünün coding agent'ları ile üretmek

|  | Tahmin | Gerçekleşen |
|---|---|---|
| **Kapsam** | Yalnızca aort dilimi (alarm→olay→eskalasyon→çözüm), tüm ürün değil | Aynı — aort dilimi uçtan uca |
| **Süre** | Tek geliştirici + AI ajan ile **2–4 gün** | **~1 yoğun oturum** (bu repo, tek ajan ile) |
| **Para (token/abonelik)** | Coding agent aboneliği (~20–100 $/ay) içinde; saf token maliyeti kabaca **birkaç ila ~30 $** | Mevcut Claude Code aboneliği kapsamında; ek saf token maliyeti düşük (tek haneli–~onlarca $ mertebesinde) |

> Dürüst not: Tam platformu (AIOps, otomasyon, analitik…) klonlamak bu bütçenin çok ötesindedir; ucuzlayan şey **çekirdek iş akışının** bir kopyasını çıkarmaktır — ödevin tezi de budur.

---

## Aort dilimi (uçtan uca çalışan ana iş akışı)

Müşterinin bu ürüne para ödemesinin asıl nedeni: **bir sistem arızası olduğunda doğru kişinin zamanında haberdar olup müdahale etmesi.** Klonlanan dilim:

1. **İzleme aracı alarm gönderir** (girişsiz, public uç nokta): `/alerts/new`. Bu bir Datadog/Prometheus/health-check'i taklit eder.
2. Alarm bir **olay (incident)** açar — ya da aynı servis/dedup anahtarı için **açık bir olay varsa ona gruplanır** (gürültü azaltma; 100 puan).
3. Olay **triggered** (tetiklendi) durumunda görevli kuyruğuna düşer, aciliyet + eskalasyon seviyesiyle.
4. Olay **onaylanmazsa**, servisin politikasındaki süre (ör. 5 dk) dolunca **otomatik bir üst seviyeye yükselir** (eskalasyon zaman kuralı), azami seviyeye kadar.
5. **Görevli giriş yapar**, olayı **onaylar** (eskalasyon durur) ve **çözer**.
6. Her adım olayın **zaman çizelgesine** işlenir.

**İki zorunlu öğe:**
- **Zaman kuralı:** Eskalasyon zaman aşımı — `app/models/incident.rb` (`escalate_at`, `apply_escalations!`) + `app/models/escalation_policy.rb` (`ack_timeout_minutes`).
- **Durum akışı:** `app/models/incident.rb` içindeki `TRANSITIONS` durum makinesi (`triggered → acknowledged → resolved`, + yeniden açma).

---

## 100 puan — çözülen kullanıcı acısı

**Kimin acısı, hangi yorumdan, çözümümüz ne — tek cümleyle:**
> PagerDuty kullanıcıları, düşük paketlerde **yerleşik gürültü azaltma olmamasından** ve olay anında **alarm bombardımanından** (alert fatigue) şikâyet ediyor; Klaxon, aynı servis/anahtardan gelen **yinelenen alarmları yeni olay açıp tekrar çağrı göndermek yerine açık olaya gruplar**, böylece gürültüyü kaynağında azaltır.

Kaynaklar (gerçek kullanıcı geri bildirimi):
- G2 — PagerDuty'nin yaygın dezavantajları özetinde **"alert overload"** ve **düşük paketlerde yerleşik gürültü azaltma eksikliği** nedeniyle on-call ekiplerinde yorgunluk/moral kaybı belirtiliyor: [g2.com/products/pagerduty/reviews][pd-g2]
- G2 yorumu — AI olmasına rağmen dağınık izleme girdilerinin kişileri bildirime boğabildiği: [g2.com][pd-g2]
- Capterra — çizelge/alarm esnekliği ve gürültü ile ilgili şikâyetler: [capterra.com/p/125693/PagerDuty/reviews][pd-cap]

**Çözümümüz nasıl çalışıyor:** `Incident.ingest` bir alarm geldiğinde, o servis için **açık** (çözülmemiş) ve aynı `dedup_key`'e sahip bir olay var mı diye bakar. Varsa yeni olay/çağrı üretmez; alarmı o olaya **bastırılmış (deduplicated)** olarak ekler ve zaman çizelgesine not düşer. Olay detayında "N yinelenen alarm bastırıldı" rozeti görünür. Demo: aynı alarmı 2+ kez gönder → tek olay, artan alarm sayacı (bkz. `test/models/incident_test.rb` ve `test/integration/aorta_slice_test.rb`).

[pd-g2]: https://www.g2.com/products/pagerduty/reviews
[pd-cap]: https://www.capterra.com/p/125693/PagerDuty/reviews/

---

## Faz 3 — Otonom ajan→ajan self-healing (Jev)

1. haftada akış **insan→insan**'dı: alarm → olay → eskalasyon → **görevli insan** onaylar ve çözer. 2. haftada vaat **agent→agent otonom self-healing**: arızayı bir ajan saptasın, devralsın, **gerçekten çözsün**; çözemezse insanı çağırsın. Tam günlük, kanıt ve commit bağlantıları: [**CHALLENGE_LOG.md**](CHALLENGE_LOG.md).

### Mimari — iki ayrı canlı sistem

```
   Nimbus (ayrı firma sitesi)                 Klaxon (otonom kontrol düzlemi)
 ┌──────────────────────────┐   telemetri   ┌─────────────────────────────────┐
 │ mağaza + /panel arıza     │ ───POST────▶  │ 1) LLM ile ANOMALİ tespiti (Jev)│
 │ enjeksiyonu; sayfalar      │ /api/telemetry│ 2) LLM ile DEDUP / gruplama(Jev)│
 │ gerçekten 500/503 döner    │               │ 3) olay açılır → arka plan job  │
 │                            │  ◀──POST────  │ 4) LLM ile AKSİYON kararı (Jev) │
 │ POST /heal → gerçekten      │   /heal       │ 5) çözemezse → nöbetçi + Telegram│
 │ düzelir (checkout 200)      │               │    (HITL eskalasyon)            │
 └──────────────────────────┘               └─────────────────────────────────┘
```

- **Nimbus** ([ayrı repo](https://github.com/halilkeles6666/nimbus), ayrı deploy): gezilebilir bir mağaza. `/panel`'den bir bileşene arıza enjekte edilince sayfalar **gerçekten 500/503** döner; Nimbus kendini izleyip Klaxon'a **telemetri** push eder ve `POST /heal` ile uzaktan onarılır.
- **Klaxon**: gelen telemetriyi işler, olayı açar ve **ajan** devralır. Üç kararın üçü de LLM (Jev); eşik/anahtar-kelime yalnızca **güvenlik ağı (fallback)**.

### Her kararda LLM (Jev / TypeSafe System One)

| Karar | LLM yolu | Fallback | Kod |
|---|---|---|---|
| **Anomali tespiti** | `LlmAnomalyDetector` — Jev `noul` olasılığı (eşik 0.6) | `ThresholdDetector` | [`app/services/anomaly_detector.rb`](app/services/anomaly_detector.rb), [`llm_anomaly_detector.rb`](app/services/llm_anomaly_detector.rb) |
| **Dedup / gruplama** | `JevDeduper` — Jev `choice` (açık olaylar + "none", taban 0.5) | `KeyDeduper` | [`app/services/deduper.rb`](app/services/deduper.rb), [`jev_deduper.rb`](app/services/jev_deduper.rb) |
| **Aksiyon / çözüm** | `ResolutionAgent#assess` — Jev severity + auto_ok + action | — | [`app/services/resolution_agent.rb`](app/services/resolution_agent.rb) |
| HTTP istemci | typed System One çağrısı (Bearer) | — | [`app/services/jev_client.rb`](app/services/jev_client.rb), [`stub_jev_client.rb`](app/services/stub_jev_client.rb) (test) |

> **"Anahtar kelime yerine LLM":** hoca özellikle **dedup anahtarını** kastetti — eski `dedup_key` tam-eşleşmesi yerine artık Jev benzer olayları değerlendirip gruplar.

### Kapalı döngü, asenkron çözüm ve HITL

- **Gerçek kapalı döngü** (enjekte→sapta→uygula→**ölç**): ajan bir aksiyon dener, dünyadan **ölçülen sağlık** geri bildirimi alır; yanlış aksiyon arızayı **gerçekten** bırakmaz, doğru aksiyon iyileştirir. Cevap anahtarı yok. — [`simulated_world.rb`](app/services/simulated_world.rb), [`store_world.rb`](app/services/store_world.rb), [`remote_store_world.rb`](app/services/remote_store_world.rb)
- **Asenkron çözüm**: telemetri olayı açar ve `ResolveIncidentJob` kuyruğa alınır (ActiveJob `:async`); ingest cevabı bloklanmaz. — [`app/jobs/resolve_incident_job.rb`](app/jobs/resolve_incident_job.rb)
- **HITL (human-in-the-loop) eskalasyon**: ajan çözemezse o an nöbetçi olan mühendise **Telegram'dan** alarm basılır. — [`app/services/on_call.rb`](app/services/on_call.rb), [`telegram_notifier.rb`](app/services/telegram_notifier.rb)
- **Public ingest uçları**: [`app/controllers/api/telemetry_controller.rb`](app/controllers/api/telemetry_controller.rb), [`alerts_controller.rb`](app/controllers/api/alerts_controller.rb)

### Canlı demo (uçtan uca, gerçekten koşturuldu)

1. https://nimbus-ijkz.onrender.com/panel → bir bileşene arıza ver (ör. ödeme = `bad_deploy`).
2. Site **gerçekten** bozulur (checkout 500).
3. Nimbus telemetriyi Klaxon'a push eder → Klaxon **Jev ile anomaliyi saptar** → olay açar → **arka planda** ajan Jev'e aksiyonu sorar → Nimbus `/heal`'i çağırır.
4. ~10 sn içinde site **gerçekten düzelir** (checkout 200).
5. Ajan çözemezse → nöbetçi mühendise **Telegram'dan** "🚨 ALERT ALERT". Doğrulandı: ödeme=`bad_deploy` → Jev `rollback_deploy` seçti → Nimbus iyileşti.

> **Slop testi (benimkinde olup çoğununkinde olmayan):** *ayrı ve canlı bir siteyi uzaktan izleyip, LLM ile anomaliyi saptayan, kararı o sitenin API'sine komut göndererek uygulayan ve çözemeyince gerçek bir nöbetçiye Telegram'dan alarm basan uçtan uca otonom (agent→agent) self-healing döngüsü.*

**Güvenlik notu:** API anahtarları (TypeSafe, Telegram, Nimbus) repoya **hiç girmez** — yalnızca gitignore'lu `config/*.key` dosyalarında ve Render ortam değişkenlerinde tutulur.

---

## Zaman kuralı ve durum geçişi — kod nerede

| Konu | Dosya | Açıklama |
|---|---|---|
| **Zaman kuralı (eskalasyon)** | [`app/models/incident.rb`](app/models/incident.rb) | `escalate_at`, `minutes_until_escalation`, `apply_escalations!` — onaylanmayan olay her `ack_timeout_minutes`'te bir üst seviyeye yükselir. |
| Eskalasyon süresi (veri) | [`app/models/escalation_policy.rb`](app/models/escalation_policy.rb) | `ack_timeout_minutes`, `max_level` — servis başına politika. |
| **Durum geçişi** | [`app/models/incident.rb`](app/models/incident.rb) | `TRANSITIONS` tablosu + `transition_to!` / `acknowledge!` / `resolve!` / `reopen!` |
| Dedup (gürültü azaltma) | [`app/models/incident.rb`](app/models/incident.rb) | `Incident.ingest` |
| Testler (travel_to) | [`test/models/escalation_test.rb`](test/models/escalation_test.rb), [`test/models/incident_test.rb`](test/models/incident_test.rb) | Eskalasyon zamanlaması, onayla-durdur, geçiş kuralları, dedup |

> **Sunum 5. soru örneği** (bir kural değişikliği): "Eskalasyon 5 değil 10 dakikada olsun" → veri düzeyinde ilgili **EscalationPolicy**'nin `ack_timeout_minutes` değeri (UI yok, seed/console veya DB). Formülün kendisi `app/models/incident.rb` → `escalate_at`. "Düşük aciliyette hiç eskale etme" gibi bir kural da `escalatable?` metoduna tek koşul eklenerek yapılır.

---

## Kurulum, test ve çalıştırma

```bash
bundle install
bin/rails db:prepare db:seed
bin/rails server            # http://localhost:3000
bin/rails test              # tüm testler (model + entegrasyon)
```

- Dev/test: SQLite (kurulum gerektirmez). Production: PostgreSQL (`DATABASE_URL`).
- CI: GitHub Actions (`.github/workflows/ci.yml`) — brakeman, importmap audit, rubocop ve `bin/rails test`.
- Deploy: [DEPLOY.md](DEPLOY.md) (Render).

Hızlı demo akışı: `/alerts/new`'den bir alarm gönder → aynı alarmı tekrar gönder (gruplanır) → `responder@klaxon.test` ile giriş yap → olayı onayla ve çöz.

---

## Yapamadıklarım

Dürüstlük bölümü — bunlar **bilerek kapsam dışı** bırakıldı (gizli eksik değil).

> Not: Faz 3 ile 1. haftanın bazı eksikleri **kapandı** — artık **arka plan job'u var** (`ResolveIncidentJob`, ActiveJob `:async`), **gerçek bildirim var** (Telegram ile nöbetçiyi uyandırma), **nöbet/on-call ataması var** (`OnCall`) ve dedup artık **LLM ile akıllı gruplama** yapıyor (tam-eşleşen `dedup_key` değil). Aşağıda kalan gerçek sınırlar listeleniyor.

- **Kalıcı kuyruk altyapısı yok.** Asenkron çözüm ActiveJob `:async` ile, yani **süreç-içi thread havuzu**; Sidekiq/SolidQueue gibi kalıcı/dayanıklı bir kuyruk değil — süreç ölürse kuyruk uçar.
- **Eskalasyon hâlâ okuma anında tembel (lazy).** Zaman tabanlı eskalasyon (`apply_escalations!`) kuyruk/olay sayfası açıldığında çalışır; bunu zamanlanmış bir job sürmez. (Çözüm tarafı asenkron, eskalasyon tarafı değil.)
- **Nimbus arıza durumu bellekte.** Render yeniden başlayınca sıfırlanır; kalıcı değil.
- **Ingest uçlarında kimlik doğrulaması yok** (`/api/telemetry`, `/alerts/new` public). Telemetri her bileşen için LLM'e çağrı yapar (maliyet kuruşlar, ama kimlik doğrulaması olmadığı için üretimde açık uç).
- **RAG/embedding yok.** Benzerlik ve kök-neden için embedding/RAG yerine doğrudan Jev kararı kullanıldı.
- **Gerçek Jev ağı test edilmiyor.** Testler `StubJevClient` ile offline koşar (deterministik); canlı Jev yalnızca elle doğrulandı.
- **Çalışma takvimi/sessiz saat yok.** Olay müdahalesi 24/7 varsayılır; eskalasyon mesai/hafta sonu ayrımı yapmaz.
- **Yetkilendirme sade:** giriş yapan herkes görevli; rol bazlı yetki (admin-only ekran) uygulanmadı.
- **Sayfalama yok**; olay listesi büyürse tek sayfada gelir.
- **Demo seed parolaları zayıf** (`password`) — yalnızca demo/sunum içindir.
- **Sistem (tarayıcı) testleri yok**; kapsam model + servis + HTTP entegrasyon testleriyle doğrulandı (77 run / 301 assertion).

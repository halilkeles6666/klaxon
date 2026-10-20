# CHALLENGE_LOG

## Başlangıç noktası

- **Klonlanan ürün:** PagerDuty (olay yönetimi / on-call & incident response).
- **Canlı URL'ler:**
  - Klaxon (kontrol düzlemi / olay yönetimi): https://klaxon-wgno.onrender.com
  - Nimbus (ayrı canlı firma sitesi): https://nimbus-ijkz.onrender.com
- **Geçen haftanın son commit'i:** [`50b4e20` — README: add live Render URL](https://github.com/halilkeles6666/klaxon/commit/50b4e20)
- **Bu ürüne kim, neden para ödüyor?** On-call yapan yazılım/SRE/DevOps ekipleri.
  PagerDuty'nin SEC'e verdiği FY2025 10-K'sına göre müşterileri arasında Fortune
  500'ün ~yarısı, Fortune 100'ün ~2/3'ü var; FY2024 geliri ~431 milyon $. Ödeme
  sebebi: üretim sistemi çöktüğünde **doğru kişinin saniyeler içinde haberdar
  olması** — kesintinin her dakikası binlerce dolar.

## Acı

- **Alarm yorgunluğu (alert fatigue).** Aynı arızadan gelen tekrar alarmlar
  telefonu durmadan çaldırıyor; düşük paketlerde yerleşik gürültü azaltma yok.
- **Kaynaklar:**
  - Spike.sh 2026 incelemesi: PagerDuty'nin ML gürültü azaltması (AIOps) ayda
    **799 $'lık ayrı eklenti** — https://spike.sh/blog/pagerduty-review-for-alerting-2026/
  - G2 "Cons": https://www.g2.com/products/pagerduty/reviews
  - Capterra: https://www.capterra.com/p/125693/PagerDuty/reviews/

## Bu haftanın vaadi

Geçen hafta **insan→insan** bir olay yönetimi (alarm→olay→eskalasyon→insan onayı)
getirmiştim. Bu hafta vaadim **agent→agent otonom self-healing**:

> "Ayrı ve canlı bir firma sitesi gerçek hata üretsin; agent bunu **LLM ile**
> saptayıp devralsın, **gerçekten düzeltsin**; çözemezse o an nöbetçi olan
> mühendisi **Telegram'dan** uyandırsın. Anahtar-kelime yerine her kararda LLM
> (Jev / TypeSafe System One) kullan."

## Yapılanlar ve kanıt

**Ayrı canlı firma sitesi — Nimbus** (kendi repo'su, ayrı deploy):
https://github.com/halilkeles6666/nimbus — gezilebilir mağaza; bir bileşene arıza
enjekte edilince sayfalar **gerçekten 500/503** döner; kendi kendini izleyip
Klaxon'a **telemetri** push eder; `POST /heal` ile Klaxon tarafından düzeltilir.

**Klaxon — otonom ajan + LLM her katmanda** (branch `autonomous-agent`):
- Agent→agent + HITL: [`404213c`](https://github.com/halilkeles6666/klaxon/commit/404213c), nöbetçi + Telegram [`315a7b4`](https://github.com/halilkeles6666/klaxon/commit/315a7b4)
- **LLM ile dedup** (anahtar kelime değil): [`e1ac71f`](https://github.com/halilkeles6666/klaxon/commit/e1ac71f)
- **LLM ile anomali tespiti** (eşik değil): [`f32a375`](https://github.com/halilkeles6666/klaxon/commit/f32a375)
- Gerçek kapalı-döngü (enjekte→sapta→uygula→ölç): [`2d48757`](https://github.com/halilkeles6666/klaxon/commit/2d48757)
- Ayrı canlı siteyi uzaktan /heal ile onarma: [`1903bae`](https://github.com/halilkeles6666/klaxon/commit/1903bae)
- Canlı yolda LLM tespit + telemetri + **asenkron** çözüm: [`e8c2ca2`](https://github.com/halilkeles6666/klaxon/commit/e8c2ca2)

**Üç karar da LLM (Jev):** tespit (anomali) · gruplama (dedup) · çözüm (aksiyon).
Eşik ve anahtar-kelime yalnızca **güvenlik ağı/fallback**.

**Testler:** 77 run / 301 assertion yeşil (`ruby bin/rails test`); rubocop temiz;
brakeman 0. StubJevClient ile offline — gerçek Jev ağı test etmiyor.

**Canlı demo adımları:**
1. https://nimbus-ijkz.onrender.com/panel → bir bileşene arıza ver (ör. ödeme = bad_deploy).
2. Site gerçekten bozulur (checkout 500).
3. Nimbus telemetriyi Klaxon'a push eder → Klaxon **Jev ile anomaliyi saptar** →
   olay açar → **arka planda** ajan Jev'e aksiyonu sorar → Nimbus `/heal`'i çağırır.
4. ~10 sn içinde site **gerçekten düzelir** (checkout 200).
5. Çözemezse: o an nöbetçi olan mühendise **Telegram'dan "🚨 ALERT ALERT"**.
   → Canlı olarak koşturuldu ve doğrulandı (ödeme=bad_deploy → rollback_deploy → düzeldi).

**Slop testi — benimkinde olup çoğununkinde olmayan:** *Ayrı ve canlı bir siteyi
uzaktan izleyip, LLM ile anomaliyi saptayan, kararı o sitenin API'sine komut
göndererek uygulayan ve çözemeyince gerçek bir nöbetçiye Telegram'dan alarm basan
uçtan uca otonom (agent→agent) self-healing döngüsü.*

**Vaat edip yapamadıklarım (dürüstçe):**
- **RAG eklemedim** — dedup/benzerlik için embedding/RAG yerine Jev'in doğrudan
  kararını kullandım (hedefim kişisel göreve odaklanmaktı).
- **Gerçek arka plan altyapısı yok** — asenkron çözüm ActiveJob `:async` (süreç-içi
  thread havuzu); kalıcı kuyruk (Sidekiq/SolidQueue) yok.
- **Nimbus arıza durumu bellekte** — Render yeniden başlayınca sıfırlanır.
- **Ingest ucu kimlik doğrulaması yok** (`/api/telemetry` public). Telemetri LLM'e
  her bileşen için çağrı yapar (maliyet kuruşlar ama sabit).

## Zaman

- **İnsan zamanı:** yönlendirme + kararlar (devam/pivot, mimari seçimler) + Render
  deploy + env/secret girişi + canlı test — birkaç saat, dağınık oturumlar.
- **Agent zamanı:** tüm kodlama, test, hata ayıklama ve commit'ler — tek uzun
  oturumda onlarca tur (Claude Code). İş hacminin büyük kısmı agent, yön ve
  kararlar insan.
- **İlk prompt'um (olduğu gibi):**
  > "projeyi geliştirmemiz lazım şuan sistem insan -> insan bunun yerine bir
  > simülasyon yapıcaz ve bu simülasyonda çıkan sorunları agent çözecek sistem
  > agent-> agent olacak ve jev system 1 entegrasyonu istedi şu linktekini
  > https://typesafe.ai/blog/introducing-system-one-models-and-jev"

## Karar

**Devam et ve üzerine ekle.**

**Gerekçe ("bundan bir iş çıkar mı?"):** Evet. İnsan-ticket'lı destek klonları
birbirinin aynısı (slop). Ama **otonom olay çözümü / self-healing** gerçek ve
büyüyen bir kategori — PagerDuty AIOps, incident.io bunu satıyor; web trafiğinin
giderek artan kısmı agent. Benim eklediğim fark: **ayrı canlı bir sistemi LLM ile
izleyip uzaktan onaran, çözemeyince insanı çağıran** uçtan uca otonom döngü.
Bu, "bir agent'ın bakım yaptığı sistem" vizyonunun çalışan, canlı bir prototipi;
üzerine eklenebilir (çok servisli, RAG'li kök-neden, gerçek runbook aksiyonları).
Öldürmek için sebep yok; pivot gerekmez — yön zaten agent→agent'a kaydı.

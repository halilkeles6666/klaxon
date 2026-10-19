# Agent 1 in the agent->agent loop: a synthetic monitoring source.
#
# It fabricates realistic incidents across several services. Each scenario
# carries a hidden `root_cause_action` (the remediation that actually fixes
# it) which the ResolutionAgent must infer from the free-text description.
# Wording is varied so the agent has to reason, not pattern-match.
class IncidentSimulator
  SCENARIOS = [
    {
      service: "payments-api", urgency: "high", root_cause: "rollback_deploy",
      titles: [
        "Ödeme API'sinde 5xx oranı fırladı",
        "Checkout 500 hataları artıyor",
        "Ödeme servisi hata patlaması"
      ],
      summaries: [
        "/charge üzerinde hata oranı 14:02 dağıtımından hemen sonra %18'e çıktı; gecikme normal.",
        "Son sürümden sonra ödeme uçları %22 oranında 500 dönüyor; bir önceki sürümde sorun yoktu.",
        "Yeni deploy sonrası NullPointer kaynaklı 5xx; trafik ve kaynak kullanımı normal."
      ]
    },
    {
      service: "web-frontend", urgency: "high", root_cause: "scale_up",
      titles: [
        "Web ön yüzünde yüksek gecikme",
        "Site yavaşladı, p95 tırmanıyor",
        "Ön yüz yanıt süreleri kötüleşti"
      ],
      summaries: [
        "Kampanya trafiğiyle istek sayısı 3 katına çıktı; p95 2.4s, CPU %95, hata yok.",
        "Ani ziyaretçi artışı sonrası tüm sunucular doygun; kuyruk birikiyor ama kod değişmedi.",
        "Yük testi gibi trafik; mevcut instance'lar yetmiyor, otomatik ölçekleme kapalı."
      ]
    },
    {
      service: "auth-service", urgency: "high", root_cause: "restart_service",
      titles: [
        "Kimlik servisi yanıt vermiyor",
        "Auth süreci takıldı",
        "Oturum açma zaman aşımına uğruyor"
      ],
      summaries: [
        "Bellek kullanımı saatlerdir doğrusal artıyor (sızıntı), süreç yanıt vermez oldu; dağıtım yok.",
        "Auth süreci deadlock'a girmiş görünüyor; thread havuzu dolu, trafik normal.",
        "Servis zombi durumda; yeniden başlatma dışında kaynak/kod değişikliği gerekmiyor."
      ]
    },
    {
      service: "email-batch", urgency: "low", root_cause: "clear_queue",
      titles: [
        "E-posta kuyruğu birikti",
        "Toplu e-posta gecikmesi",
        "Bildirim kuyruğu tıkandı"
      ],
      summaries: [
        "Kuyrukta 48 bin mesaj birikti; tek bir hatalı mesaj işçiyi tıkamış, disk %97 dolu.",
        "Zehirli mesaj (poison message) kuyruğu durdurmuş; temizlenince akış düzelecek.",
        "Birikmiş kuyruk nedeniyle teslimat gecikiyor; kod ve kaynak sağlıklı."
      ]
    },
    {
      service: "orders-db", urgency: "high", root_cause: "failover",
      titles: [
        "Sipariş veritabanı birincil düğümü düştü",
        "Orders DB bağlantıları kopuyor",
        "Birincil veritabanı erişilemez"
      ],
      summaries: [
        "Birincil DB düğümü donanım arızasıyla düştü; replika sağlıklı ve güncel.",
        "Primary'ye bağlantılar reddediliyor; hazırda bekleyen replica promote edilmeyi bekliyor.",
        "Birincil bölge erişilemez durumda; ikincil bölge çalışır vaziyette."
      ]
    },
    {
      service: "search-api", urgency: "high", root_cause: "scale_up",
      titles: [
        "Arama API'si yavaşladı",
        "Arama sorguları zaman aşımına uğruyor",
        "Arama gecikmesi tırmanıyor"
      ],
      summaries: [
        "Yeniden indeksleme yükü altında sorgu gecikmesi p95 3.1s'ye çıktı; düğümler doygun, hata yok.",
        "Trafik 2 katına çıkınca arama kümesi yetmedi; CPU %92, kod değişmedi.",
        "Yük artışıyla eşzamanlı sorgular birikti; daha fazla kapasite gerekiyor."
      ]
    },
    {
      service: "billing-worker", urgency: "low", root_cause: "clear_queue",
      titles: [
        "Faturalama işçisi takıldı",
        "Fatura işleri kuyruğu birikti",
        "Ödeme mutabakatı gecikiyor"
      ],
      summaries: [
        "Zehirli bir iş kuyruğu durdurdu; 9 bin fatura işi bekliyor, işçi ilerlemiyor.",
        "Kuyrukta hatalı bir mesaj işçiyi tıkadı; temizlenince akış düzelir.",
        "Birikmiş iş kuyruğu yüzünden faturalar gecikiyor; kaynak ve kod sağlıklı."
      ]
    },
    {
      service: "cdn-edge", urgency: "high", root_cause: "rollback_deploy",
      titles: [
        "CDN kenarında köken hataları",
        "Statik içerik 5xx dönüyor",
        "Edge yapılandırması sonrası hatalar"
      ],
      summaries: [
        "Yeni edge yapılandırması yayınlandıktan sonra %20 köken hatası; önceki yapılandırmada sorun yoktu.",
        "Son config push sonrası önbellek kuralları bozuldu; geri almak düzeltir.",
        "Edge dağıtımı hatalı; trafik ve kaynak normal, sorun yeni sürümde."
      ]
    },
    {
      service: "inventory-db", urgency: "high", root_cause: "failover",
      titles: [
        "Envanter veritabanı birincil düğümü düştü",
        "Inventory DB erişilemez",
        "Stok veritabanı bağlantıları kopuyor"
      ],
      summaries: [
        "Birincil envanter DB düğümü çöktü; sağlıklı replika promote edilmeyi bekliyor.",
        "Primary erişilemez, bağlantılar reddediliyor; ikincil düğüm güncel.",
        "Birincil düğüm donanım hatası verdi; replikaya geçiş gerekiyor."
      ]
    },
    {
      service: "notification-svc", urgency: "low", root_cause: "restart_service",
      titles: [
        "Bildirim servisi yanıt vermiyor",
        "Push bildirim süreci takıldı",
        "Bildirim gönderimi durdu"
      ],
      summaries: [
        "Bildirim süreci bellek sızıntısıyla yanıt veremez oldu; dağıtım yok, trafik normal.",
        "Servis deadlock'a girdi; thread havuzu dolu, yeniden başlatma gerekiyor.",
        "Süreç zombi durumda; kaynak/kod değişmeden yeniden başlatma yeterli."
      ]
    }
  ].freeze

  def initialize(random: Random.new)
    @random = random
  end

  # Make sure the simulated services (and a policy) exist. Idempotent.
  def ensure_services!
    policy = EscalationPolicy.find_or_create_by!(name: "Simülasyon") do |p|
      p.ack_timeout_minutes = 10
      p.max_level = 3
      p.active = true
    end

    SCENARIOS.map { |s| s[:service] }.uniq.each do |key|
      Service.find_or_create_by!(routing_key: key) do |svc|
        svc.name = key.tr("-", " ").split.map(&:capitalize).join(" ")
        svc.escalation_policy = policy
        svc.active = true
      end
    end

    ensure_oncall!
  end

  # Build a rotating on-call schedule for today (3-hour shifts) so that someone
  # is always on call when the agent needs to page a human. Idempotent.
  def ensure_oncall!
    return if OnCallShift.where("ends_at > ?", Time.current).exists?

    users = User.where(role: "responder").order(:id).to_a
    users = User.order(:id).to_a if users.empty?
    return if users.empty?

    day = Time.current.beginning_of_day
    8.times do |i| # 8 x 3h = full day
      OnCallShift.create!(
        user: users[i % users.size],
        starts_at: day + (i * 3).hours,
        ends_at: day + ((i + 1) * 3).hours
      )
    end
  end

  # Fabricate `count` incidents. Returns the created Incident records.
  def generate!(count: 5)
    ensure_services!

    Array.new(count) do
      scenario = SCENARIOS.sample(random: @random)
      service  = Service.find_by!(routing_key: scenario[:service])

      incident, = Incident.ingest(
        service: service,
        dedup_key: "#{scenario[:service]}-#{SecureRandom.hex(3)}", # unique -> its own incident
        title: scenario[:titles].sample(random: @random),
        summary: scenario[:summaries].sample(random: @random),
        urgency: scenario[:urgency],
        source: "simulator"
      )
      incident.update!(root_cause_action: scenario[:root_cause], simulated: true)
      incident
    end
  end
end

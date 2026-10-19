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

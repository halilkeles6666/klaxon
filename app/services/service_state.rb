# A small but REAL stateful service. It has live metrics and a hidden fault.
# A fault genuinely degrades the metrics; applying the CORRECT remediation
# genuinely restores them; a wrong action changes nothing. Health is MEASURED
# from the metrics — there is no answer key used for scoring.
#
# The agent/Jev never sees `fault`; it only reads the symptoms (derived from the
# metrics) and must infer the right remediation. Whether it "worked" is decided
# by re-reading #healthy? after the action.
class ServiceState
  # fault => the remediation that actually fixes it + how it looks
  FAULTS = {
    "crashed" => {
      fix: "restart_service", urgency: "high",
      title: ->(n) { "#{n} yanıt vermiyor" },
      desc: "Süreç yanıt vermiyor (health check FAIL). Bellek kullanımı tavan yaptı " \
            "(sızıntı belirtisi); son dağıtım yok, trafik normal.",
      hit: { up: false, error_rate: 100.0, latency_ms: 0, cpu: 0 }
    },
    "overloaded" => {
      fix: "scale_up", urgency: "high",
      title: ->(n) { "#{n} doygun — yüksek gecikme" },
      desc: "Trafik birkaç katına çıktı; işlemciler doygun. Kod/dağıtım değişmedi, " \
            "mevcut kapasite yetmiyor.",
      hit: { cpu: 96.0, latency_ms: 2400, error_rate: 3.0 }
    },
    "bad_deploy" => {
      fix: "rollback_deploy", urgency: "high",
      title: ->(n) { "#{n} dağıtım sonrası hata patlaması" },
      desc: "Son dağıtımdan hemen sonra hata oranı fırladı; gecikme ve kaynak " \
            "kullanımı normal. Önceki sürümde sorun yoktu.",
      hit: { error_rate: 22.0, latency_ms: 220 }
    },
    "queue_stuck" => {
      fix: "clear_queue", urgency: "low",
      title: ->(n) { "#{n} kuyruğu tıkandı" },
      desc: "İş kuyruğu onbinlere birikti, disk dolmak üzere; zehirli bir mesaj " \
            "işçiyi tıkamış görünüyor.",
      hit: { queue_depth: 48_000, error_rate: 1.0 }
    },
    "primary_down" => {
      fix: "failover", urgency: "high",
      title: ->(n) { "#{n} birincil veritabanı düştü" },
      desc: "Birincil veritabanı düğümü erişilemez (DOWN); sağlıklı ve güncel bir " \
            "replika promote edilmeyi bekliyor.",
      hit: { up: false, error_rate: 100.0 }
    }
  }.freeze

  attr_reader :key, :name, :fault

  def initialize(key, name)
    @key = key
    @name = name
    reset_healthy!
  end

  def reset_healthy!
    @up = true
    @error_rate = 0.3
    @latency_ms = 140
    @cpu = 35
    @queue_depth = 8
    @fault = nil
  end

  def inject_fault!(fault)
    @fault = fault
    FAULTS.fetch(fault)[:hit].each { |metric, value| instance_variable_set("@#{metric}", value) }
  end

  # Apply a remediation. The correct fix for the current fault genuinely heals
  # the service; anything else does nothing. Returns true if now healthy.
  def apply(action)
    reset_healthy! if @fault && action.to_s == FAULTS[@fault][:fix]
    healthy?
  end

  # Health is measured from the live metrics — this is the ground truth.
  def healthy?
    @up && @error_rate < 5 && @cpu < 85 && @latency_ms < 800 && @queue_depth < 1000
  end

  def fix
    @fault && FAULTS[@fault][:fix]
  end

  def urgency
    @fault ? FAULTS[@fault][:urgency] : "low"
  end

  def alert_title
    @fault ? FAULTS[@fault][:title].call(@name) : "#{@name} sağlıklı"
  end

  # The symptoms the monitor/agent sees — derived from the fault context and the
  # live metrics. Deliberately does NOT name the fault or the fix.
  def alert_summary
    return "Tüm metrikler normal." unless @fault
    "#{FAULTS[@fault][:desc]} [ölçümler: #{metrics_line}]"
  end

  def metrics_line
    "durum #{@up ? 'UP' : 'DOWN'}, hata %#{@error_rate.round}, CPU %#{@cpu.round}, " \
      "p95 #{@latency_ms}ms, kuyruk #{@queue_depth}"
  end
end

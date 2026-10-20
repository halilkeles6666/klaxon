# Watches the store's real telemetry (RequestLog) and opens a Klaxon incident
# for any component whose behavior is anomalous. Whether something is an anomaly
# is decided by a pluggable detector — the LLM (Jev) when configured, else a
# fixed threshold. The incident description combines the real telemetry with a
# log-derived context clue; the remediation is left for the agent/Jev to infer.
# root_cause_action is stored for transparency only — success is decided by the
# component actually recovering.
class StoreMonitor
  def initialize(detector: AnomalyDetector.default)
    @detector = detector
  end

  def detect!
    StoreBackend::COMPONENTS.filter_map do |component, name|
      stats = RequestLog.window_stats(component)
      next if stats.nil?
      next unless @detector.anomalous?(component_name: name, stats: stats)
      next if Service.find_by(routing_key: component)&.incidents&.open&.exists? # already handled

      open_incident(component, stats)
    end
  end

  private

  def open_incident(component, stats)
    service = Service.find_by!(routing_key: component)
    fault   = SiteFault.active_for(component)&.fault
    cfg     = fault && ServiceState::FAULTS[fault]

    incident, = Incident.ingest(
      service: service,
      dedup_key: "store-#{component}-#{SecureRandom.hex(2)}",
      title: cfg ? cfg[:title].call(service.name) : "#{service.name} sağlık sorunu",
      summary: summary(cfg, stats),
      urgency: stats[:error_rate] >= 5 ? "high" : "low",
      source: "monitor")
    incident.update!(simulated: true, root_cause_action: SiteFault::FIXES[fault])
    incident
  end

  def summary(cfg, stats)
    context = cfg ? "#{cfg[:desc]} " : ""
    "#{context}[ölçülen telemetri: #{stats[:count]} istek, hata %#{stats[:error_rate]}, p95 #{stats[:p95_ms]}ms]"
  end
end

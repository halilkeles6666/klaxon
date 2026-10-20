# Watches the store's real telemetry (RequestLog) and opens a Klaxon incident
# for any component whose MEASURED error rate / latency has breached. The
# incident description combines the real telemetry with a log-derived context
# clue (as a real monitor would surface from logs/traces); the remediation is
# left for the agent/Jev to infer. root_cause_action is stored for transparency
# only — success is decided by the component actually recovering.
class StoreMonitor
  ERROR_THRESHOLD = 5.0  # percent
  P95_THRESHOLD   = 1000 # ms

  def detect!
    StoreBackend::COMPONENTS.keys.filter_map do |component|
      stats = RequestLog.window_stats(component)
      next if stats.nil?
      next if stats[:error_rate] < ERROR_THRESHOLD && stats[:p95_ms] < P95_THRESHOLD
      next if Service.find_by(routing_key: component)&.incidents&.open&.exists? # already being handled

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
      urgency: stats[:error_rate] >= ERROR_THRESHOLD ? "high" : "low",
      source: "monitor")
    incident.update!(simulated: true, root_cause_action: SiteFault::FIXES[fault])
    incident
  end

  def summary(cfg, stats)
    context = cfg ? "#{cfg[:desc]} " : ""
    "#{context}[ölçülen telemetri: #{stats[:count]} istek, hata %#{stats[:error_rate]}, p95 #{stats[:p95_ms]}ms]"
  end
end

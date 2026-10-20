module Api
  # The live Nimbus store pushes a telemetry snapshot here. For each component
  # Klaxon decides — with the LLM (Jev) anomaly detector — whether it is an
  # anomaly worth paging for, opens an incident from the reported symptoms, and
  # resolves it in the background (ResolveIncidentJob -> RemoteStoreWorld).
  class TelemetryController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      StoreBackend.ensure_components!
      detector = AnomalyDetector.default
      opened = []

      components.each do |key, metrics|
        service = Service.find_by(routing_key: key.to_s.strip.downcase)
        next if service.nil?

        stats = {
          count: metrics[:count].to_i,
          error_rate: metrics[:error_rate].to_f,
          p95_ms: metrics[:p95].to_i
        }
        next unless detector.anomalous?(component_name: service.name, stats: stats)
        next if service.incidents.open.exists? # already being handled

        incident = open_incident(service, metrics, stats)
        ResolveIncidentJob.perform_later(incident.id) if ENV["NIMBUS_URL"].to_s.strip.present?
        opened << incident.reference
      end

      render json: { opened: opened }
    end

    private

    def components
      params[:components] || {}
    end

    def open_incident(service, metrics, stats)
      incident, = Incident.ingest(
        service: service,
        dedup_key: "nimbus-#{service.routing_key}",
        title: "#{service.name} anomali tespit edildi",
        summary: metrics[:log].presence ||
          "Telemetri: #{stats[:count]} istek, hata %#{stats[:error_rate]}, p95 #{stats[:p95_ms]}ms",
        urgency: stats[:error_rate] >= 5 ? "high" : "low",
        source: "nimbus")
      incident.update!(simulated: true)
      incident
    end
  end
end

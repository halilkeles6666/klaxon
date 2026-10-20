module Api
  # Public JSON ingest for external systems (e.g. the live Nimbus store) to
  # report an incident by routing_key. On receipt Klaxon opens the incident and,
  # when NIMBUS_URL is configured, immediately lets the agent resolve it by
  # calling the store's /heal endpoint over HTTP.
  class AlertsController < ApplicationController
    allow_unauthenticated_access
    skip_forgery_protection

    def create
      StoreBackend.ensure_components!
      service = Service.find_by(routing_key: params[:routing_key].to_s.strip.downcase)
      if service.nil?
        return render json: { error: "unknown routing_key" }, status: :unprocessable_entity
      end

      incident, outcome = Incident.ingest(
        service: service,
        dedup_key: params[:dedup_key].presence || params[:routing_key],
        title: params[:title].presence || "#{service.name} uyarısı",
        summary: params[:summary].presence || params[:title],
        urgency: params[:urgency].presence || "high",
        source: "nimbus")
      incident.update!(simulated: true)

      resolution = nil
      if ENV["NIMBUS_URL"].to_s.strip.present?
        resolution = ResolutionAgent.new(jev: jev_client, world: RemoteStoreWorld.new).resolve!(incident)
      end

      render json: {
        reference: incident.reference,
        outcome: outcome,
        resolution: resolution,
        agent_action: incident.reload.agent_action,
        status: incident.status
      }
    end

    private

    def jev_client
      ENV["TYPESAFE_API_KEY"].to_s.strip.present? ? JevClient.new : StubJevClient.new
    end
  end
end

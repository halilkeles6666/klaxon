# Resolves an incident off the request thread, so ingesting an alert/telemetry
# returns immediately while the agent works (Jev calls + remote /heal + retries)
# in the background (:async adapter in production — an in-process thread pool).
class ResolveIncidentJob < ApplicationJob
  queue_as :default

  def perform(incident_id)
    incident = Incident.find_by(id: incident_id)
    return if incident.nil? || incident.status == "resolved"

    jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present? ? JevClient.new : StubJevClient.new
    ResolutionAgent.new(jev: jev, world: RemoteStoreWorld.new).resolve!(incident)
  end
end

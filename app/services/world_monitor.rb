# The detection agent. It scans the live world, finds services whose MEASURED
# health has degraded, and opens an incident for each from the observed
# symptoms — exactly how a real monitor turns metric breaches into alerts.
#
# root_cause_action is stored for TRANSPARENCY only (so the dashboard can reveal
# the true fix afterwards); it is NOT used to decide whether the agent succeeded
# — that is measured by the service actually becoming healthy again.
class WorldMonitor
  def initialize(world)
    @world = world
  end

  # Returns the incidents created for the currently-unhealthy services.
  def detect!
    @world.unhealthy_states.map do |state|
      service = Service.find_by!(routing_key: state.key)
      incident, = Incident.ingest(
        service: service,
        dedup_key: "world-#{SecureRandom.hex(3)}",
        title: state.alert_title,
        summary: state.alert_summary,
        urgency: state.urgency,
        source: "monitor")
      incident.update!(simulated: true, root_cause_action: state.fix)
      incident
    end
  end
end

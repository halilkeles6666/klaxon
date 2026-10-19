# An ActionWorld for incidents that have NO hidden ground truth — e.g. a
# free-text incident the user typed in. Instead of comparing to a known
# root_cause_action, it asks Jev to judge whether the applied remediation
# would resolve the incident. This keeps user-provided incidents fully
# Jev-driven (one call to choose the action, one to judge the outcome).
class JevWorld
  RESOLVE_THRESHOLD = 0.5

  def initialize(jev: JevClient.new)
    @jev = jev
  end

  # Returns true if Jev judges that applying `action` resolves the incident.
  def apply(action, incident)
    description = ResolutionAgent::ACTIONS[action] || action
    latest = incident.alerts.chronological.last
    state = [
      "Service: #{incident.service.name}.",
      "Incident: #{incident.title}.",
      ("Details: #{latest.summary}." if latest),
      "An automated responder applied this remediation: #{action} (#{description})."
    ].compact.join(" ")

    result = @jev.evaluate(
      state: state,
      questions: {
        resolved: JevClient::Jev.noul(
          "Applying this remediation resolves the incident's root cause.")
      })

    result.noul(:resolved) >= RESOLVE_THRESHOLD
  end
end

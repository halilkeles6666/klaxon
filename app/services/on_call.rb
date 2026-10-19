# Resolves who the on-call human is at a given moment. Prefers an active
# on-call shift; falls back to any responder, then any user. Returns nil only
# when there are no users at all.
module OnCall
  module_function

  def on_call_at(now = Time.current)
    OnCallShift.covering(now).chronological.first&.user ||
      User.where(role: "responder").order(:id).first ||
      User.order(:id).first
  end
end

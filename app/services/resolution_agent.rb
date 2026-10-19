# The autonomous responder (Agent 2 in the agent->agent loop).
#
# Given a freshly triggered incident it:
#   1. asks Jev (one System One request) for severity, auto-resolvability, and
#      the single best remediation;
#   2. takes ownership (acknowledge -> stops the escalation clock);
#   3. applies the chosen action against the simulated ActionWorld;
#   4. if it fails, asks Jev for the next best remaining action and retries,
#      up to MAX_ATTEMPTS;
#   5. resolves the incident on success, or records that it gave up.
#
# Every step is written to the incident timeline with Jev's confidence, so the
# whole chain of reasoning is auditable.
class ResolutionAgent
  # label => description shown to Jev (the agent's action vocabulary)
  ACTIONS = {
    "restart_service" => "Restart the crashed, hung, or leaking service process to clear its in-memory state.",
    "scale_up"        => "Add capacity or more instances to absorb elevated load or traffic spikes.",
    "rollback_deploy" => "Roll back the most recent deployment that introduced a regression.",
    "clear_queue"     => "Drain a backed-up message queue, flush a full disk, or clear a stuck buffer.",
    "failover"        => "Fail over to a healthy replica or secondary region when the primary is down."
  }.freeze

  SEVERITY_LEVELS = %w[negligible minor moderate major critical].freeze # score 0..4

  CONFIDENCE_FLOOR = 0.40 # below this the agent flags the decision as shaky
  MAX_ATTEMPTS     = 3

  def initialize(jev: JevClient.new, world: ActionWorld.new,
                 notifier: TelegramNotifier.new, logger: Rails.logger)
    @jev      = jev
    @world    = world
    @notifier = notifier
    @logger   = logger
  end

  # Drives one incident from triggered to resolved (or gives up).
  # Returns :resolved or :unresolved.
  def resolve!(incident)
    incident.acknowledge!(nil) if incident.status == "triggered"

    assessment = assess(incident)
    apply_assessment(incident, assessment)

    # Safety net #1: if Jev itself is unsure, don't act recklessly — hand off
    # to the human who is on call right now.
    if assessment[:confidence] && assessment[:confidence] < CONFIDENCE_FLOOR
      page_human!(incident, reason: "düşük güven (%#{pct_num(assessment[:confidence])}) — ajan riske girmedi")
      return :escalated
    end

    tried  = []
    action = assessment[:action]

    MAX_ATTEMPTS.times do
      incident.increment!(:resolution_attempts)
      tried << action
      incident.update!(agent_action: action)

      if @world.apply(action, incident)
        incident.update!(auto_resolved: true)
        incident.resolve!(nil)
        incident.log_event("agent_resolved",
          detail: "Jev ajanı '#{action}' ile olayı çözdü (deneme #{incident.resolution_attempts}).")
        return :resolved
      end

      incident.log_event("agent_action_failed",
        detail: "'#{action}' işe yaramadı (deneme #{incident.resolution_attempts}).")

      remaining = ACTIONS.except(*tried)
      break if remaining.empty?

      nxt    = next_action(incident, tried, remaining)
      action = nxt[:action]
      incident.update!(agent_confidence: nxt[:confidence])
    end

    # Safety net #2: exhausted every remediation it could think of — dead end.
    incident.log_event("agent_gave_up",
      detail: "Ajan #{incident.resolution_attempts} denemede çözemedi; denenen: #{tried.join(', ')}.")
    page_human!(incident, reason: "#{incident.resolution_attempts} deneme başarısız — çıkmaz")
    :escalated
  end

  private

  # Hand the incident to the human who is on call at this moment, and alert
  # them over Telegram if configured.
  def page_human!(incident, reason:)
    human = OnCall.on_call_at
    incident.update!(needs_human: true, paged_user: human)
    who = human&.display_name || "nöbetçi bulunamadı"

    delivery = @notifier.notify(user: human, text: alert_text(incident, human, reason))
    suffix = {
      sent: " (Telegram: gönderildi ✓)",
      skipped: " (Telegram: ayarlı değil)",
      error: " (Telegram: gönderilemedi)"
    }[delivery]

    incident.log_event("human_paged",
      detail: "🚨 Jev çıkmaza girdi (#{reason}); o an nöbetçi olan #{who} alarmlandı.#{suffix}",
      actor: human)
  end

  def alert_text(incident, human, reason)
    name = human&.display_name.to_s.split.first.presence || "Nöbetçi"
    <<~MSG.strip
      🚨 ALERT ALERT 🚨
      #{name}, Jev bu olayı çözemedi — sıra sende.

      Olay: #{incident.reference} — #{incident.title}
      Servis: #{incident.service.name}
      Önem: #{SEVERITY_LEVELS[incident.severity.to_i]} (#{incident.severity}/4)
      Sebep: #{reason}
      Son denenen aksiyon: #{incident.agent_action}
    MSG
  end

  # One Jev request, three typed decisions at once.
  def assess(incident)
    result = @jev.evaluate(
      state: describe(incident),
      questions: {
        severity: JevClient::Jev.score(
          "Rate the operational severity and customer impact of this incident.",
          SEVERITY_LEVELS),
        auto_ok: JevClient::Jev.noul(
          "This incident can be safely auto-remediated by software without human judgement."),
        action: JevClient::Jev.choice(
          "Choose the single best remediation action that fixes the ROOT CAUSE of this incident.",
          ACTIONS)
      })

    { severity: result.score(:severity),
      auto_ok: result.noul(:auto_ok),
      action: result.choice(:action),
      confidence: result.confidence(:action) }
  end

  def apply_assessment(incident, a)
    incident.update!(severity: a[:severity], agent_action: a[:action],
                     agent_confidence: a[:confidence])
    shaky = a[:confidence] && a[:confidence] < CONFIDENCE_FLOOR ? " (DÜŞÜK GÜVEN)" : ""
    incident.log_event("agent_assessed",
      detail: "Jev değerlendirmesi → önem: #{SEVERITY_LEVELS[a[:severity]]} (#{a[:severity]}/4), " \
              "otomatik çözülebilir olasılığı: #{pct(a[:auto_ok])}, " \
              "seçilen aksiyon: #{a[:action]} güven #{pct(a[:confidence])}#{shaky}.")
  end

  def next_action(incident, tried, remaining)
    result = @jev.evaluate(
      state: describe(incident, tried: tried),
      questions: {
        action: JevClient::Jev.choice(
          "The previous remediation(s) [#{tried.join(', ')}] did NOT resolve the incident. " \
          "Choose the next best remediation from the remaining options.",
          remaining)
      })
    { action: result.choice(:action), confidence: result.confidence(:action) }
  end

  # The state handed to Jev. Deliberately excludes root_cause_action.
  def describe(incident, tried: [])
    latest = incident.alerts.chronological.last
    lines = [
      "Service: #{incident.service.name} (#{incident.service.routing_key}).",
      "Incident: #{incident.title}.",
      ("Details: #{latest.summary}." if latest),
      "Reported urgency: #{incident.urgency}.",
      "Open for #{minutes_open(incident)} minutes, escalation level #{incident.escalation_level}."
    ]
    lines << "Already tried (did not work): #{tried.join(', ')}." if tried.any?
    lines.compact.join(" ")
  end

  def minutes_open(incident)
    return 0 unless incident.triggered_at
    ((Time.current - incident.triggered_at) / 60).round
  end

  def pct(value)
    value.nil? ? "n/a" : "#{(value * 100).round}%"
  end

  def pct_num(value)
    value.nil? ? 0 : (value * 100).round
  end
end

require "test_helper"

class ResolutionAgentTest < ActiveSupport::TestCase
  # A deterministic world: the correct action always works, any other fails.
  # This makes the agent's outcome depend solely on Jev's choice.
  class TruthfulWorld
    def apply(action, incident)
      action.to_s == incident.root_cause_action.to_s
    end
  end

  setup do
    @service = services(:payments)
    @world   = TruthfulWorld.new
  end

  def new_incident(root:)
    incident, = Incident.ingest(service: @service, dedup_key: "k-#{SecureRandom.hex(2)}",
                                title: "x", summary: "y")
    incident.update!(root_cause_action: root, simulated: true)
    incident
  end

  def pick(action, confidence: 0.9)
    { "action" => { "type" => "choice", "choice" => action, "confidence" => confidence } }
  end

  test "resolves in one attempt when Jev picks the correct action" do
    incident = new_incident(root: "rollback_deploy")
    jev = StubJevClient.new { |_state, _q| pick("rollback_deploy") }

    outcome = ResolutionAgent.new(jev: jev, world: @world).resolve!(incident)

    assert_equal :resolved, outcome
    incident.reload
    assert_equal "resolved", incident.status
    assert incident.auto_resolved
    assert_equal "rollback_deploy", incident.agent_action
    assert_equal 1, incident.resolution_attempts
    assert incident.agent_action_correct?
  end

  test "records severity, confidence, and a timeline of agent events" do
    incident = new_incident(root: "rollback_deploy")
    jev = StubJevClient.new { |_s, _q| pick("rollback_deploy", confidence: 0.77) }

    ResolutionAgent.new(jev: jev, world: @world).resolve!(incident)

    incident.reload
    assert_not_nil incident.severity
    assert_in_delta 0.77, incident.agent_confidence, 0.001
    kinds = incident.incident_events.pluck(:kind)
    assert_includes kinds, "agent_assessed"
    assert_includes kinds, "agent_resolved"
  end

  test "retries with a new action and resolves on the second attempt" do
    incident = new_incident(root: "failover")
    # First (assessment) call includes a :severity question -> pick a WRONG action.
    # Retry call has only :action -> pick the correct one.
    jev = StubJevClient.new do |_state, questions|
      if questions.key?(:severity)
        pick("restart_service")   # wrong
      else
        pick("failover")          # correct on retry
      end
    end

    outcome = ResolutionAgent.new(jev: jev, world: @world).resolve!(incident)

    assert_equal :resolved, outcome
    incident.reload
    assert_equal "failover", incident.agent_action
    assert_equal 2, incident.resolution_attempts
    assert_includes incident.incident_events.pluck(:kind), "agent_action_failed"
  end

  test "pages the on-call human after MAX_ATTEMPTS when it never picks correctly" do
    incident = new_incident(root: "failover")
    # Always pick the first remaining option that is NOT the correct one.
    jev = StubJevClient.new do |_state, questions|
      options = questions[:action][:criteria].keys
      wrong = (options - [ "failover" ]).first
      pick(wrong)
    end

    outcome = ResolutionAgent.new(jev: jev, world: @world).resolve!(incident)

    assert_equal :escalated, outcome
    incident.reload
    assert_not_equal "resolved", incident.status
    assert_equal ResolutionAgent::MAX_ATTEMPTS, incident.resolution_attempts
    assert incident.needs_human, "should be flagged for a human"
    assert_equal OnCall.on_call_at, incident.paged_user
    kinds = incident.incident_events.pluck(:kind)
    assert_includes kinds, "agent_gave_up"
    assert_includes kinds, "human_paged"
  end

  test "pages the human immediately when Jev's confidence is below the floor" do
    incident = new_incident(root: "failover")
    low = ResolutionAgent::CONFIDENCE_FLOOR - 0.1
    jev = StubJevClient.new { |_s, _q| pick("restart_service", confidence: low) }

    outcome = ResolutionAgent.new(jev: jev, world: @world).resolve!(incident)

    assert_equal :escalated, outcome
    incident.reload
    assert incident.needs_human
    assert_equal 0, incident.resolution_attempts, "should not have acted on a shaky decision"
    assert_includes incident.incident_events.pluck(:kind), "human_paged"
  end

  test "names whoever is on call at the moment of paging" do
    incident = new_incident(root: "failover")
    # Put a specific user on call right now.
    on_call = users(:admin)
    OnCallShift.create!(user: on_call, starts_at: 1.hour.ago, ends_at: 1.hour.from_now)
    jev = StubJevClient.new { |_s, _q| pick("restart_service", confidence: 0.1) }

    ResolutionAgent.new(jev: jev, world: @world).resolve!(incident)

    assert_equal on_call, incident.reload.paged_user
  end
end

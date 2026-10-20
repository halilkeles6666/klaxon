require "test_helper"

# Proves the real closed loop: break a service -> agent applies Jev's action to
# the LIVE world -> success is decided by the service actually recovering
# (measured health), not by matching an answer key.
class ClosedLoopTest < ActiveSupport::TestCase
  setup { IncidentSimulator.new.ensure_services! }

  def incident_for(state)
    incident, = Incident.ingest(
      service: Service.find_by!(routing_key: state.key),
      dedup_key: "w-#{SecureRandom.hex(2)}",
      title: state.alert_title, summary: state.alert_summary, urgency: "high")
    incident.update!(simulated: true, root_cause_action: state.fix)
    incident
  end

  def picks(action)
    ->(_s, _q) { { "action" => { "type" => "choice", "choice" => action, "confidence" => 0.9 } } }
  end

  test "a crashed service is really healed when the agent restarts it" do
    world = SimulatedWorld.new(random: Random.new(1))
    state = world.states.first
    state.inject_fault!("crashed")
    incident = incident_for(state)

    outcome = ResolutionAgent.new(jev: StubJevClient.new(&picks("restart_service")), world: world).resolve!(incident)

    assert_equal :resolved, outcome
    assert state.healthy?, "the live service must actually be healthy again"
    assert_equal "resolved", incident.reload.status
    assert incident.auto_resolved
  end

  test "a wrong action leaves it broken; the agent retries until health recovers" do
    world = SimulatedWorld.new(random: Random.new(1))
    state = world.states.first
    state.inject_fault!("primary_down") # fix: failover
    incident = incident_for(state)

    jev = StubJevClient.new do |_state, questions|
      if questions.key?(:severity) # first assessment -> wrong action
        { "action" => { "type" => "choice", "choice" => "restart_service", "confidence" => 0.9 } }
      else                         # retry -> correct action
        { "action" => { "type" => "choice", "choice" => "failover", "confidence" => 0.9 } }
      end
    end

    outcome = ResolutionAgent.new(jev: jev, world: world).resolve!(incident)

    assert_equal :resolved, outcome
    assert state.healthy?
    assert_operator incident.reload.resolution_attempts, :>=, 2
  end

  test "if the agent never finds the fix, the service stays broken and a human is paged" do
    world = SimulatedWorld.new(random: Random.new(1))
    state = world.states.first
    state.inject_fault!("primary_down") # fix: failover
    incident = incident_for(state)

    # Always pick a non-failover action.
    jev = StubJevClient.new do |_s, questions|
      options = questions[:action][:criteria].keys
      { "action" => { "type" => "choice", "choice" => (options - [ "failover" ]).first, "confidence" => 0.9 } }
    end

    outcome = ResolutionAgent.new(jev: jev, world: world).resolve!(incident)

    assert_equal :escalated, outcome
    refute state.healthy?, "the live service is genuinely still broken"
    assert incident.reload.needs_human
  end
end

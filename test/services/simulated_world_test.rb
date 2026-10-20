require "test_helper"

class SimulatedWorldTest < ActiveSupport::TestCase
  setup { IncidentSimulator.new.ensure_services! }

  test "inject_random_faults! breaks the requested number of services" do
    world = SimulatedWorld.new(random: Random.new(1))
    world.inject_random_faults!(3)
    assert_equal 3, world.unhealthy_states.size
  end

  test "apply gives real health feedback: wrong action stays broken, correct heals" do
    world = SimulatedWorld.new(random: Random.new(1))
    world.inject_random_faults!(1)
    state = world.unhealthy_states.first
    incident = Incident.new(service: Service.find_by!(routing_key: state.key))

    wrong = (ServiceState::FAULTS.values.map { |c| c[:fix] } - [ state.fix ]).first
    refute world.apply(wrong, incident), "wrong action should leave it unhealthy"
    assert world.apply(state.fix, incident), "correct action should make it healthy"
  end

  test "WorldMonitor opens an incident per unhealthy service from the symptoms" do
    world = SimulatedWorld.new(random: Random.new(2))
    world.inject_random_faults!(2)

    incidents = WorldMonitor.new(world).detect!
    assert_equal 2, incidents.size
    incidents.each do |incident|
      assert incident.simulated
      assert incident.root_cause_action.present?, "true fix stored for transparency"
      assert incident.alerts_count.positive?
      assert_equal "triggered", incident.status
    end
  end
end

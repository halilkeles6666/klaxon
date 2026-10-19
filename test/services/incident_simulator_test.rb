require "test_helper"

class IncidentSimulatorTest < ActiveSupport::TestCase
  test "generate! creates simulated incidents with hidden ground truth" do
    sim = IncidentSimulator.new(random: Random.new(1))

    incidents = assert_difference -> { Incident.count }, 4 do
      sim.generate!(count: 4)
    end

    assert_equal 4, incidents.size
    incidents.each do |incident|
      assert incident.simulated, "should be flagged simulated"
      assert incident.root_cause_action.present?, "should carry a hidden root cause"
      assert_includes ResolutionAgent::ACTIONS.keys, incident.root_cause_action
      assert_equal "triggered", incident.status
      assert incident.alerts_count.positive?
    end
  end

  test "ensure_services! is idempotent" do
    sim = IncidentSimulator.new
    sim.ensure_services!
    count_after_first = Service.count
    sim.ensure_services!
    assert_equal count_after_first, Service.count
  end
end

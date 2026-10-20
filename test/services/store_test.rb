require "test_helper"

class StoreTest < ActiveSupport::TestCase
  setup { StoreBackend.ensure_components! }

  test "a healthy component serves 200 and records telemetry" do
    assert_difference -> { RequestLog.count }, 1 do
      result = StoreBackend.serve("magaza-vitrin", "/magaza")
      assert result[:ok]
      assert_equal 200, result[:status]
    end
  end

  test "a crashed component really returns a server error" do
    SiteFault.create!(component: "magaza-vitrin", fault: "crashed")
    result = StoreBackend.serve("magaza-vitrin", "/magaza")
    refute result[:ok]
    assert_operator result[:status], :>=, 500
  end

  test "the monitor opens an incident from measured telemetry" do
    SiteFault.create!(component: "magaza-odeme", fault: "bad_deploy")
    StoreTraffic.generate!(hits: 30)

    incidents = StoreMonitor.new.detect!
    incident = incidents.find { |i| i.service.routing_key == "magaza-odeme" }
    assert incident, "should open an incident for the faulted checkout"
    assert_equal "rollback_deploy", incident.root_cause_action # transparency only
    assert incident.simulated
  end

  test "StoreWorld: the correct remediation really heals; a wrong one does not" do
    SiteFault.create!(component: "magaza-db", fault: "primary_down")
    incident = Incident.new(service: Service.find_by!(routing_key: "magaza-db"))
    world = StoreWorld.new

    refute world.apply("restart_service", incident), "wrong action should not heal"
    assert SiteFault.active_for("magaza-db"), "fault should remain"

    assert world.apply("failover", incident), "correct action should heal"
    assert_nil SiteFault.active_for("magaza-db"), "fault should be gone (store healed)"
  end
end

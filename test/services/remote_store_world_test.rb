require "test_helper"

class RemoteStoreWorldTest < ActiveSupport::TestCase
  test "with no base URL it is a no-op that reports healthy" do
    world = RemoteStoreWorld.new(base_url: "", token: "")
    incident = Incident.new(service: Service.new(routing_key: "magaza-odeme"))
    assert world.apply("restart_service", incident)
  end

  test "a network failure is treated as still-broken (so the agent retries)" do
    # Point at a port nothing listens on -> connection refused -> false.
    world = RemoteStoreWorld.new(base_url: "http://127.0.0.1:0", token: "t")
    incident = Incident.new(service: Service.new(routing_key: "magaza-odeme"))
    refute world.apply("restart_service", incident)
  end
end

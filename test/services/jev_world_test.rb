require "test_helper"

class JevWorldTest < ActiveSupport::TestCase
  def incident
    i, = Incident.ingest(service: services(:payments), dedup_key: "u-#{SecureRandom.hex(2)}",
                         title: "x", summary: "y")
    i
  end

  def noul(value)
    { "resolved" => { "type" => "noul", "noul" => value } }
  end

  test "resolves when Jev judges the remediation sufficient" do
    jev = StubJevClient.new { |_s, _q| noul(0.9) }
    assert JevWorld.new(jev: jev).apply("restart_service", incident)
  end

  test "does not resolve when Jev judges it insufficient" do
    jev = StubJevClient.new { |_s, _q| noul(0.2) }
    refute JevWorld.new(jev: jev).apply("restart_service", incident)
  end
end

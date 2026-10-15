require "test_helper"

class ServiceTest < ActiveSupport::TestCase
  test "routing_key is normalized to lowercase and must be unique" do
    policy = escalation_policies(:standard)
    svc = Service.create!(name: "Search API", routing_key: "  Search-API  ", escalation_policy: policy)
    assert_equal "search-api", svc.routing_key

    dup = Service.new(name: "Another", routing_key: "search-api", escalation_policy: policy)
    refute dup.valid?
  end

  test "routing_key rejects spaces and uppercase formats" do
    svc = Service.new(name: "x", routing_key: "Bad Key!", escalation_policy: escalation_policies(:standard))
    refute svc.valid?
  end

  test "service exposes its policy's ack timeout" do
    assert_equal 5, services(:payments).ack_timeout_minutes
  end
end

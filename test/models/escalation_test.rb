require "test_helper"

# The time rule: an unacknowledged incident escalates one level every
# ack_timeout_minutes, up to the policy's max_level. All assertions pin the
# clock with travel_to so the arithmetic is deterministic.
class EscalationTest < ActiveSupport::TestCase
  setup do
    @service = services(:payments)   # ack_timeout 5 min, max_level 3
    @base    = Time.zone.local(2026, 10, 19, 12, 0, 0)
  end

  def trigger(now: @base)
    incident, = Incident.ingest(service: @service, dedup_key: "k", title: "x", now: now)
    incident
  end

  test "does not escalate before the ack timeout" do
    incident = trigger
    travel_to(@base + 4.minutes) do
      refute incident.escalation_due?
      refute incident.apply_escalations!
      assert_equal 1, incident.escalation_level
    end
  end

  test "escalates one level once the ack timeout passes" do
    incident = trigger
    travel_to(@base + 6.minutes) do
      assert incident.escalation_due?
      assert incident.apply_escalations!
      assert_equal 2, incident.escalation_level
      assert_equal "high", incident.urgency
    end
  end

  test "escalation is capped at the policy max level" do
    incident = trigger
    travel_to(@base + 40.minutes) do
      incident.apply_escalations!
      assert_equal 3, incident.escalation_level # not 1 + 40/5 = 9
      refute incident.apply_escalations!         # already at the ceiling
    end
  end

  test "acknowledging before the timeout stops the clock" do
    incident = trigger
    incident.acknowledge!(users(:responder), now: @base + 2.minutes)

    travel_to(@base + 30.minutes) do
      refute incident.escalatable?
      refute incident.apply_escalations!
      assert_equal 1, incident.escalation_level
      assert_nil incident.minutes_until_escalation
    end
  end

  test "minutes_until_escalation counts down to the next level" do
    incident = trigger
    travel_to(@base + 2.minutes) do
      assert_equal 3, incident.minutes_until_escalation # deadline at +5, so 3 left
    end
  end
end

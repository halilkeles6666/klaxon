require "test_helper"

class IncidentTest < ActiveSupport::TestCase
  setup do
    @service = services(:payments) # ack_timeout 5 min, max_level 3
    @user = users(:responder)
  end

  # ---- alert ingestion + deduplication (noise reduction) -----------------

  test "a fresh alert opens a new triggered incident with one alert" do
    assert_difference -> { Incident.count }, 1 do
      incident, outcome = Incident.ingest(service: @service, dedup_key: "k1", title: "DB down")
      assert_equal :created, outcome
      assert_equal "triggered", incident.status
      assert_equal 1, incident.alerts_count
      assert incident.reference.start_with?("INC-")
    end
  end

  test "repeat alerts with the same key group into the open incident" do
    first, = Incident.ingest(service: @service, dedup_key: "k1", title: "DB down")

    assert_no_difference -> { Incident.count } do
      grouped, outcome = Incident.ingest(service: @service, dedup_key: "k1", title: "DB down")
      assert_equal :grouped, outcome
      assert_equal first, grouped
    end

    assert_equal 2, first.reload.alerts_count
    assert_equal 1, first.duplicate_alerts_count
    assert_equal 1, first.alerts.where(deduplicated: true).count
  end

  test "different dedup keys open separate incidents" do
    Incident.ingest(service: @service, dedup_key: "k1", title: "A")
    assert_difference -> { Incident.count }, 1 do
      Incident.ingest(service: @service, dedup_key: "k2", title: "B")
    end
  end

  test "a new alert after resolution opens a fresh incident, not a group" do
    first, = Incident.ingest(service: @service, dedup_key: "k1", title: "A")
    first.resolve!(@user)

    assert_difference -> { Incident.count }, 1 do
      _, outcome = Incident.ingest(service: @service, dedup_key: "k1", title: "A again")
      assert_equal :created, outcome
    end
  end

  test "a blank dedup key is derived from the title" do
    incident, = Incident.ingest(service: @service, dedup_key: "", title: "High Error Rate!")
    assert_equal "high-error-rate", incident.dedup_key
  end

  # ---- status machine (aort dilimi) --------------------------------------

  test "valid path triggered -> acknowledged -> resolved" do
    incident, = Incident.ingest(service: @service, dedup_key: "k", title: "x")

    assert incident.acknowledge!(@user)
    assert_equal "acknowledged", incident.status
    assert_equal @user, incident.acknowledged_by
    assert incident.acknowledged_at.present?

    assert incident.resolve!(@user)
    assert_equal "resolved", incident.status
    assert incident.resolved_at.present?
  end

  test "an illegal transition is rejected and the status is unchanged" do
    incident, = Incident.ingest(service: @service, dedup_key: "k", title: "x")
    incident.resolve!(@user) # triggered -> resolved is allowed

    refute incident.transition_to!("acknowledged", actor: @user) # resolved -> acknowledged is not
    assert_equal "resolved", incident.reload.status
  end

  test "reopening a resolved incident restarts the escalation clock" do
    incident, = Incident.ingest(service: @service, dedup_key: "k", title: "x")
    incident.acknowledge!(@user)
    incident.resolve!(@user)

    assert incident.reopen!(@user)
    assert_equal "triggered", incident.status
    assert_equal 1, incident.escalation_level
    assert_nil incident.acknowledged_at
    assert_nil incident.resolved_at
  end

  test "every transition records a timeline event" do
    incident, = Incident.ingest(service: @service, dedup_key: "k", title: "x")
    incident.acknowledge!(@user)
    incident.resolve!(@user)

    assert_equal %w[triggered acknowledged resolved],
                 incident.incident_events.chronological.pluck(:kind)
  end
end

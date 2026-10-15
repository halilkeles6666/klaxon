require "test_helper"

# End-to-end test of the aort dilimi (core workflow):
#   a monitoring tool posts an alert (public) -> an incident is opened ->
#   a responder signs in -> sees it in the queue -> acknowledges it (stopping
#   escalation) -> resolves it. Plus: repeat alerts are deduplicated, and the
#   queue reflects escalation once the ack timeout passes.
class AortaSliceTest < ActionDispatch::IntegrationTest
  def sign_in_as(user, password = "password")
    post session_path, params: { email_address: user.email_address, password: password }
  end

  test "an alert travels end to end from ingest to resolved" do
    service = services(:payments)

    # 1) A monitoring tool posts an alert (no login).
    assert_difference -> { Incident.count }, 1 do
      post alerts_path, params: { alert: {
        service_id: service.id, title: "Checkout 500s", summary: "many 500s", urgency: "high"
      } }
    end
    incident = Incident.order(:triggered_at).last
    assert_equal "triggered", incident.status
    assert_redirected_to alert_received_path(incident.reference, outcome: "created")
    follow_redirect!
    assert_response :success
    assert_select ".big-ref", text: incident.reference

    # Responder workspace is gated behind authentication.
    get incident_path(incident)
    assert_redirected_to new_session_path

    # 2) Responder signs in.
    sign_in_as users(:responder)
    follow_redirect!
    assert_response :success

    # 3) Incident shows up in the queue and on its own page.
    get incidents_path
    assert_response :success
    assert_select "a.ref", text: incident.reference

    get incident_path(incident)
    assert_response :success
    assert_select "h1", text: incident.title

    # 4) Acknowledge -> resolve through the status machine.
    patch acknowledge_incident_path(incident)
    assert_equal "acknowledged", incident.reload.status
    assert_equal users(:responder), incident.acknowledged_by

    patch resolve_incident_path(incident)
    assert_equal "resolved", incident.reload.status
    assert incident.resolved_at.present?
  end

  test "repeat alerts are grouped into one incident (noise reduction)" do
    service = services(:web)
    post alerts_path, params: { alert: { service_id: service.id, title: "High latency", dedup_key: "lat" } }
    incident = Incident.order(:triggered_at).last

    assert_no_difference -> { Incident.count } do
      post alerts_path, params: { alert: { service_id: service.id, title: "High latency", dedup_key: "lat" } }
    end
    assert_redirected_to alert_received_path(incident.reference, outcome: "grouped")
    assert_equal 2, incident.reload.alerts_count
    assert_equal 1, incident.duplicate_alerts_count
  end

  test "the queue applies escalation once the ack timeout passes" do
    service = services(:payments) # 5-minute ack timeout
    sign_in_as users(:responder)
    base = Time.zone.local(2026, 10, 19, 12, 0, 0)
    incident, = Incident.ingest(service: service, dedup_key: "k", title: "x", now: base)

    travel_to(base + 12.minutes) do
      get incidents_path
      assert_response :success
    end
    assert_operator incident.reload.escalation_level, :>, 1,
                    "escalation should be applied lazily on read"
  end

  test "an illegal transition via the controller leaves the status unchanged" do
    sign_in_as users(:responder)
    incident, = Incident.ingest(service: services(:payments), dedup_key: "k", title: "x")
    incident.resolve!(users(:responder))

    patch acknowledge_incident_path(incident) # resolved -> acknowledged is illegal
    assert_equal "resolved", incident.reload.status
  end
end

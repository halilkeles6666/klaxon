require "test_helper"

# The live store pushes telemetry; Klaxon opens incidents only for the
# components the anomaly detector flags (threshold detector in the test env).
class ApiTelemetryTest < ActionDispatch::IntegrationTest
  test "opens an incident only for the anomalous component" do
    assert_difference -> { Incident.count }, 1 do
      post "/api/telemetry",
        params: { components: {
          "magaza-odeme"  => { error_rate: 22, p95: 180, count: 60, log: "deploy sonrası hata patlaması" },
          "magaza-vitrin" => { error_rate: 0.2, p95: 140, count: 50, log: "normal" }
        } },
        as: :json
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body["opened"].size

    incident = Incident.find_by(reference: body["opened"].first)
    assert_equal "magaza-odeme", incident.service.routing_key
    assert_match(/deploy/, incident.alerts.first.summary)
  end

  test "quiet telemetry opens nothing" do
    assert_no_difference -> { Incident.count } do
      post "/api/telemetry",
        params: { components: { "magaza-odeme" => { error_rate: 0.3, p95: 150, count: 50 } } },
        as: :json
    end
    assert_response :success
  end
end

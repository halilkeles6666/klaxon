require "test_helper"

# External systems (the live Nimbus store) report incidents by routing_key.
class ApiAlertsTest < ActionDispatch::IntegrationTest
  test "ingests an alert by routing_key and returns the incident reference" do
    assert_difference -> { Incident.count }, 1 do
      post "/api/alerts",
        params: { routing_key: "magaza-odeme", title: "Ödeme sorunu", summary: "500 hataları" },
        as: :json
    end
    assert_response :success
    body = JSON.parse(response.body)
    assert body["reference"].start_with?("INC-")

    incident = Incident.find_by(reference: body["reference"])
    assert_equal "magaza-odeme", incident.service.routing_key
    # No NIMBUS_URL in the test env -> the agent does not auto-resolve.
    assert_nil body["resolution"]
  end

  test "an unknown routing_key is rejected" do
    post "/api/alerts", params: { routing_key: "boyle-bir-sey-yok", title: "x" }, as: :json
    assert_response :unprocessable_entity
  end
end

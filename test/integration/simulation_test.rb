require "test_helper"

# The simulation dashboard end to end. No TYPESAFE_API_KEY in the test env, so
# the controller falls back to StubJevClient — no network, no cost.
class SimulationTest < ActionDispatch::IntegrationTest
  def sign_in
    post session_path, params: { email_address: users(:responder).email_address, password: "password" }
  end

  test "dashboard requires authentication" do
    get simulation_path
    assert_redirected_to new_session_path
  end

  test "dashboard renders for a signed-in responder" do
    sign_in
    get simulation_path
    assert_response :success
    assert_select "h1", text: /ajan/i
  end

  test "running the simulation creates incidents the agent has acted on" do
    sign_in
    assert_difference -> { Incident.simulated.count }, 3 do
      post run_simulation_path, params: { count: 3 }
    end
    assert_redirected_to simulation_path

    Incident.simulated.find_each do |incident|
      assert incident.agent_action.present?, "agent should have chosen an action"
      assert incident.resolution_attempts.positive?
    end

    follow_redirect!
    assert_response :success
  end

  test "reset clears simulated incidents" do
    sign_in
    IncidentSimulator.new.generate!(count: 2)
    assert_operator Incident.simulated.count, :>, 0

    post reset_simulation_path
    assert_equal 0, Incident.simulated.count
  end
end

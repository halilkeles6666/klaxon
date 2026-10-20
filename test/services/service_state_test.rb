require "test_helper"

class ServiceStateTest < ActiveSupport::TestCase
  test "a fresh service is healthy" do
    assert ServiceState.new("svc", "Svc").healthy?
  end

  test "a fault degrades health; only the matching action heals it (measured)" do
    ServiceState::FAULTS.each do |fault, cfg|
      state = ServiceState.new("svc", "Svc")
      state.inject_fault!(fault)
      refute state.healthy?, "#{fault} should be unhealthy"
      assert_equal cfg[:fix], state.fix

      wrong = (ServiceState::FAULTS.values.map { |c| c[:fix] } - [ cfg[:fix] ]).first
      state.apply(wrong)
      refute state.healthy?, "#{fault} must NOT be healed by #{wrong}"

      state.apply(cfg[:fix])
      assert state.healthy?, "#{fault} must be healed by #{cfg[:fix]}"
    end
  end

  test "symptoms never name the hidden fault or its fix" do
    state = ServiceState.new("svc", "Svc")
    state.inject_fault!("bad_deploy")
    text = "#{state.alert_title} #{state.alert_summary}"
    refute_match(/bad_deploy|rollback_deploy/, text)
    assert_match(/ölçümler/, state.alert_summary) # carries live metrics
  end
end

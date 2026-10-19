require "test_helper"

class OnCallShiftTest < ActiveSupport::TestCase
  test "covering finds the shift that contains a moment" do
    now = Time.zone.local(2026, 10, 19, 12, 0, 0)
    OnCallShift.create!(user: users(:responder), starts_at: now - 1.hour, ends_at: now + 1.hour)
    OnCallShift.create!(user: users(:admin),     starts_at: now + 1.hour, ends_at: now + 3.hours)

    assert_equal users(:responder), OnCallShift.covering(now).first.user
    assert_equal users(:admin),     OnCallShift.covering(now + 2.hours).first.user
  end

  test "ends_at must be after starts_at" do
    shift = OnCallShift.new(user: users(:responder), starts_at: Time.current, ends_at: Time.current - 1.hour)
    refute shift.valid?
  end

  test "OnCall falls back to a responder when no shift covers now" do
    assert_nil OnCallShift.covering(Time.current).first
    assert_equal "responder", OnCall.on_call_at.role
  end
end

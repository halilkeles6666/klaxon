require "test_helper"

class TelegramNotifierTest < ActiveSupport::TestCase
  test "disabled and skips when no bot token is configured" do
    notifier = TelegramNotifier.new(token: nil, default_chat_id: "123")
    refute notifier.enabled?
    assert_equal :skipped, notifier.notify(user: users(:responder), text: "hi")
  end

  test "skips when there is a token but no chat id anywhere (no network)" do
    users(:responder).update!(telegram_chat_id: nil)
    notifier = TelegramNotifier.new(token: "t", default_chat_id: nil)
    assert notifier.enabled?
    assert_equal :skipped, notifier.notify(user: users(:responder), text: "hi")
  end

  test "uses the user's chat id over the default (still skips without a real token/network)" do
    users(:responder).update!(telegram_chat_id: "999")
    notifier = TelegramNotifier.new(token: "", default_chat_id: "123")
    # token blank -> disabled -> skipped, regardless of chat id
    assert_equal :skipped, notifier.notify(user: users(:responder), text: "hi")
  end
end

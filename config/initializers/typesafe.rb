# Load the TypeSafe / Jev API key from a local, gitignored file when it isn't
# already in the environment. This way `rails server` and `rails console` use
# the real Jev model regardless of which shell launched them (the env var does
# not have to be exported every time).
#
# config/typesafe.key is gitignored and never committed. On Render, set the
# TYPESAFE_API_KEY environment variable instead (the env var wins).
# Never auto-load secrets in the test environment — tests must stay offline
# (StubJevClient for Jev, no Telegram sends).
unless Rails.env.test?
  if ENV["TYPESAFE_API_KEY"].to_s.strip.empty?
    key_file = Rails.root.join("config", "typesafe.key")
    ENV["TYPESAFE_API_KEY"] = key_file.read.strip if key_file.exist?
  end

  # config/telegram.key (gitignored): line 1 = bot token, line 2 (optional) =
  # default chat id used when an on-call user has no telegram_chat_id set.
  telegram_file = Rails.root.join("config", "telegram.key")
  if telegram_file.exist?
    token, default_chat = telegram_file.read.lines.map(&:strip)
    ENV["TELEGRAM_BOT_TOKEN"] = token if ENV["TELEGRAM_BOT_TOKEN"].to_s.strip.empty? && token.present?
    ENV["TELEGRAM_DEFAULT_CHAT_ID"] = default_chat if ENV["TELEGRAM_DEFAULT_CHAT_ID"].to_s.strip.empty? && default_chat.present?
  end
end

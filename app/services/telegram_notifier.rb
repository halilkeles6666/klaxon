require "net/http"
require "json"

# Sends on-call pages over Telegram when the autonomous agent hands an incident
# to a human. Safe by design: if no bot token or no chat id is configured it
# simply skips (returns :skipped) and never raises into the agent. Any network
# error is caught and returned as :error.
#
# Configure via env (loaded from the gitignored config/telegram.key — see
# config/initializers/typesafe.rb):
#   TELEGRAM_BOT_TOKEN       - bot token from @BotFather
#   TELEGRAM_DEFAULT_CHAT_ID - optional fallback chat id when a user has none
#
# Per-user delivery uses User#telegram_chat_id.
class TelegramNotifier
  API_BASE     = "https://api.telegram.org".freeze
  OPEN_TIMEOUT = 4
  READ_TIMEOUT = 6

  def initialize(token: ENV["TELEGRAM_BOT_TOKEN"],
                 default_chat_id: ENV["TELEGRAM_DEFAULT_CHAT_ID"],
                 logger: Rails.logger)
    @token = token.to_s.strip
    @default_chat_id = default_chat_id.to_s.strip
    @logger = logger
  end

  def enabled?
    @token.present?
  end

  # Sends `text` to the user's chat (or the default chat). Returns one of
  # :sent | :skipped | :error. Never raises.
  def notify(user:, text:)
    chat_id = user&.telegram_chat_id.presence || @default_chat_id.presence
    return :skipped unless enabled? && chat_id.present?

    response = post("sendMessage", chat_id: chat_id, text: text)
    if response.is_a?(Net::HTTPSuccess)
      :sent
    else
      @logger&.warn("[Telegram] sendMessage failed: #{response.code} #{response.body.to_s[0, 200]}")
      :error
    end
  rescue => e
    @logger&.warn("[Telegram] error: #{e.class}: #{e.message}")
    :error
  end

  private

  def post(method, payload)
    uri  = URI("#{API_BASE}/bot#{@token}/#{method}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl      = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    req = Net::HTTP::Post.new(uri)
    req["Content-Type"] = "application/json"
    req.body = JSON.generate(payload)
    http.request(req)
  end
end

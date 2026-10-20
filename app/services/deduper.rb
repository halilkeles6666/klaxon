# Picks the deduplication strategy. Uses the LLM (Jev) when a key is configured
# and we are not in tests; otherwise the exact-key strategy (offline, cheap,
# deterministic for tests).
module Deduper
  module_function

  def default
    if ENV["TYPESAFE_API_KEY"].to_s.strip.present? && !Rails.env.test?
      JevDeduper.new
    else
      KeyDeduper.new
    end
  end
end

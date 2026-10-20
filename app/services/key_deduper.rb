# Classic deduplication: group a new alert into an open incident only when it
# carries the exact same dedup_key. Used in tests/offline and as the fallback
# when the LLM deduper is unavailable.
class KeyDeduper
  def find_match(service:, key:, **)
    service.incidents.open.find_by(dedup_key: key)
  end
end

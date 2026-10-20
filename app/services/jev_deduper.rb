# LLM-based deduplication (the teacher's "use an LLM instead of a keyword").
# Instead of matching a literal dedup_key, it asks Jev whether the new alert
# describes the SAME ongoing problem as one of the currently-open incidents.
# This groups semantically related alerts even when their keys/wording differ,
# and keeps unrelated ones apart. Falls back to KeyDeduper if Jev is unavailable.
class JevDeduper
  CONFIDENCE_FLOOR = 0.5
  MAX_CANDIDATES   = 10

  def initialize(jev: JevClient.new, fallback: KeyDeduper.new)
    @jev = jev
    @fallback = fallback
  end

  def find_match(service:, title:, summary:, key:)
    open = service.incidents.open.newest_first.limit(MAX_CANDIDATES).to_a
    return nil if open.empty?

    options = {}
    open.each_with_index do |incident, i|
      last = incident.alerts.chronological.last&.summary
      options["olay_#{i}"] = "#{incident.title} — #{last || incident.title}"
    end
    options["none"] = "Yukarıdakilerin hiçbiriyle aynı değil — ayrı/yeni bir problem."

    result = @jev.evaluate(
      state: "Yeni alarm: #{title}. #{summary}",
      questions: {
        match: JevClient::Jev.choice(
          "Bu yeni alarm, aşağıdaki açık olaylardan hangisiyle AYNI devam eden problemi anlatıyor?",
          options)
      })

    pick = result.choice(:match)
    return nil if pick == "none" || result.confidence(:match).to_f < CONFIDENCE_FLOOR

    open[pick.to_s.sub("olay_", "").to_i]
  rescue JevClient::Error
    @fallback.find_match(service: service, title: title, summary: summary, key: key)
  end
end

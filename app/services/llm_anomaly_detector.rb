# LLM-based anomaly detection: instead of a fixed threshold, Jev judges whether
# a component's measured telemetry (compared to its normal baseline) is an
# anomaly worth opening an incident for. Catches context a threshold misses — a
# sharp jump that is still under the limit, a slow climb, etc. Falls back to the
# threshold detector if Jev is unavailable.
class LlmAnomalyDetector
  FLOOR = 0.6

  # The store's healthy baseline (normal operation), given to Jev for context.
  BASELINE = "normalde hata ~%0.3, p95 ~140ms, istikrarlı".freeze

  def initialize(jev: JevClient.new, fallback: ThresholdDetector.new)
    @jev = jev
    @fallback = fallback
  end

  def anomalous?(component_name:, stats:)
    result = @jev.evaluate(
      state: "Servis: #{component_name} (#{BASELINE}). " \
             "Son 90 saniyede ölçülen: #{stats[:count]} istek, " \
             "hata %#{stats[:error_rate]}, p95 #{stats[:p95_ms]}ms.",
      questions: {
        anomaly: JevClient::Jev.noul(
          "Bu telemetri normal davranıştan anormal sapma gösteriyor ve bir olay açılmasını gerektiriyor.")
      })
    result.noul(:anomaly) >= FLOOR
  rescue JevClient::Error
    @fallback.anomalous?(component_name: component_name, stats: stats)
  end
end

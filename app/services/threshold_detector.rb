# Classic rule-based anomaly detection: a component is anomalous if its measured
# error rate or p95 latency crosses a fixed threshold. Cheap, deterministic,
# used offline/in tests and as the fallback for the LLM detector.
class ThresholdDetector
  ERROR_THRESHOLD = 5.0  # percent
  P95_THRESHOLD   = 1000 # ms

  def anomalous?(component_name:, stats:)
    stats[:error_rate] >= ERROR_THRESHOLD || stats[:p95_ms] >= P95_THRESHOLD
  end
end

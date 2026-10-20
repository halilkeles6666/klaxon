require "test_helper"

class AnomalyDetectorTest < ActiveSupport::TestCase
  def stats(error_rate:, p95_ms:, count: 30)
    { count: count, error_rate: error_rate, p95_ms: p95_ms }
  end

  test "threshold detector flags high error rate or high latency, not normal" do
    detector = ThresholdDetector.new
    assert detector.anomalous?(component_name: "x", stats: stats(error_rate: 12.0, p95_ms: 150))
    assert detector.anomalous?(component_name: "x", stats: stats(error_rate: 0.1, p95_ms: 2200))
    refute detector.anomalous?(component_name: "x", stats: stats(error_rate: 1.0, p95_ms: 200))
  end

  test "LLM detector flags when Jev's probability is above the floor" do
    jev = StubJevClient.new { |_s, _q| { "anomaly" => { "type" => "noul", "noul" => 0.9 } } }
    # error 3% is UNDER the threshold, but the LLM still flags the anomaly.
    assert LlmAnomalyDetector.new(jev: jev).anomalous?(component_name: "x", stats: stats(error_rate: 3.0, p95_ms: 200))
  end

  test "LLM detector does not flag below the floor" do
    jev = StubJevClient.new { |_s, _q| { "anomaly" => { "type" => "noul", "noul" => 0.2 } } }
    refute LlmAnomalyDetector.new(jev: jev).anomalous?(component_name: "x", stats: stats(error_rate: 3.0, p95_ms: 200))
  end

  test "LLM detector falls back to the threshold when Jev errors" do
    raising = Object.new
    def raising.evaluate(**) = raise JevClient::Error, "boom"
    detector = LlmAnomalyDetector.new(jev: raising)

    assert detector.anomalous?(component_name: "x", stats: stats(error_rate: 20.0, p95_ms: 150))
    refute detector.anomalous?(component_name: "x", stats: stats(error_rate: 1.0, p95_ms: 150))
  end
end

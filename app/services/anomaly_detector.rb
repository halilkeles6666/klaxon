# Picks the anomaly-detection strategy: the LLM (Jev) when a key is configured
# and we are not in tests, otherwise the deterministic threshold detector.
module AnomalyDetector
  module_function

  def default
    if ENV["TYPESAFE_API_KEY"].to_s.strip.present? && !Rails.env.test?
      LlmAnomalyDetector.new
    else
      ThresholdDetector.new
    end
  end
end

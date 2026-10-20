# One real request served by the fake store (Nimbus). The monitor reads recent
# windows of these to decide, from measured telemetry, whether a component is
# having an incident.
class RequestLog < ApplicationRecord
  scope :recent, ->(since = 2.minutes.ago) { where("created_at >= ?", since) }
  scope :for_component, ->(c) { where(component: c) }

  def self.record!(component:, path:, status:, latency_ms:)
    create!(component: component, path: path, status: status,
            latency_ms: latency_ms, created_at: Time.current)
  end

  # Telemetry summary for a component over a window: request count, error rate,
  # and p95 latency — the numbers the monitor/agent reason about.
  def self.window_stats(component, since = 90.seconds.ago)
    rows = for_component(component).recent(since).pluck(:status, :latency_ms)
    return nil if rows.empty?

    total   = rows.size
    errors  = rows.count { |status, _| status >= 500 }
    latency = rows.map(&:last).sort
    p95 = latency[(latency.size * 0.95).ceil - 1] || latency.last
    { count: total, error_rate: (errors * 100.0 / total).round(1), p95_ms: p95 }
  end
end

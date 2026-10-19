# Dashboard for the autonomous agent->agent experiment. Lists simulated
# incidents with the agent's Jev-driven decisions and scores its accuracy.
# The "Run" button fabricates incidents and lets the agent resolve them inline
# (synchronous — fine for a demo of a handful of incidents).
class SimulationController < ApplicationController
  def index
    @incidents = Incident.simulated.newest_first.includes(:service)
    @stats = build_stats(@incidents)
    @using_jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present?
  end

  def run
    count = params.fetch(:count, 5).to_i.clamp(1, 20)

    jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present? ? JevClient.new : StubJevClient.new
    agent = ResolutionAgent.new(jev: jev, world: ActionWorld.new)

    incidents = IncidentSimulator.new.generate!(count: count)
    incidents.each { |incident| agent.resolve!(incident) }

    redirect_to simulation_path, notice: "#{count} olay üretildi ve ajana verildi."
  rescue JevClient::Error => e
    redirect_to simulation_path, alert: "Jev hatası: #{e.message}"
  end

  def reset
    Incident.simulated.destroy_all
    redirect_to simulation_path, notice: "Simüle olaylar temizlendi."
  end

  private

  def build_stats(incidents)
    total = incidents.size
    return { total: 0 } if total.zero?

    resolved = incidents.count { |i| i.status == "resolved" }
    correct  = incidents.count(&:agent_action_correct?)
    confs    = incidents.filter_map(&:agent_confidence)
    {
      total: total,
      resolved: resolved,
      resolved_pct: (resolved * 100.0 / total).round,
      correct: correct,
      correct_pct: (correct * 100.0 / total).round,
      avg_conf: confs.any? ? (confs.sum / confs.size * 100).round : nil
    }
  end
end

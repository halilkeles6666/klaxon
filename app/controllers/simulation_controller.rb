# Dashboard for the autonomous agent->agent experiment. Lists simulated
# incidents with the agent's Jev-driven decisions, scores its accuracy, and
# shows when the agent handed an incident to the on-call human.
#
#   index : the dashboard
#   run   : fabricate N incidents and let the agent resolve them (bulk)
#   tick  : fabricate ONE incident and resolve it, return the refreshed board
#           (used by the live/auto mode on the dashboard)
#   reset : delete all simulated incidents
class SimulationController < ApplicationController
  def index
    load_board
  end

  def run
    count = params.fetch(:count, 5).to_i.clamp(1, 20)
    agent = build_agent
    IncidentSimulator.new.generate!(count: count).each { |i| agent.resolve!(i) }
    redirect_to simulation_path, notice: "#{count} olay üretildi ve ajana verildi."
  rescue JevClient::Error => e
    redirect_to simulation_path, alert: "Jev hatası: #{e.message}"
  end

  # One incident at a time — the heartbeat of live mode. Returns just the board.
  def tick
    incident = IncidentSimulator.new.generate!(count: 1).first
    build_agent.resolve!(incident)
    load_board
    render partial: "simulation/board"
  rescue JevClient::Error => e
    render plain: "Jev hatası: #{e.message}", status: :bad_gateway
  end

  def reset
    Incident.simulated.destroy_all
    redirect_to simulation_path, notice: "Simüle olaylar temizlendi."
  end

  private

  def build_agent
    jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present? ? JevClient.new : StubJevClient.new
    ResolutionAgent.new(jev: jev, world: ActionWorld.new)
  end

  def load_board
    @incidents = Incident.simulated.newest_first.includes(:service, :paged_user)
    @stats     = build_stats(@incidents)
    @using_jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present?
    @on_call   = OnCall.on_call_at
  end

  def build_stats(incidents)
    total = incidents.size
    return { total: 0 } if total.zero?

    resolved  = incidents.count { |i| i.status == "resolved" }
    escalated = incidents.count(&:needs_human)
    correct   = incidents.count(&:agent_action_correct?)
    confs     = incidents.filter_map(&:agent_confidence)
    {
      total: total,
      resolved: resolved,
      resolved_pct: (resolved * 100.0 / total).round,
      escalated: escalated,
      correct: correct,
      correct_pct: (correct * 100.0 / total).round,
      avg_conf: confs.any? ? (confs.sum / confs.size * 100).round : nil
    }
  end
end

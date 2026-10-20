# Dashboard for the autonomous agent->agent experiment. Lists simulated
# incidents with the agent's Jev-driven decisions, scores its accuracy, and
# shows when the agent handed an incident to the on-call human.
#
#   index  : the dashboard (also exposes a form to submit your own incident)
#   run    : fabricate N incidents and let the agent resolve them (bulk)
#   tick   : fabricate ONE incident and resolve it, return the refreshed board
#   submit : take a free-text incident from the user and let the agent solve it
#            (outcome judged by Jev, since there is no hidden ground truth)
#   reset  : delete all simulated incidents
class SimulationController < ApplicationController
  def index
    IncidentSimulator.new.ensure_services! # make sure services + on-call exist
    load_board
  end

  # Real closed loop: break real services -> monitor detects from metrics ->
  # agent asks Jev -> applies the remediation to the live world -> health is
  # re-measured. "Resolved" means the service actually recovered.
  def run
    count = params.fetch(:count, 5).to_i.clamp(1, 20)
    incidents = detect_and_resolve!(count)
    redirect_to simulation_path, notice: "#{incidents.size} gerçek arıza üretildi, saptandı ve ajana verildi."
  rescue JevClient::Error => e
    redirect_to simulation_path, alert: "Jev hatası: #{e.message}"
  end

  def tick
    detect_and_resolve!(1)
    load_board
    render partial: "simulation/board"
  rescue JevClient::Error => e
    render plain: "Jev hatası: #{e.message}", status: :bad_gateway
  end

  # The user types their own incident; the agent solves it, with Jev judging
  # whether each remediation actually works (no hidden ground truth).
  def submit
    service = Service.active.find_by(id: params[:service_id]) || Service.active.order(:name).first
    title   = params[:title].to_s.strip

    if service.nil?
      redirect_to simulation_path, alert: "Önce bir simülasyon çalıştırın (servis yok)." and return
    end
    if title.blank?
      redirect_to simulation_path, alert: "Olay başlığı gerekli." and return
    end

    incident, = Incident.ingest(
      service: service,
      dedup_key: "user-#{SecureRandom.hex(3)}",
      title: title,
      summary: params[:details].to_s.strip.presence || title,
      urgency: params[:urgency].presence || "high",
      source: "user")
    incident.update!(simulated: true) # root_cause_action stays nil = user-provided

    build_agent(world: JevWorld.new(jev: build_jev)).resolve!(incident)
    redirect_to incident_path(incident), notice: "Olayın ajana verildi — aşağıda ne yaptığını gör."
  rescue JevClient::Error => e
    redirect_to simulation_path, alert: "Jev hatası: #{e.message}"
  end

  def reset
    Incident.simulated.destroy_all
    redirect_to simulation_path, notice: "Simüle olaylar temizlendi."
  end

  private

  # Inject faults into a fresh live world, let the monitor detect them, and let
  # the agent resolve each against that same world (so health feedback is real).
  def detect_and_resolve!(count)
    IncidentSimulator.new.ensure_services! # services + on-call exist
    world = SimulatedWorld.new
    world.inject_random_faults!(count)
    incidents = WorldMonitor.new(world).detect!
    agent = build_agent(world: world)
    incidents.each { |incident| agent.resolve!(incident) }
    incidents
  end

  def build_jev
    ENV["TYPESAFE_API_KEY"].to_s.strip.present? ? JevClient.new : StubJevClient.new
  end

  def build_agent(world: ActionWorld.new)
    ResolutionAgent.new(jev: build_jev, world: world)
  end

  def load_board
    @incidents = Incident.simulated.newest_first.includes(:service, :paged_user)
    @services  = Service.active.order(:name)
    @stats     = build_stats(@incidents)
    @using_jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present?
    @on_call   = OnCall.on_call_at
  end

  def build_stats(incidents)
    total = incidents.size
    return { total: 0 } if total.zero?

    resolved  = incidents.count { |i| i.status == "resolved" }
    escalated = incidents.count(&:needs_human)
    scored    = incidents.select { |i| i.root_cause_action.present? } # excludes user-provided
    correct   = scored.count(&:agent_action_correct?)
    confs     = incidents.filter_map(&:agent_confidence)
    {
      total: total,
      resolved: resolved,
      resolved_pct: (resolved * 100.0 / total).round,
      escalated: escalated,
      scored: scored.size,
      correct: correct,
      correct_pct: scored.any? ? (correct * 100.0 / scored.size).round : nil,
      avg_conf: confs.any? ? (confs.sum / confs.size * 100).round : nil
    }
  end
end

# Responder workspace for triaging incidents. Authentication is required
# (inherited from ApplicationController's before_action).
class IncidentsController < ApplicationController
  before_action :set_incident, only: %i[show acknowledge resolve reopen]

  def index
    @status = params[:status].presence
    scope = Incident.by_status(@status).newest_first.includes(:service)
    # Apply the escalation time rule lazily on read so the queue reflects the
    # current level without a background worker (see README "Yapamadıklarım").
    Incident.open.includes(:service).find_each(&:apply_escalations!)
    @incidents = scope
    @counts = Incident.group(:status).count
  end

  def show
    @incident.apply_escalations!
    @events = @incident.incident_events.chronological.includes(:actor)
    @alerts = @incident.alerts.chronological
  end

  def acknowledge
    if @incident.acknowledge!(current_user)
      redirect_to @incident, notice: "Olay onaylandı — eskalasyon durduruldu."
    else
      redirect_to @incident, alert: @incident.errors.full_messages.to_sentence
    end
  end

  def resolve
    if @incident.resolve!(current_user)
      redirect_to @incident, notice: "Olay çözüldü olarak işaretlendi."
    else
      redirect_to @incident, alert: @incident.errors.full_messages.to_sentence
    end
  end

  def reopen
    if @incident.reopen!(current_user)
      redirect_to @incident, notice: "Olay yeniden açıldı — eskalasyon saati sıfırlandı."
    else
      redirect_to @incident, alert: @incident.errors.full_messages.to_sentence
    end
  end

  private

  def set_incident
    @incident = Incident.find(params[:id])
  end
end

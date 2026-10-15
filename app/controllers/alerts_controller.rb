# Public alert intake. No authentication: this simulates a monitoring tool
# (Datadog, Prometheus, a health check...) POSTing an alert to Klaxon. An
# alert either opens a new incident or is grouped into an open one.
class AlertsController < ApplicationController
  allow_unauthenticated_access only: %i[new create received]

  def new
    @services = Service.active.order(:name)
    @service_id = params[:service_id]
  end

  def create
    service = Service.active.find_by(id: alert_params[:service_id])
    if service.nil?
      @services = Service.active.order(:name)
      flash.now[:alert] = "Lütfen geçerli bir servis seçin."
      return render :new, status: :unprocessable_entity
    end

    if alert_params[:title].blank?
      @services = Service.active.order(:name)
      @service_id = service.id
      flash.now[:alert] = "Alarm başlığı gerekli."
      return render :new, status: :unprocessable_entity
    end

    incident, outcome = Incident.ingest(
      service: service,
      dedup_key: alert_params[:dedup_key],
      title: alert_params[:title],
      summary: alert_params[:summary],
      urgency: alert_params[:urgency].presence || "high",
      source: "manual"
    )

    redirect_to alert_received_path(incident.reference, outcome: outcome)
  end

  def received
    @incident = Incident.find_by!(reference: params[:reference])
    @outcome = params[:outcome]
  end

  private

  def alert_params
    params.require(:alert).permit(:service_id, :title, :summary, :dedup_key, :urgency)
  end
end

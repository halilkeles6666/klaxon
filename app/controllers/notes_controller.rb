# Responders add free-text notes to an incident's timeline.
class NotesController < ApplicationController
  def create
    incident = Incident.find(params[:incident_id])
    detail = params.dig(:note, :detail).to_s.strip

    if detail.present?
      incident.log_event("note", detail: detail, actor: current_user)
      redirect_to incident, notice: "Not eklendi."
    else
      redirect_to incident, alert: "Not boş olamaz."
    end
  end
end

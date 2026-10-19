# One entry on an incident's timeline (what happened and who did it).
class IncidentEvent < ApplicationRecord
  KINDS = %w[triggered alert_grouped escalated acknowledged resolved reopened note
             agent_assessed agent_action_failed agent_resolved agent_gave_up
             human_paged].freeze

  belongs_to :incident
  belongs_to :actor, class_name: "User", optional: true

  validates :kind, inclusion: { in: KINDS }

  scope :chronological, -> { order(:created_at) }
end

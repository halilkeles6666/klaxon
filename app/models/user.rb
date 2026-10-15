class User < ApplicationRecord
  ROLES = %w[responder admin].freeze

  has_secure_password
  has_many :sessions, dependent: :destroy
  has_many :acknowledged_incidents, class_name: "Incident",
           foreign_key: :acknowledged_by_id, dependent: :nullify
  has_many :incident_events, foreign_key: :actor_id, dependent: :nullify

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :name, presence: true
  validates :role, inclusion: { in: ROLES }

  def admin?
    role == "admin"
  end

  def display_name
    name.presence || email_address
  end
end

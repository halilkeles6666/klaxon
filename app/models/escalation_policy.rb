# Defines the on-call time rule for a service: how long an incident may sit
# unacknowledged before Klaxon escalates it to the next level.
class EscalationPolicy < ApplicationRecord
  has_many :services, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: true
  validates :ack_timeout_minutes, numericality: { only_integer: true, greater_than: 0 }
  validates :max_level, numericality: { only_integer: true, greater_than_or_equal_to: 1 }

  scope :active, -> { where(active: true) }
end

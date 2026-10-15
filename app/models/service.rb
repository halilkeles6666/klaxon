# A monitored service. Monitoring tools send alerts to its routing_key;
# Klaxon turns those alerts into incidents under the service's escalation policy.
class Service < ApplicationRecord
  belongs_to :escalation_policy
  has_many :incidents, dependent: :destroy

  normalizes :routing_key, with: ->(k) { k.to_s.strip.downcase }

  validates :name, presence: true
  validates :routing_key, presence: true, uniqueness: true,
            format: { with: /\A[a-z0-9][a-z0-9-]*\z/,
                      message: "yalnızca küçük harf, rakam ve tire içerebilir" }

  scope :active, -> { where(active: true) }

  def ack_timeout_minutes
    escalation_policy.ack_timeout_minutes
  end

  def max_level
    escalation_policy.max_level
  end
end

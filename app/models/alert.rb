# A single alert signal from a monitoring tool. Many alerts may be grouped
# into one incident (see Incident.ingest) — those carry deduplicated: true.
class Alert < ApplicationRecord
  belongs_to :incident, counter_cache: :alerts_count

  validates :summary, presence: true

  scope :chronological, -> { order(:created_at) }
end

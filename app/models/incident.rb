class Incident < ApplicationRecord
  STATUSES  = %w[triggered acknowledged resolved].freeze
  URGENCIES = %w[high low].freeze

  # The aort dilimi (core workflow) status machine. An incident may only move
  # along these edges; anything else is rejected by #transition_to!.
  #   triggered ─▶ acknowledged ─▶ resolved
  #        ▲            │               │
  #        └── reopen ──┴─────── reopen ─┘
  TRANSITIONS = {
    "triggered"    => %w[acknowledged resolved],
    "acknowledged" => %w[resolved triggered],
    "resolved"     => %w[triggered]
  }.freeze

  belongs_to :service
  belongs_to :acknowledged_by, class_name: "User", optional: true
  belongs_to :paged_user, class_name: "User", optional: true
  has_many :alerts, dependent: :destroy
  has_many :incident_events, -> { order(:created_at) }, dependent: :destroy

  validates :title, presence: true
  validates :dedup_key, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :urgency, inclusion: { in: URGENCIES }

  before_validation :set_defaults, on: :create
  before_validation :assign_reference, on: :create

  scope :open,      -> { where.not(status: "resolved") }
  scope :resolved,  -> { where(status: "resolved") }
  scope :triggered, -> { where(status: "triggered") }
  scope :by_status, ->(s) { where(status: s) if s.present? }
  scope :newest_first, -> { order(triggered_at: :desc) }
  scope :simulated, -> { where(simulated: true) }
  scope :needs_human, -> { where(needs_human: true) }

  # Simulation scoring: did the agent end up applying the action that actually
  # fixes this incident? (root_cause_action is hidden ground truth.)
  def agent_action_correct?
    root_cause_action.present? && agent_action == root_cause_action
  end

  # ---- Alert ingestion + deduplication (noise reduction) -----------------
  #
  # Monitoring tools fire an alert per check, so a single outage can emit
  # dozens of identical alerts. Instead of opening (and paging for) a new
  # incident each time, Klaxon groups repeat alerts that share the same
  # (service, dedup_key) into the one incident that is still open.
  #
  # Returns [incident, :created | :grouped].
  def self.ingest(service:, dedup_key:, title:, summary: nil, urgency: "high", source: nil, now: Time.current)
    key = dedup_key.to_s.strip.downcase.presence || title.to_s.parameterize.presence || "alert"
    summary ||= title

    existing = service.incidents.open.find_by(dedup_key: key)
    if existing
      existing.alerts.create!(summary: summary, source: source, deduplicated: true)
      existing.log_event("alert_grouped",
        detail: "Yinelenen alarm mevcut olaya eklendi (bastırıldı): #{summary}")
      [ existing, :grouped ]
    else
      incident = new(
        service: service, dedup_key: key, title: title,
        urgency: URGENCIES.include?(urgency) ? urgency : "high",
        status: "triggered", triggered_at: now, escalation_level: 1
      )
      incident.save!
      incident.alerts.create!(summary: summary, source: source, deduplicated: false)
      incident.log_event("triggered", detail: "Olay açıldı: #{summary}")
      [ incident, :created ]
    end
  end

  # ---- Status transitions -------------------------------------------------

  def available_transitions
    TRANSITIONS.fetch(status, [])
  end

  def can_transition_to?(new_status)
    available_transitions.include?(new_status.to_s)
  end

  def open?
    status != "resolved"
  end

  def unacknowledged?
    status == "triggered"
  end

  # Move the incident along the status machine, applying side effects and
  # recording a timeline event. Returns true, or false on an illegal move.
  def transition_to!(new_status, actor: nil, now: Time.current)
    new_status = new_status.to_s
    unless can_transition_to?(new_status)
      errors.add(:status, "#{status} durumundan #{new_status} durumuna geçilemez")
      return false
    end
    previous = status
    apply_status_side_effects(new_status, actor, now)
    self.status = new_status
    save!
    log_event(event_kind_for(previous, new_status), actor: actor)
    true
  end

  def acknowledge!(actor, now: Time.current) = transition_to!("acknowledged", actor: actor, now: now)
  def resolve!(actor, now: Time.current)     = transition_to!("resolved", actor: actor, now: now)
  def reopen!(actor, now: Time.current)      = transition_to!("triggered", actor: actor, now: now)

  # ---- Time rule: escalation timeout -------------------------------------
  #
  # While an incident stays unacknowledged (triggered) it escalates one level
  # every ack_timeout_minutes, up to the policy's max_level, raising urgency to
  # high. Acknowledging it stops the clock.

  def ack_timeout_minutes
    service.ack_timeout_minutes
  end

  def max_level
    service.max_level
  end

  def escalatable?
    status == "triggered" && escalation_level < max_level
  end

  # Deadline at which the CURRENT level escalates to the next one.
  def escalate_at
    return nil unless triggered_at
    triggered_at + (escalation_level * ack_timeout_minutes).minutes
  end

  # Signed minutes until the next escalation (negative = overdue), or nil when
  # the clock no longer runs (acknowledged/resolved or already at max level).
  def minutes_until_escalation(now = Time.current)
    return nil unless escalatable?
    ((escalate_at - now) / 60.0).ceil
  end

  def escalation_due?(now = Time.current)
    escalatable? && now >= escalate_at
  end

  # Advance the escalation level to reflect how long the incident has gone
  # unacknowledged. Idempotent: safe to call on every read. Returns true if it
  # escalated.
  def apply_escalations!(now = Time.current)
    return false unless escalatable?

    elapsed_minutes = ((now - triggered_at) / 60.0).floor
    target_level = [ 1 + (elapsed_minutes / ack_timeout_minutes), max_level ].min
    return false if target_level <= escalation_level

    while escalation_level < target_level
      self.escalation_level += 1
      self.urgency = "high"
      self.escalated_at = triggered_at + ((escalation_level - 1) * ack_timeout_minutes).minutes
      save!
      log_event("escalated", detail: "Onaylanmadı — seviye #{escalation_level}'e yükseltildi")
    end
    true
  end

  # ---- Timeline -----------------------------------------------------------

  def log_event(kind, detail: nil, actor: nil)
    incident_events.create!(kind: kind, detail: detail, actor: actor)
  end

  def duplicate_alerts_count
    [ alerts_count - 1, 0 ].max
  end

  private

  def set_defaults
    self.status ||= "triggered"
    self.urgency ||= "high"
    self.escalation_level ||= 1
    self.triggered_at ||= Time.current
  end

  def apply_status_side_effects(new_status, actor, now)
    case new_status
    when "acknowledged"
      self.acknowledged_at = now
      self.acknowledged_by = actor
    when "resolved"
      self.resolved_at = now
    when "triggered" # reopen or unacknowledge: restart the escalation clock
      self.triggered_at = now
      self.escalation_level = 1
      self.acknowledged_at = nil
      self.acknowledged_by = nil
      self.resolved_at = nil
      self.escalated_at = nil
    end
  end

  def event_kind_for(previous, new_status)
    return "reopened" if new_status == "triggered"
    new_status # "acknowledged" | "resolved"
  end

  def assign_reference
    return if reference.present?
    loop do
      candidate = "INC-#{SecureRandom.random_number(900_000) + 100_000}"
      break self.reference = candidate unless Incident.exists?(reference: candidate)
    end
  end
end

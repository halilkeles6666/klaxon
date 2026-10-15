module IncidentsHelper
  STATUS_LABELS = {
    "triggered" => "Tetiklendi", "acknowledged" => "Onaylandı", "resolved" => "Çözüldü"
  }.freeze

  URGENCY_LABELS = { "high" => "Yüksek", "low" => "Düşük" }.freeze

  EVENT_LABELS = {
    "triggered"     => "Olay açıldı",
    "alert_grouped" => "Yinelenen alarm gruplandı",
    "escalated"     => "Yükseltildi",
    "acknowledged"  => "Onaylandı",
    "resolved"      => "Çözüldü",
    "reopened"      => "Yeniden açıldı",
    "note"          => "Not"
  }.freeze

  def status_label(status)
    STATUS_LABELS.fetch(status, status)
  end

  def status_pill(status)
    tag.span(status_label(status), class: "pill pill--#{status}")
  end

  def urgency_label(urgency)
    URGENCY_LABELS.fetch(urgency, urgency)
  end

  def urgency_tag(urgency)
    tag.span(urgency_label(urgency), class: "prio prio--#{urgency}")
  end

  def event_label(kind)
    EVENT_LABELS.fetch(kind, kind)
  end

  # Compact "2s 5d" style string from a minute count.
  def humanize_minutes(mins)
    mins = mins.abs
    hours = mins / 60
    minutes = mins % 60
    parts = []
    parts << "#{hours}s" if hours.positive?
    parts << "#{minutes}d" if minutes.positive? || parts.empty?
    parts.join(" ")
  end

  # Escalation countdown / status badge for the queue and detail pages.
  def escalation_badge(incident)
    case incident.status
    when "resolved"
      return tag.span("Çözüldü", class: "sla sla--ok")
    when "acknowledged"
      who = incident.acknowledged_by&.display_name
      return tag.span(who ? "#{who} onayladı" : "Onaylandı", class: "sla sla--paused")
    end

    # triggered
    remaining = incident.minutes_until_escalation
    if remaining.nil? # at max level
      tag.span("Seviye #{incident.escalation_level} (azami)", class: "sla sla--breached")
    elsif remaining <= 0
      tag.span("Yükseltme gecikti", class: "sla sla--breached")
    elsif remaining <= 5
      tag.span("#{humanize_minutes(remaining)} içinde yükselir", class: "sla sla--soon")
    else
      tag.span("#{humanize_minutes(remaining)} içinde yükselir", class: "sla sla--ok")
    end
  end

  def level_tag(incident)
    cls = incident.escalation_level > 1 ? "lvl lvl--high" : "lvl"
    tag.span("Sv #{incident.escalation_level}/#{incident.max_level}", class: cls)
  end
end

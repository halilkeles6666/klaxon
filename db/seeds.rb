# Klaxon seed data — idempotent, safe to run repeatedly.
# Escalation times below are wall-clock minutes (incident response is 24/7).

policies = {
  "Kritik"         => { ack_timeout_minutes: 5,  max_level: 3 },
  "Standart"       => { ack_timeout_minutes: 15, max_level: 3 },
  "Düşük öncelik"  => { ack_timeout_minutes: 60, max_level: 2 }
}
policies.each do |name, attrs|
  policy = EscalationPolicy.find_or_initialize_by(name: name)
  policy.update!(attrs.merge(active: true))
end

services = {
  "payments-api" => { name: "Ödeme API",    policy: "Kritik" },
  "web-frontend" => { name: "Web Ön Yüz",    policy: "Standart" },
  "email-batch"  => { name: "Toplu E-posta", policy: "Düşük öncelik" }
}
services.each do |key, attrs|
  svc = Service.find_or_initialize_by(routing_key: key)
  svc.update!(name: attrs[:name], escalation_policy: EscalationPolicy.find_by!(name: attrs[:policy]), active: true)
end

responder = User.find_or_initialize_by(email_address: "responder@klaxon.test")
responder.update!(name: "Demo Responder", role: "responder", password: "password", password_confirmation: "password")

admin = User.find_or_initialize_by(email_address: "admin@klaxon.test")
admin.update!(name: "Demo Admin", role: "admin", password: "password", password_confirmation: "password")

if Incident.count.zero?
  payments = Service.find_by!(routing_key: "payments-api")
  web      = Service.find_by!(routing_key: "web-frontend")
  email    = Service.find_by!(routing_key: "email-batch")

  # 1) Unacknowledged long enough to have escalated to the top level.
  esc, = Incident.ingest(service: payments, dedup_key: "pay-5xx",
    title: "Ödeme API yüksek 5xx oranı", summary: "/charge üzerinde %18 hata",
    urgency: "high", now: 22.minutes.ago)
  esc.apply_escalations!

  # 2) One incident that absorbed repeat alerts (noise reduction demo).
  web_inc, = Incident.ingest(service: web, dedup_key: "web-latency",
    title: "Web ön yüz yüksek gecikme", summary: "p95 2.4s", urgency: "high",
    now: 8.minutes.ago)
  3.times do |i|
    Incident.ingest(service: web, dedup_key: "web-latency",
      title: "Web ön yüz yüksek gecikme", summary: "p95 tekrar ölçümü ##{i + 1}",
      now: (6 - i).minutes.ago)
  end

  # 3) Acknowledged, being worked on.
  ack, = Incident.ingest(service: payments, dedup_key: "pay-latency",
    title: "Ödeme API yavaş yanıt", summary: "p99 3.1s", now: 10.minutes.ago)
  ack.acknowledge!(responder, now: 9.minutes.ago)
  ack.log_event("note", detail: "Veritabanı bağlantı havuzu inceleniyor.", actor: responder)

  # 4) Resolved.
  done, = Incident.ingest(service: email, dedup_key: "email-queue",
    title: "E-posta kuyruğu birikti", summary: "Kuyruk 12k", now: 90.minutes.ago)
  done.acknowledge!(responder, now: 80.minutes.ago)
  done.resolve!(responder, now: 20.minutes.ago)
end

puts "Seeded: #{EscalationPolicy.count} policies, #{Service.count} services, " \
     "#{User.count} users, #{Incident.count} incidents, #{Alert.count} alerts."

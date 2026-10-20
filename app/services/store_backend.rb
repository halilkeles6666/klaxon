# The backend of the fake company store (Nimbus). Every store request goes
# through #serve: if the component has an active fault it genuinely returns an
# error / is slow, and every request is written to RequestLog (real telemetry).
#
# Components are real Service records so Klaxon can open incidents against them.
module StoreBackend
  module_function

  COMPONENTS = {
    "magaza-vitrin"  => "Nimbus Vitrin",
    "magaza-katalog" => "Nimbus Katalog",
    "magaza-odeme"   => "Nimbus Ödeme",
    "magaza-db"      => "Nimbus Veritabanı"
  }.freeze

  # Make sure each store component exists as a Service (so incidents attach).
  def ensure_components!
    policy = EscalationPolicy.find_or_create_by!(name: "Nimbus") do |p|
      p.ack_timeout_minutes = 5
      p.max_level = 3
      p.active = true
    end
    COMPONENTS.each do |key, name|
      Service.find_or_create_by!(routing_key: key) do |svc|
        svc.name = name
        svc.escalation_policy = policy
        svc.active = true
      end
    end
  end

  # Serve one request through a component. Returns { status:, latency_ms:, ok:,
  # fault: } and records telemetry. The faulted component really errors/slows.
  def serve(component, path)
    fault = SiteFault.active_for(component)&.fault
    status, latency = outcome(fault)
    RequestLog.record!(component: component, path: path, status: status, latency_ms: latency)
    { status: status, latency_ms: latency, ok: status < 500, fault: fault }
  end

  # Map a fault to a realistic (status, latency). Random so telemetry looks real.
  def outcome(fault)
    case fault
    when nil            then [ 200, rand(70..180) ]
    when "bad_deploy"   then [ rand < 0.8 ? 500 : 200, rand(90..200) ]   # 500s after deploy
    when "crashed"      then [ 503, rand(10..40) ]                       # process down
    when "primary_down" then [ 500, rand(20..60) ]                       # DB unreachable
    when "overloaded"   then [ rand < 0.15 ? 500 : 200, rand(1600..3200) ] # slow under load
    when "queue_stuck"  then [ rand < 0.2 ? 500 : 200, rand(300..900) ]  # backed up
    else [ 200, rand(70..180) ]
    end
  end

  def component_name(key)
    COMPONENTS.fetch(key, key)
  end
end

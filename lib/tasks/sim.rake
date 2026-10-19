# Autonomous agent->agent simulation.
#
#   ruby bin/rails sim:run                # 8 incidents (or COUNT=n)
#   ruby bin/rails sim:run COUNT=12 SEED=42
#
# Uses the real Jev model when TYPESAFE_API_KEY is set; otherwise falls back to
# the StubJevClient so it still runs offline (with trivial, not-smart answers).
namespace :sim do
  desc "Generate incidents and let the autonomous agent resolve them via Jev"
  task run: :environment do
    count = (ENV["COUNT"] || 8).to_i
    seed  = ENV["SEED"]&.to_i

    using_jev = ENV["TYPESAFE_API_KEY"].to_s.strip.present?
    jev   = using_jev ? JevClient.new : StubJevClient.new
    world = ActionWorld.new(random: seed ? Random.new(seed) : Random.new)
    agent = ResolutionAgent.new(jev: jev, world: world)
    sim   = IncidentSimulator.new(random: seed ? Random.new(seed) : Random.new)

    puts "=" * 72
    puts "KLAXON — otonom ajan->ajan simülasyonu"
    puts "Karar motoru: #{using_jev ? 'GERÇEK Jev (TypeSafe System One)' : 'StubJevClient (sahte)'}"
    puts "Üretilecek olay: #{count}#{seed ? "  (seed #{seed})" : ''}"
    puts "=" * 72

    incidents = sim.generate!(count: count)

    rows = incidents.map do |incident|
      outcome = agent.resolve!(incident)
      incident.reload
      {
        ref: incident.reference,
        service: incident.service.routing_key,
        severity: ResolutionAgent::SEVERITY_LEVELS[incident.severity.to_i],
        chose: incident.agent_action,
        correct: incident.root_cause_action,
        ok: incident.agent_action_correct?,
        conf: incident.agent_confidence,
        attempts: incident.resolution_attempts,
        outcome: outcome
      }
    end

    puts
    printf("%-11s %-14s %-9s %-16s %-16s %-6s %-5s %-4s %s\n",
           "REF", "SERVİS", "ÖNEM", "AJAN SEÇTİ", "DOĞRU AKSİYON", "İSBT", "GÜVEN", "DEN", "SONUÇ")
    puts "-" * 104
    rows.each do |r|
      printf("%-11s %-14s %-9s %-16s %-16s %-6s %-5s %-4d %s\n",
             r[:ref], r[:service], r[:severity].to_s, r[:chose].to_s, r[:correct].to_s,
             (r[:ok] ? "✓" : "✗"),
             (r[:conf] ? "#{(r[:conf] * 100).round}%" : "-"),
             r[:attempts], r[:outcome])
    end

    resolved = rows.count { |r| r[:outcome] == :resolved }
    correct  = rows.count { |r| r[:ok] }
    avg_conf = rows.filter_map { |r| r[:conf] }
    avg = avg_conf.any? ? (avg_conf.sum / avg_conf.size * 100).round : 0

    puts "-" * 104
    puts
    puts "ÖZET"
    puts "  Çözülen           : #{resolved}/#{rows.size}  (%#{(resolved * 100.0 / rows.size).round})"
    puts "  Doğru kök-neden   : #{correct}/#{rows.size}  (%#{(correct * 100.0 / rows.size).round})  ← Jev'in kararı ne kadar isabetli"
    puts "  Ortalama güven    : %#{avg}"
    puts
    puts "Her olayın adım adım gerekçesi için: /incidents (olaya tıkla, zaman çizelgesi)."
  end

  desc "Delete all simulated incidents (cleanup)"
  task clean: :environment do
    n = Incident.simulated.destroy_all.size
    puts "Silinen simüle olay: #{n}"
  end
end

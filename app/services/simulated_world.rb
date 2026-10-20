# A small live system: one ServiceState per (DB) service. Faults are injected
# for real, remediations are applied for real, and health is measured. Doubles
# as the "world" the ResolutionAgent acts on — #apply(action, incident) mutates
# the real state and returns whether the service actually recovered.
#
# One world lives for the duration of a single request/run: inject -> detect ->
# agent resolves -> re-check, all against the same in-memory state.
class SimulatedWorld
  def initialize(services: Service.active.order(:name), random: Random.new)
    @random = random
    @states = services.each_with_object({}) do |svc, acc|
      acc[svc.routing_key] = ServiceState.new(svc.routing_key, svc.name)
    end
  end

  def states
    @states.values
  end

  def state_for(routing_key)
    @states[routing_key]
  end

  def unhealthy_states
    @states.values.reject(&:healthy?)
  end

  # Break `count` currently-healthy services with a random fault each.
  def inject_random_faults!(count)
    healthy = @states.values.select(&:healthy?)
    healthy.sample([ count, healthy.size ].min, random: @random).each do |state|
      state.inject_fault!(ServiceState::FAULTS.keys.sample(random: @random))
    end
  end

  # World interface used by ResolutionAgent: apply the action to the incident's
  # service and report whether it is now actually healthy.
  def apply(action, incident)
    state = @states[incident.service.routing_key]
    return true if state.nil? # unknown service -> nothing to fix
    state.apply(action)
  end
end

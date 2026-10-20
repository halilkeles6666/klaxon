# The agent's world for the real store: applying a remediation to an incident's
# component removes the matching SiteFault for real (which genuinely heals the
# live store — subsequent requests return 200 again). Returns whether the
# component is now healthy, measured by the fault being gone.
class StoreWorld
  def apply(action, incident)
    component = incident.service.routing_key
    fault = SiteFault.active_for(component)
    return true if fault.nil? # already healthy

    fault.destroy if action.to_s == fault.fix # only the correct remediation heals
    SiteFault.active_for(component).nil?
  end
end

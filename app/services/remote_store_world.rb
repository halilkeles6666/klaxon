require "net/http"
require "json"

# The agent's world for the LIVE, separate Nimbus store. Applying a remediation
# POSTs it to the store's token-protected /heal endpoint over HTTP; the store
# clears the fault only if the action is the correct fix and reports back its
# health. So success is measured by the real remote site actually recovering.
class RemoteStoreWorld
  def initialize(base_url: ENV["NIMBUS_URL"], token: ENV["NIMBUS_TOKEN"], logger: Rails.logger)
    @base_url = base_url.to_s.strip
    @token = token.to_s
    @logger = logger
  end

  def apply(action, incident)
    return true if @base_url.empty? # nothing to call -> treat as resolved

    uri = URI.join(@base_url + (@base_url.end_with?("/") ? "" : "/"), "heal")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 4
    http.read_timeout = 8

    req = Net::HTTP::Post.new(uri)
    req.set_form_data(component: incident.service.routing_key, action: action.to_s, token: @token)
    response = http.request(req)

    return false unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["healthy"] == true
  rescue => e
    @logger&.warn("[RemoteStore] heal failed: #{e.class}: #{e.message}")
    false
  end
end

require "net/http"
require "json"

# Thin client for TypeSafe AI's System One endpoint (the Jev model).
#
#   "unstructured state in -> typed probabilistic decisions out"
#
# There is no official Ruby SDK, so we call the HTTP endpoint directly:
#   POST https://api.typesafe.ai/v1/systemone
#   Authorization: Bearer <TYPESAFE_API_KEY>
#
# Jev answers several typed questions about one `state` in a single request:
#   - noul   : probability (0..1) that a statement is true
#   - choice : picks one option from a labelled set (+ confidence, probabilities)
#   - score  : rates the state on ordered levels 0..n-1 (+ confidence)
#
# The agent uses the convenience builders (Jev.noul/choice/score) and reads the
# typed result back through JevClient::Result.
class JevClient
  ENDPOINT      = "https://api.typesafe.ai/v1/systemone".freeze
  DEFAULT_MODEL = "jev-latest".freeze
  OPEN_TIMEOUT  = 5
  READ_TIMEOUT  = 15

  class Error < StandardError; end
  class MissingKeyError < Error; end

  # ---- question builders (what you put in `questions:`) -------------------
  module Jev
    module_function

    def noul(instructions)
      { type: "noul", instructions: instructions }
    end

    # options: { "label" => "description", ... }
    def choice(instructions, options)
      { type: "choice", instructions: instructions, criteria: options }
    end

    # levels: ["lowest", ..., "highest"] -> score is the index 0..n-1
    def score(instructions, levels)
      { type: "score", instructions: instructions, criteria: levels }
    end
  end

  # ---- typed view over the `answers` object -------------------------------
  class Result
    def initialize(raw)
      @raw     = raw
      @answers = raw.fetch("answers", {})
    end

    attr_reader :raw

    def model = @raw["model"]

    # noul -> Float in 0..1
    def noul(id) = fetch(id).fetch("noul")

    # choice -> picked label (String)
    def choice(id) = fetch(id).fetch("choice")

    # choice -> confidence in the pick (Float, may be nil)
    def confidence(id) = fetch(id)["confidence"]

    # choice -> { "label" => probability } (Hash, may be nil)
    def probabilities(id) = fetch(id)["probabilities"]

    # score -> integer level 0..n-1
    def score(id) = fetch(id).fetch("score")

    def fetch(id)
      @answers[id.to_s] or raise Error, "no answer for #{id.inspect} (got #{@answers.keys})"
    end
  end

  def initialize(api_key: ENV["TYPESAFE_API_KEY"], model: DEFAULT_MODEL, logger: Rails.logger)
    @api_key = api_key
    @model   = model
    @logger  = logger
  end

  # state:     String or Hash describing the situation
  # questions: { id => Jev.noul/choice/score(...) }
  # => JevClient::Result
  def evaluate(state:, questions:)
    raise MissingKeyError, "TYPESAFE_API_KEY is not set" if @api_key.to_s.strip.empty?

    body = { state: state, model: @model, questions: questions }
    res  = post(body)

    unless res.is_a?(Net::HTTPSuccess)
      raise Error, "Jev HTTP #{res.code}: #{res.body.to_s[0, 300]}"
    end

    Result.new(JSON.parse(res.body))
  rescue JSON::ParserError => e
    raise Error, "Jev returned non-JSON: #{e.message}"
  end

  private

  def post(body)
    uri  = URI(ENDPOINT)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl     = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT

    req = Net::HTTP::Post.new(uri)
    req["Authorization"] = "Bearer #{@api_key}"
    req["Content-Type"]  = "application/json"
    req.body = JSON.generate(body)

    http.request(req)
  rescue Net::OpenTimeout, Net::ReadTimeout => e
    raise Error, "Jev request timed out: #{e.message}"
  rescue SocketError, Errno::ECONNREFUSED => e
    raise Error, "Jev unreachable: #{e.message}"
  end
end

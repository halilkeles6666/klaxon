# A drop-in replacement for JevClient used in tests and offline development.
# Same interface (#evaluate -> JevClient::Result), no network, no cost.
#
# By default it answers deterministically (first choice, noul 0.9, middle
# score). Pass a resolver block to script answers for a specific scenario:
#
#   StubJevClient.new do |state, questions|
#     { "action" => { "type" => "choice", "choice" => "rollback_deploy",
#                     "confidence" => 0.95 } }
#   end
#
# It records every call in #calls so tests can assert what the agent asked.
class StubJevClient
  attr_reader :calls

  def initialize(&resolver)
    @resolver = resolver
    @calls    = []
  end

  def evaluate(state:, questions:)
    @calls << { state: state, questions: questions }
    answers = @resolver&.call(state, questions) || default_answers(questions)
    # Allow a resolver to fill only some ids; default the rest.
    answers = default_answers(questions).merge(stringify(answers))
    JevClient::Result.new("model" => "stub-jev", "answers" => answers)
  end

  private

  def default_answers(questions)
    questions.each_with_object({}) do |(id, q), acc|
      acc[id.to_s] =
        case q[:type] || q["type"]
        when "noul"
          { "type" => "noul", "noul" => 0.9 }
        when "choice"
          labels = (q[:criteria] || q["criteria"]).keys
          { "type" => "choice", "choice" => labels.first,
            "confidence" => 0.8,
            "probabilities" => labels.index_with { |_| 1.0 / labels.size } }
        when "score"
          levels = q[:criteria] || q["criteria"]
          { "type" => "score", "score" => levels.size / 2, "confidence" => 0.8 }
        end
    end
  end

  def stringify(hash)
    hash.transform_keys(&:to_s)
  end
end

require "test_helper"

class JevClientTest < ActiveSupport::TestCase
  test "evaluate raises without an API key (no network attempted)" do
    client = JevClient.new(api_key: nil)
    assert_raises(JevClient::MissingKeyError) do
      client.evaluate(state: "x", questions: { q: JevClient::Jev.noul("y") })
    end
  end

  test "question builders produce the documented shapes" do
    assert_equal({ type: "noul", instructions: "urgent?" },
                 JevClient::Jev.noul("urgent?"))

    choice = JevClient::Jev.choice("pick", { "a" => "A", "b" => "B" })
    assert_equal "choice", choice[:type]
    assert_equal({ "a" => "A", "b" => "B" }, choice[:criteria])

    score = JevClient::Jev.score("rate", %w[low high])
    assert_equal "score", score[:type]
    assert_equal %w[low high], score[:criteria]
  end

  test "Result exposes typed answers" do
    result = JevClient::Result.new(
      "model" => "jev-test",
      "answers" => {
        "is_urgent" => { "type" => "noul", "noul" => 0.91 },
        "action"    => { "type" => "choice", "choice" => "failover",
                         "confidence" => 0.8, "probabilities" => { "failover" => 0.8 } },
        "sev"       => { "type" => "score", "score" => 3, "confidence" => 0.7 }
      })

    assert_equal "jev-test", result.model
    assert_in_delta 0.91, result.noul(:is_urgent), 0.001
    assert_equal "failover", result.choice(:action)
    assert_in_delta 0.8, result.confidence(:action), 0.001
    assert_equal({ "failover" => 0.8 }, result.probabilities(:action))
    assert_equal 3, result.score(:sev)
  end

  test "Result raises a clear error for a missing answer id" do
    result = JevClient::Result.new("answers" => {})
    assert_raises(JevClient::Error) { result.noul(:nope) }
  end
end

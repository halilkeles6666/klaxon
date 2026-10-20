require "test_helper"

class JevDeduperTest < ActiveSupport::TestCase
  setup { @service = services(:payments) }

  def open_incident(title, key: SecureRandom.hex(3))
    incident, = Incident.ingest(service: @service, dedup_key: key, title: title,
                                summary: title, deduper: KeyDeduper.new)
    incident
  end

  def match_answer(choice, confidence: 0.9)
    { "match" => { "type" => "choice", "choice" => choice, "confidence" => confidence } }
  end

  test "groups the new alert into the open incident Jev chooses" do
    existing = open_incident("Ödeme API 5xx oranı yüksek")
    jev = StubJevClient.new { |_s, _q| match_answer("olay_0") }

    match = JevDeduper.new(jev: jev).find_match(
      service: @service, title: "Checkout 500 hataları", summary: "çok sayıda 500", key: "x")

    assert_equal existing, match
  end

  test "opens a separate incident when Jev says none" do
    open_incident("Ödeme API 5xx oranı yüksek")
    jev = StubJevClient.new { |_s, _q| match_answer("none") }

    assert_nil JevDeduper.new(jev: jev).find_match(
      service: @service, title: "Veritabanı düştü", summary: "farklı problem", key: "y")
  end

  test "does not group on low confidence" do
    open_incident("Ödeme API 5xx oranı yüksek")
    jev = StubJevClient.new { |_s, _q| match_answer("olay_0", confidence: 0.2) }

    assert_nil JevDeduper.new(jev: jev).find_match(
      service: @service, title: "x", summary: "y", key: "z")
  end

  test "falls back to exact-key matching when Jev errors" do
    incident = open_incident("herhangi", key: "known")
    raising = Object.new
    def raising.evaluate(**) = raise JevClient::Error, "boom"

    match = JevDeduper.new(jev: raising).find_match(
      service: @service, title: "a", summary: "b", key: "known")

    assert_equal incident, match
  end
end

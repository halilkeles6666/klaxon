# Load the TypeSafe / Jev API key from a local, gitignored file when it isn't
# already in the environment. This way `rails server` and `rails console` use
# the real Jev model regardless of which shell launched them (the env var does
# not have to be exported every time).
#
# config/typesafe.key is gitignored and never committed. On Render, set the
# TYPESAFE_API_KEY environment variable instead (the env var wins).
# Never auto-load the key in the test environment — tests must stay offline and
# use StubJevClient (no network, no cost).
unless Rails.env.test?
  if ENV["TYPESAFE_API_KEY"].to_s.strip.empty?
    key_file = Rails.root.join("config", "typesafe.key")
    ENV["TYPESAFE_API_KEY"] = key_file.read.strip if key_file.exist?
  end
end

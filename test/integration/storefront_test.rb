require "test_helper"

# The fake store is a real, public, browsable site — and it genuinely breaks
# when a fault is injected.
class StorefrontTest < ActionDispatch::IntegrationTest
  test "the storefront is browsable without logging in" do
    get store_path
    assert_response :success
    assert_select "h1"
  end

  test "an injected fault really breaks the page (real HTTP error)" do
    StoreBackend.ensure_components!
    SiteFault.create!(component: "magaza-vitrin", fault: "crashed")

    get store_path
    assert_response :service_unavailable # 503
  end

  test "clearing the fault brings the page back" do
    StoreBackend.ensure_components!
    SiteFault.create!(component: "magaza-vitrin", fault: "crashed")
    SiteFault.destroy_all

    get store_path
    assert_response :success
  end
end

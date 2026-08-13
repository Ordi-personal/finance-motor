require "test_helper"

class Auth::SsoControllerTest < ActiveSupport::TestCase
  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "claims a jti once with an atomic cache write" do
    controller = Auth::SsoController.new

    assert controller.send(:mark_token_as_used, "jti-once", 10.minutes.from_now.to_i)
    assert_not controller.send(:mark_token_as_used, "jti-once", 10.minutes.from_now.to_i)
  end

  test "uses the cache unless_exist option for the replay claim" do
    controller = Auth::SsoController.new
    Rails.cache.expects(:write).with(
      "sso:jti:jti-option", true,
      expires_in: is_a(Integer), unless_exist: true
    ).returns(true)

    assert controller.send(:mark_token_as_used, "jti-option", 10.minutes.from_now.to_i)
  end
end

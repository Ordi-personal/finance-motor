# frozen_string_literal: true

require "test_helper"

class Api::V1::ProvisioningControllerTest < ActionDispatch::IntegrationTest
  setup do
    @email = "new-provisioned-user-#{SecureRandom.hex(6)}@example.com"
    User.where(email: @email).destroy_all
  end

  teardown do
    User.where(email: @email).destroy_all
  end

  test "should provision a new family, user, categories, rules, trial subscription and initial account" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      assert_difference "User.count", 1 do
        post "/api/v1/provisioning",
             params: {
               email: @email,
               first_name: "Ada",
               last_name: "Lovelace",
               time_zone: "America/Sao_Paulo",
               currency: "BRL",
               locale: "pt-BR",
               initial_account: { name: "Dinheiro", balance: 100, currency: "BRL" }
             },
             headers: { "X-Ordi-Secret" => "shared-secret" }
      end

      assert_response :created
      response_body = JSON.parse(response.body)
      assert_equal true, response_body["created"]
      assert_equal @email, response_body["user"]["email"]
      assert_equal "Ada", response_body["user"]["first_name"]
      assert response_body["family"]["id"].present?
      assert_equal "Dinheiro", response_body["account"]["name"]

      user = User.find_by(email: @email)
      assert user.present?
      assert user.onboarded_at.present?
      assert_equal "admin", user.role

      family = user.family
      assert family.categories.any?
      assert family.rules.any?
      assert family.subscription.present?
      assert_equal "trialing", family.subscription.status
      assert_equal 1, family.accounts.count
      assert_equal "Dinheiro", family.accounts.first.name
    end
  end

  test "should be idempotent for an already-provisioned email" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      post "/api/v1/provisioning",
           params: { email: @email, first_name: "Ada" },
           headers: { "X-Ordi-Secret" => "shared-secret" }
      assert_response :created
      first_user_id = JSON.parse(response.body)["user"]["id"]

      assert_no_difference "User.count" do
        post "/api/v1/provisioning",
             params: { email: @email, first_name: "Ada" },
             headers: { "X-Ordi-Secret" => "shared-secret" }
      end

      assert_response :success
      response_body = JSON.parse(response.body)
      assert_equal false, response_body["created"]
      assert_equal first_user_id, response_body["user"]["id"]
      assert_nil response_body["account"]
    end
  end

  test "should reject requests without X-Ordi-Secret header" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      post "/api/v1/provisioning", params: { email: @email }

      assert_response :unauthorized
    end
  end

  test "should reject requests with an invalid X-Ordi-Secret" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      post "/api/v1/provisioning", params: { email: @email }, headers: { "X-Ordi-Secret" => "wrong-secret" }

      assert_response :unauthorized
    end
  end

  test "should reject OAuth/API key authentication (S2S only)" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      user = users(:family_admin)
      user.api_keys.active.destroy_all
      api_key = ApiKey.create!(
        user: user,
        name: "Some Key",
        scopes: [ "read_write" ],
        source: "web",
        display_key: "provisioning_test_#{SecureRandom.hex(8)}"
      )

      post "/api/v1/provisioning", params: { email: @email }, headers: { "X-Api-Key" => api_key.plain_key }

      assert_response :unauthorized
    end
  end

  test "should return 401 when ORDI_SHARED_SECRET is not configured" do
    with_env_overrides("ORDI_SHARED_SECRET" => nil) do
      post "/api/v1/provisioning", params: { email: @email }, headers: { "X-Ordi-Secret" => "anything" }

      assert_response :unauthorized
    end
  end

  test "should return 422 when email is missing" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      post "/api/v1/provisioning", params: {}, headers: { "X-Ordi-Secret" => "shared-secret" }

      assert_response :unprocessable_entity
      response_body = JSON.parse(response.body)
      assert_equal "validation_failed", response_body["error"]
    end
  end
end

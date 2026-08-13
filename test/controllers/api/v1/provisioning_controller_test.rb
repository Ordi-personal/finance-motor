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

  test "accepts the dedicated provisioning secret when configured" do
    with_env_overrides("ORDI_SHARED_SECRET" => "operations-secret", "ORDI_PROVISIONING_SECRET" => "provisioning-secret") do
      post "/api/v1/provisioning", params: { email: @email }, headers: { "X-Ordi-Secret" => "provisioning-secret" }

      assert_response :created
    end
  end

  test "rejects the operations secret when a dedicated provisioning secret is configured" do
    with_env_overrides("ORDI_SHARED_SECRET" => "operations-secret", "ORDI_PROVISIONING_SECRET" => "provisioning-secret") do
      post "/api/v1/provisioning", params: { email: @email }, headers: { "X-Ordi-Secret" => "operations-secret" }

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

  test "should reject a non-BRL provisioning currency without creating a user" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      assert_no_difference "User.count" do
        post "/api/v1/provisioning",
             params: { email: @email, currency: "USD" },
             headers: { "X-Ordi-Secret" => "shared-secret" }
      end

      assert_response :unprocessable_entity
      response_body = JSON.parse(response.body)
      assert_equal "unsupported_currency", response_body["error"]
      assert_match(/BRL only/i, response_body["message"])
    end
  end

  test "should reject a non-BRL initial account currency" do
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret") do
      assert_no_difference "User.count" do
        post "/api/v1/provisioning",
             params: {
               email: @email,
               currency: "BRL",
               initial_account: { name: "Dollar", balance: 0, currency: "USD" }
             },
             headers: { "X-Ordi-Secret" => "shared-secret" }
      end

      assert_response :unprocessable_entity
      response_body = JSON.parse(response.body)
      assert_equal "unsupported_currency", response_body["error"]
    end
  end

  test "concurrent provisioning requests return one created and one already-existing user" do
    email = "race-provisioned-user-#{SecureRandom.hex(6)}@example.com"
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret", "ORDI_PROVISIONING_SECRET" => nil) do
      lookup_mutex = Mutex.new
      lookup_condition = ConditionVariable.new
      initial_lookups = 0
      original_find_by = User.method(:find_by)
      find_by_with_barrier = lambda do |conditions = nil, *args, **kwargs|
        result = if conditions.nil? && kwargs.present?
          original_find_by.call(*args, **kwargs)
        elsif conditions.nil?
          nil
        else
          original_find_by.call(conditions, *args, **kwargs)
        end
        query = conditions || kwargs
        target_lookup = query.is_a?(Hash) && query[:email].to_s.casecmp?(email)
        should_wait = lookup_mutex.synchronize do
          next false unless target_lookup && initial_lookups < 2

          initial_lookups += 1
          true
        end
        if should_wait
          lookup_mutex.synchronize do
            lookup_condition.broadcast if initial_lookups == 2
            lookup_condition.wait(lookup_mutex) while initial_lookups < 2
          end
        end
        result
      end

      outcomes = User.stub(:find_by, find_by_with_barrier) do
        requests = 2.times.map do
          Thread.new do
            ActiveRecord::Base.connection_pool.with_connection do
              env = Rack::MockRequest.env_for(
                "/api/v1/provisioning",
                method: "POST",
                "CONTENT_TYPE" => "application/json",
                input: { email: email, currency: "BRL" }.to_json
              )
              env["HTTP_X_ORDI_SECRET"] = "shared-secret"
              status, _headers, body = Api::V1::ProvisioningController.action(:create).call(env)
              [ status, JSON.parse(body.each.to_a.join) ]
            end
          end
        end
        requests.map(&:value)
      end

      assert_equal [ 200, 201 ], outcomes.map(&:first).sort, outcomes.inspect
      assert outcomes.all? { |(_, body)| body["user"]["email"] == email }
      assert_equal 1, User.where(email: email).count
      assert_equal 1, Family.where(id: User.where(email: email).select(:family_id)).count
    end
  ensure
    family_ids = User.where(email: email).pluck(:family_id)
    User.where(email: email).destroy_all
    Family.where(id: family_ids).destroy_all
  end

  test "treats a unique email insert error as an idempotent replay" do
    @email = "replayed-provisioned-user-#{SecureRandom.hex(6)}@example.com"
    existing_user = families(:empty).users.create!(
      email: @email,
      first_name: "Already",
      last_name: "Exists",
      password: "Password1!",
      role: "admin"
    )
    with_env_overrides("ORDI_SHARED_SECRET" => "shared-secret", "ORDI_PROVISIONING_SECRET" => nil) do
      Saas::UserProvisioningService.stubs(:provision!).raises(
        ActiveRecord::RecordNotUnique.new('duplicate key value violates unique constraint "index_users_on_email"')
      )

      post "/api/v1/provisioning",
           params: { email: @email, currency: "BRL" },
           headers: { "X-Ordi-Secret" => "shared-secret" }
    end

    assert_response :success
    response_body = JSON.parse(response.body)
    assert_equal false, response_body["created"]
    assert_equal existing_user.id, response_body.dig("user", "id")
    assert_equal 1, User.where(email: @email).count
  end
end

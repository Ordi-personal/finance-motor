# frozen_string_literal: true

require "test_helper"

# Upgrade gate for the HTTP surface consumed by fluxo-app. Keep this test close
# to the real Jbuilders so an upstream merge cannot silently remove a field the
# app depends on.
class OrdiUpgradeContractTest < ActiveSupport::TestCase
  TRANSACTION_FIELDS = %w[
    kind amount_cents signed_amount_cents currency external_id source classification
  ].freeze

  test "transaction and account serializers retain the Ordi upgrade contract" do
    transaction_serializer = Rails.root.join("app/views/api/v1/transactions/_transaction.json.jbuilder").read
    account_serializer = Rails.root.join("app/views/api/v1/accounts/_account.json.jbuilder").read

    TRANSACTION_FIELDS.each do |field|
      assert_match(/json\.#{Regexp.escape(field)}\b/, transaction_serializer, "missing transaction field #{field}")
    end
    assert_match(/json\.available_credit\b/, account_serializer, "missing account field available_credit")
  end

  test "SSO replay claim remains atomic across an upgrade" do
    original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    controller = Auth::SsoController.new

    assert controller.send(:mark_token_as_used, "upgrade-contract-jti", 10.minutes.from_now.to_i)
    assert_not controller.send(:mark_token_as_used, "upgrade-contract-jti", 10.minutes.from_now.to_i)
  ensure
    Rails.cache = original_cache
  end
end

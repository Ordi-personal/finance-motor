require "test_helper"

class TransactionsIndexLocalizationTest < ActionDispatch::IntegrationTest
  setup do
    sign_in users(:family_admin)
  end

  test "index renders pt-BR transaction list and search labels without translation wrappers" do
    get transactions_url(locale: "pt-BR")

    assert_response :success
    assert_includes @response.body, 'data-bulk-select-singular-label-value="transação"'
    assert_includes @response.body, 'placeholder="Buscar transações..."'
    refute_includes @response.body, 'translation missing: pt-BR.transactions.list.transaction'
    refute_includes @response.body, 'translation missing: pt-BR.transactions.searches.form.search_placeholder'
  end
end
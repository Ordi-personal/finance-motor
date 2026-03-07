# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  # Ensure proper scope authorization for read access
  before_action :ensure_read_scope

  def create
    family = current_resource_owner.family
    
    # Extract params
    account_params = params.require(:account).permit(:name, :balance, :currency, :account_type, :is_active)
    
    name = account_params[:name]
    balance = account_params[:balance].to_d
    currency = account_params[:currency] || "BRL"
    type = account_params[:account_type] # e.g. "checking"

    # Map generic type to Accountable Type
    case type
    when "checking", "savings", "hsa", "cd", "money_market"
      accountable_type = "Depository"
      subtype = type
    when "credit_card"
      accountable_type = "CreditCard"
      subtype = nil
    when "loan"
      accountable_type = "Loan"
      subtype = "mortgage" # Default or need mapping
    when "investment"
      accountable_type = "Investment"
      subtype = "brokerage"
    else
      # Default fallback
      accountable_type = "Depository"
      subtype = "checking"
    end

    attributes = {
      family: family,
      name: name,
      balance: balance, # Current balance
      currency: currency,
      accountable_type: accountable_type,
      accountable_attributes: { 
        subtype: subtype
      }.compact
    }

    @account = Account.create_and_sync(attributes)

    render :show, status: :created
  rescue => e
    Rails.logger.error "AccountsController#create error: #{e.message}"
    render json: { error: e.message }, status: :unprocessable_entity
  end

  def index
    # Test with Pagy pagination
    family = current_resource_owner.family
    accounts_query = family.accounts.visible.alphabetically

    # Handle pagination with Pagy
    @pagy, @accounts = pagy(
      accounts_query,
      page: safe_page_param,
      limit: safe_per_page_param
    )

    @per_page = safe_per_page_param

    # Rails will automatically use app/views/api/v1/accounts/index.json.jbuilder
    render :index
  rescue => e
    Rails.logger.error "AccountsController error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
end

    private

      def ensure_read_scope
        authorize_scope!(:read)
      end



      def safe_page_param
        page = params[:page].to_i
        page > 0 ? page : 1
      end

      def safe_per_page_param
        per_page = params[:per_page].to_i

        # Default to 25, max 100
        case per_page
        when 1..100
          per_page
        else
          25
        end
      end
end

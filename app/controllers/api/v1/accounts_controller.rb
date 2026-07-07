# frozen_string_literal: true

class Api::V1::AccountsController < Api::V1::BaseController
  include Pagy::Backend

  # Ensure proper scope authorization for read vs write access
  before_action :ensure_read_scope, only: [ :index, :show ]
  before_action :ensure_write_scope, only: [ :create ]

  def index
    @per_page = safe_per_page_param

    @pagy, @accounts = pagy(
      accounts_scope.alphabetically,
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue => e
    Rails.logger.error "AccountsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def show
    unless valid_uuid?(params[:id])
      render json: {
        error: "not_found",
        message: "Account not found"
      }, status: :not_found
      return
    end

    @account = accounts_scope.find(params[:id])

    render :show
  rescue ActiveRecord::RecordNotFound
    render json: {
      error: "not_found",
      message: "Account not found"
    }, status: :not_found
  rescue => e
    Rails.logger.error "AccountsController#show error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  def create
    accountable_type = params.dig(:account, :accountable_type).presence || "Depository"

    unless Accountable::TYPES.include?(accountable_type)
      render json: {
        error: "validation_failed",
        message: "Account could not be created",
        errors: [ "accountable_type must be one of: #{Accountable::TYPES.join(', ')}" ]
      }, status: :unprocessable_entity
      return
    end

    Account.transaction do
      @account = current_resource_owner.family.accounts.create_and_sync(
        account_create_params(accountable_type).merge(owner: current_resource_owner)
      )
    end

    render :show, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Account could not be created",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "AccountsController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    def ensure_read_scope
      authorize_scope!(:read)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    # Builds the attribute hash expected by Account.create_and_sync. Note that
    # `subtype` must travel inside `accountable_attributes` (not as a top-level
    # Account attribute) — Account#subtype= delegates to the (not-yet-built)
    # accountable association, so a top-level `subtype:` is silently dropped
    # when creating a brand new record. This mirrors how the web accounts form
    # submits params (accountable_type hidden field + subtype nested under the
    # accountable's own form partial).
    def account_create_params(accountable_type)
      permitted = params.require(:account).permit(:name, :balance, :currency, :subtype)
      klass = accountable_type.constantize
      default_subtype = accountable_type == "Depository" ? "checking" : (klass.const_defined?(:DEFAULT_SUBTYPE) ? klass::DEFAULT_SUBTYPE : nil)

      {
        name: permitted[:name],
        balance: permitted[:balance],
        currency: permitted[:currency].presence || current_resource_owner.family.currency,
        accountable_type: accountable_type,
        accountable_attributes: { subtype: permitted[:subtype].presence || default_subtype }
      }
    end

    def accounts_scope
      scope = current_resource_owner.family.accounts
                                    .accessible_by(current_resource_owner)
                                    .includes(:accountable, account_providers: :provider)
      include_disabled_accounts? ? scope : scope.visible
    end

    def include_disabled_accounts?
      ActiveModel::Type::Boolean.new.cast(params[:include_disabled])
    end
end

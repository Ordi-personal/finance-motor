# frozen_string_literal: true

# Internal server-to-server endpoint used by the Ordi app to provision a
# fully-onboarded Sure user (Family + User + default categories/rules +
# trial subscription + optional initial account) without writing directly
# to Sure's database. Idempotent: a second call for the same email returns
# the existing user/family instead of erroring.
#
# Authentication here is intentionally narrower than the rest of the API:
# only the X-Ordi-Secret shared secret is accepted (no OAuth, no API key),
# following the AuthController pattern of skipping the default
# authenticate_request! chain and defining its own before_action. This
# endpoint creates/reads user accounts, so it must never be reachable with
# a user-scoped credential.
class Api::V1::ProvisioningController < Api::V1::BaseController
  skip_before_action :authenticate_request!
  skip_before_action :check_api_key_rate_limit
  skip_before_action :log_api_access
  before_action :authenticate_provisioning_secret!

  def create
    unless params[:email].present?
      render json: {
        error: "validation_failed",
        message: "Email is required",
        errors: [ "Email is required" ]
      }, status: :unprocessable_entity
      return
    end

    result = Saas::UserProvisioningService.provision!(
      email: params[:email],
      first_name: params[:first_name],
      last_name: params[:last_name],
      time_zone: params[:time_zone],
      currency: params[:currency],
      locale: params[:locale],
      initial_account: initial_account_params
    )

    render json: provisioning_response(result), status: (result.created ? :created : :ok)
  rescue ActiveRecord::RecordInvalid => e
    render json: {
      error: "validation_failed",
      message: "Provisioning failed",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "ProvisioningController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "An unexpected error occurred"
    }, status: :internal_server_error
  end

  private

    # Deliberately does not reuse BaseController#authenticate_ordi_secret:
    # that method looks up an *existing* User by X-User-Email and fails if
    # none is found, which would break provisioning of brand-new users.
    # Path allowlisting still goes through the shared
    # ordi_internal_request_allowed? check for consistency.
    def authenticate_provisioning_secret!
      shared_secret = ENV["ORDI_SHARED_SECRET"]

      unless shared_secret.present? && ordi_internal_request_allowed?
        render_unauthorized
        return
      end

      secret = request.headers["X-Ordi-Secret"]
      unless secret.present? && ActiveSupport::SecurityUtils.secure_compare(secret.to_s, shared_secret)
        render_unauthorized
        return
      end

      @authentication_method = :ordi_secret
    end

    def initial_account_params
      return nil unless params[:initial_account].present?

      params.require(:initial_account).permit(:name, :balance, :currency, :subtype).to_h.symbolize_keys
    end

    def provisioning_response(result)
      {
        created: result.created,
        user: {
          id: result.user.id,
          email: result.user.email,
          first_name: result.user.first_name,
          last_name: result.user.last_name
        },
        family: {
          id: result.family.id,
          currency: result.family.currency,
          locale: result.family.locale,
          timezone: result.family.timezone
        },
        account: account_response(result.account)
      }
    end

    def account_response(account)
      return nil unless account

      {
        id: account.id,
        name: account.name,
        balance: account.balance_money.format,
        currency: account.currency
      }
    end
end

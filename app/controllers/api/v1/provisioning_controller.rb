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
    if email_uniqueness_conflict?(e) && render_existing_user
      return
    end

    render json: {
      error: "validation_failed",
      message: "Provisioning failed",
      errors: e.record.errors.full_messages
    }, status: :unprocessable_entity
  rescue ActiveRecord::RecordNotUnique => e
    if render_existing_user
      return
    end

    render_internal_error(e)
  rescue ArgumentError => e
    render json: {
      error: "unsupported_currency",
      message: e.message,
      errors: [ e.message ]
    }, status: :unprocessable_entity
  rescue => e
    render_internal_error(e)
  end

  private

    # Deliberately does not reuse BaseController#authenticate_ordi_secret:
    # that method looks up an *existing* User by X-User-Email and fails if
    # none is found, which would break provisioning of brand-new users.
    # It uses a distinct secret when ORDI_PROVISIONING_SECRET is configured.
    # ORDI_SHARED_SECRET remains an explicit migration fallback only.
    def authenticate_provisioning_secret!
      shared_secret = ENV["ORDI_PROVISIONING_SECRET"].presence || ENV["ORDI_SHARED_SECRET"]

      unless shared_secret.present? && request.post? && request.path == "/api/v1/provisioning"
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

    def render_existing_user
      existing_user = User.find_by(email: normalized_email)
      return false unless existing_user

      result = Saas::UserProvisioningService::Result.new(
        user: existing_user,
        family: existing_user.family,
        account: nil,
        created: false
      )
      render json: provisioning_response(result), status: :ok
      true
    end

    def email_uniqueness_conflict?(error)
      record = error.record
      return false unless record.is_a?(User)

      record.errors.details.fetch(:email, []).any? { |detail| detail[:error] == :taken }
    end

    def normalized_email
      params[:email].to_s.strip.downcase
    end

    def render_internal_error(error)
      Rails.logger.error "ProvisioningController#create error: #{error.message}"
      Rails.logger.error error.backtrace.join("\n") if error.backtrace

      render json: {
        error: "internal_server_error",
        message: "An unexpected error occurred"
      }, status: :internal_server_error
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

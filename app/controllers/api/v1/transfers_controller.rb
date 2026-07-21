# frozen_string_literal: true

class Api::V1::TransfersController < Api::V1::BaseController
  include Pagy::Backend
  include Api::V1::TransferDecisionFiltering

  before_action :ensure_read_scope, only: [ :index, :show ]
  before_action :ensure_write_scope, only: [ :create ]
  before_action :set_transfer, only: :show

  def index
    transfers_query = apply_transfer_decision_filters(transfers_scope, status_model: Transfer).order(created_at: :desc)
    @per_page = safe_per_page_param

    @pagy, @transfers = pagy(
      transfers_query,
      page: safe_page_param,
      limit: @per_page
    )

    render :index
  rescue Api::V1::TransferDecisionFiltering::InvalidFilterError => e
    render_validation_error(e.message)
  end

  def show
    render :show
  end

  # Mirrors TransfersController#create semantics via Transfer::Creator (same
  # path the web UI uses), exposed to the API so integrations don't have to
  # write into the database directly.
  def create
    from_id = params.dig(:transfer, :from_account_id)
    to_id = params.dig(:transfer, :to_account_id)

    unless valid_uuid?(from_id) && valid_uuid?(to_id)
      return render_validation_error("from_account_id and to_account_id must be valid account ids")
    end

    @transfer = Transfer::Creator.new(
      family: current_resource_owner.family,
      source_account_id: from_id,
      destination_account_id: to_id,
      date: transfer_create_params[:date].present? ? Date.parse(transfer_create_params[:date].to_s) : Date.current,
      amount: transfer_create_params[:amount].to_d,
      exchange_rate: transfer_create_params[:exchange_rate].presence&.to_d
    ).create

    if @transfer.persisted?
      render :show, status: :created
    else
      render_json({
        error: "validation_failed",
        message: "Transfer could not be created",
        errors: @transfer.errors.full_messages
      }, status: :unprocessable_entity)
    end
  rescue ActiveRecord::RecordNotFound
    render_json({ error: "not_found", message: "Account not found" }, status: :not_found)
  rescue Money::ConversionError
    render_validation_error("Exchange rate unavailable for selected currencies and date")
  rescue ArgumentError => e
    render_validation_error(e.message)
  end

  private

    def set_transfer
      raise ActiveRecord::RecordNotFound unless valid_uuid?(params[:id])

      @transfer = transfers_scope.find(params[:id])
    end

    def transfers_scope
      transfer_decision_scope(Transfer)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end

    def transfer_create_params
      params.require(:transfer).permit(:from_account_id, :to_account_id, :amount, :date, :exchange_rate)
    end
end

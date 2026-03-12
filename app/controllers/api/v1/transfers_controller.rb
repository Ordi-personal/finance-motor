# frozen_string_literal: true

class Api::V1::TransfersController < Api::V1::BaseController
  before_action :ensure_write_scope, only: [ :create ]

  def create
    family = current_resource_owner.family

    from_account_id = transfer_params[:from_account_id]
    to_account_id = transfer_params[:to_account_id]
    amount = transfer_params[:amount]
    date = transfer_params[:date]
    name = transfer_params[:name]

    if from_account_id.blank? || to_account_id.blank? || amount.blank? || date.blank?
      render json: {
        error: "validation_failed",
        message: "Missing required fields: from_account_id, to_account_id, amount, date",
        errors: ["Missing required fields"]
      }, status: :unprocessable_entity
      return
    end

    # Explicit tenant isolation constraint:
    # Ensure both accounts belong to the authenticated user's family
    begin
      source_account = family.accounts.find(from_account_id)
      destination_account = family.accounts.find(to_account_id)
    rescue ActiveRecord::RecordNotFound
      render json: {
        error: "not_found",
        message: "One or both accounts were not found or do not belong to you",
        errors: ["Account not found"]
      }, status: :not_found
      return
    end

    @transfer = Transfer::Creator.new(
      family: family,
      source_account_id: source_account.id,
      destination_account_id: destination_account.id,
      date: date,
      amount: amount.to_d
    ).create

    if @transfer.persisted?
      # We render a success JSON with the transfer ID and the underlying transactions
      render json: {
        message: "Transfer created successfully",
        transfer: {
          id: @transfer.id,
          amount: amount.to_d,
          date: date,
          source_account_id: source_account.id,
          destination_account_id: destination_account.id,
          inflow_transaction_id: @transfer.inflow_transaction_id,
          outflow_transaction_id: @transfer.outflow_transaction_id
        }
      }, status: :created
    else
      render json: {
        error: "validation_failed",
        message: "Transfer could not be created",
        errors: @transfer.errors.full_messages
      }, status: :unprocessable_entity
    end
  rescue => e
    Rails.logger.error "Api::V1::TransfersController#create error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end

  private

    def transfer_params
      params.require(:transfer).permit(:from_account_id, :to_account_id, :amount, :date, :name)
    end

    def ensure_write_scope
      authorize_scope!(:write)
    end
end

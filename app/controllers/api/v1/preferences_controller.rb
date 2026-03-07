# frozen_string_literal: true

class Api::V1::PreferencesController < Api::V1::BaseController
  before_action :ensure_read_scope, only: [ :show ]
  before_action :ensure_write_scope, only: [ :update ]

  def show
    family = current_resource_owner.family
    render json: {
      locale: family.locale,
      currency: family.currency,
      country: family.country,
      date_format: family.date_format,
      timezone: family.timezone
    }
  end

  def update
    family = current_resource_owner.family

    Rails.logger.info("[PreferencesAPI] Update for family #{family.id}: #{preferences_params}")

    if family.update(preferences_params)
      Rails.logger.info("[PreferencesAPI] Updated family #{family.id} timezone=#{family.timezone}")
      render json: {
        status: "ok",
        locale: family.locale,
        currency: family.currency,
        country: family.country,
        date_format: family.date_format,
        timezone: family.timezone
      }
    else
      Rails.logger.warn("[PreferencesAPI] Update failed for family #{family.id}: #{family.errors.full_messages}")
      render json: {
        error: "validation_failed",
        messages: family.errors.full_messages
      }, status: :unprocessable_entity
    end
  end

  private

  def ensure_read_scope
    authorize_scope!(:read)
  end

  def ensure_write_scope
    authorize_scope!(:write)
  end

  def preferences_params
    params.permit(:locale, :currency, :country, :date_format, :timezone)
  end
end

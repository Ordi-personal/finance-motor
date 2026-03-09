# frozen_string_literal: true

module Auth
  class SsoController < ApplicationController
    skip_authentication only: [:callback]

    def callback
      token = params[:token]

      if token.blank?
        return redirect_to new_session_path, alert: "SSO token is required"
      end

      secret = ENV["SSO_SECRET_KEY"]
      if secret.blank?
        Rails.logger.error("[SSO] SSO_SECRET_KEY not configured — SSO disabled")
        return redirect_to new_session_path, alert: "SSO not available"
      end

      begin
        payload = JWT.decode(token, secret, true, { algorithm: "HS256" }).first
        
        user = User.find_by(email: payload["email"])
        
        if user.nil?
          user = create_sso_user(payload)
        else
          ensure_onboarded(user, payload)
        end

        if user
          # Create session for user (using Authentication concern method)
          create_session_for(user)
          
          # Save embedded mode to session if requested
          if params[:embedded] == "true"
            session[:embedded_mode] = true
          end
          
          Rails.logger.info("[SSO] Successfully authenticated user: #{user.email} (embedded: #{params[:embedded]})")
          
      # Garante que o path comece com / para evitar URLs malformadas como localhost:4000reports
      target_path = params[:return_to].to_s
      target_path = "/#{target_path}" unless target_path.empty? || target_path.start_with?("/")
      
      redirect_path = root_url.delete_suffix("/") + target_path
      
      if params[:embedded] == "true"
        redirect_path += (redirect_path.include?("?") ? "&" : "?") + "embedded=true"
      end

      Rails.logger.info("[SSO] Redirecting to: #{redirect_path}")
      redirect_to redirect_path, allow_other_host: true
    else
      Rails.logger.error("[SSO] Failed to find or create user for email: #{payload['email']}")
      redirect_to new_session_path, alert: "SSO authentication failed"
    end
  rescue JWT::ExpiredSignature
    Rails.logger.warn("[SSO] Token expired")
    redirect_to new_session_path, alert: "SSO token has expired"
  rescue JWT::DecodeError => e
    Rails.logger.error("[SSO] Token decode error: #{e.message}")
    redirect_to new_session_path, alert: "Invalid SSO token"
  end
end

    private

    def create_sso_user(payload)
      first = payload["first_name"].presence || payload["email"].split("@").first.titleize
      last = payload["last_name"].presence || ""
      locale = payload["locale"].presence || "pt-BR"
      currency = payload["currency"].presence || "BRL"
      country = payload["country"].presence || "BR"

      User.transaction do
        family = Family.create!(
          name: "#{first}'s Family",
          locale: locale,
          date_format: "%d/%m/%Y",
          currency: currency,
          country: country
        )

        Saas::InitialDataService.bootstrap!(family)

        user = family.users.create!(
          email: payload["email"],
          first_name: first,
          last_name: last,
          password: SecureRandom.hex(16),
          onboarded_at: Time.current,
          role: "admin"
        )
        
        Rails.logger.info("[SSO] Created user #{user.email} with family #{family.name}")
        user
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[SSO] Failed to create user: #{e.message}")
      nil
    end

    def ensure_onboarded(user, payload)
      attrs = {}

      if user.first_name.blank? || user.first_name == user.email.split("@").first.titleize
        attrs[:first_name] = payload["first_name"] if payload["first_name"].present?
      end
      attrs[:last_name] = payload["last_name"] if user.last_name.blank? && payload["last_name"].present?
      attrs[:onboarded_at] = Time.current if user.onboarded_at.nil?

      family = user.family
      if family
        family.update(locale: payload["locale"]) if payload["locale"].present? && family.locale != payload["locale"]
        family.update(currency: payload["currency"]) if payload["currency"].present? && family.currency != payload["currency"]
        family.update(country: payload["country"]) if payload["country"].present? && family.country != payload["country"]
      end

      user.update!(attrs) if attrs.any?
      Rails.logger.info("[SSO] Ensured onboarding for #{user.email}: #{attrs.keys.join(', ')}") if attrs.any?
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[SSO] Failed to ensure onboarding: #{e.message}")
    end
  end
end

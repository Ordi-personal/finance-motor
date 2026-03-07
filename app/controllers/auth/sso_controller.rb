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
        
        # Find or create user by email
        user = User.find_by(email: payload["email"])
        
        if user.nil?
          # Create user if doesn't exist (for first-time SSO users)
          user = create_sso_user(payload)
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
      User.transaction do
        family = Family.create!(
          name: "#{payload["email"].split("@").first.titleize}'s Family",
          locale: "pt-BR",
          date_format: "%d/%m/%Y",
          currency: "BRL",
          country: "BR"
        )

        # Bootstrap family with default categories and rules
        Saas::InitialDataService.bootstrap!(family)

        user = family.users.create!(
          email: payload["email"],
          first_name: payload["email"].split("@").first.titleize,
          last_name: "",
          password: SecureRandom.hex(16),
          onboarded_at: Time.current,
          role: "admin"
        )
        
        Rails.logger.info("[SSO] Created user #{user.email} with family #{family.name} and default categories")
        user
      end
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error("[SSO] Failed to create user: #{e.message}")
      nil
    end
  end
end

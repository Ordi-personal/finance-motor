module Saas
  # Provisions a fully-onboarded User + Family (categories, rules, trial
  # subscription, optional initial account) for server-to-server callers
  # (e.g. the Ordi app), without going through the SSO/JWT web flow.
  #
  # This intentionally mirrors Auth::SsoController#create_sso_user (same
  # Family/User/InitialDataService/start_trial_subscription! sequence) so
  # that a user provisioned here looks identical to one provisioned via the
  # SSO callback. Extracted as its own service (rather than modifying the
  # SSO controller) so both callers can share the logic additively.
  class UserProvisioningService
    SUPPORTED_CURRENCY = "BRL"
    Result = Struct.new(:user, :family, :account, :created, keyword_init: true)

    def self.provision!(**kwargs)
      new(**kwargs).provision!
    end

    def initialize(email:, first_name: nil, last_name: nil, time_zone: nil, currency: nil, locale: nil, initial_account: nil)
      @email = email.to_s.strip.downcase
      @first_name = first_name.presence || @email.split("@").first.titleize
      @last_name = last_name.presence || ""
      @time_zone = time_zone.presence || "America/Sao_Paulo"
      @currency = currency.presence || "BRL"
      @locale = locale.presence || "pt-BR"
      @initial_account = initial_account.presence
      validate_currency!
      initial_account_currency = @initial_account&.[](:currency) || @initial_account&.[]("currency")
      validate_currency!(initial_account_currency) if initial_account_currency.present?
    end

    def provision!
      existing_user = User.find_by(email: @email)
      return Result.new(user: existing_user, family: existing_user.family, account: nil, created: false) if existing_user

      user = nil
      family = nil

      User.transaction do
        family = Family.create!(
          name: "#{@first_name}'s Family",
          locale: @locale,
          date_format: "%d/%m/%Y",
          currency: @currency,
          country: "BR",
          timezone: @time_zone
        )

        Saas::InitialDataService.bootstrap!(family)

        # See Auth::SsoController#create_sso_user for the rationale: the
        # calling app already ran its own onboarding, so the user should
        # never hit Sure's own trial-activation gate.
        family.start_trial_subscription!

        user = family.users.create!(
          email: @email,
          first_name: @first_name,
          last_name: @last_name,
          password: SecureRandom.hex(16),
          onboarded_at: Time.current,
          role: "admin",
          theme: "light"
        )
      end

      account = create_initial_account!(family, user) if @initial_account

      Result.new(user: user, family: family, account: account, created: true)
    end

    private

      def create_initial_account!(family, user)
        name = @initial_account[:name].presence || "Dinheiro"
        balance = @initial_account[:balance].presence || 0
        currency = @initial_account[:currency].presence || family.currency
        validate_currency!(currency)
        subtype = @initial_account[:subtype].presence || "checking"

        family.accounts.create_and_sync({
          name: name,
          balance: balance,
          currency: currency,
          owner: user,
          accountable_type: "Depository",
          accountable_attributes: { subtype: subtype }
        })
      end

      def validate_currency!(currency = @currency)
        return if currency.to_s.upcase == SUPPORTED_CURRENCY

        raise ArgumentError, "Provisioning supports BRL only; received #{currency}"
      end
  end
end

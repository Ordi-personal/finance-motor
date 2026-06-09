# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src :self, :https
    policy.font_src    :self, :https, :data
    policy.img_src     :self, :https, :data, :blob
    policy.object_src  :none
    policy.script_src  :self, :https
    policy.style_src   :self, :https, :unsafe_inline
    policy.connect_src :self, :https, :wss

    frame_hosts = ENV["FRAME_ANCESTORS_HOSTS"]&.split(",")&.map(&:strip)
    if frame_hosts.present?
      policy.frame_ancestors :self, *frame_hosts
    else
      policy.frame_ancestors :self, "http://localhost:3000"
    end
  end

  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[script-src script-src-elem]
  config.content_security_policy_nonce_auto = true
end

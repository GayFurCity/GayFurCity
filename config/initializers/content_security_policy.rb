# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Define an application-wide content security policy.
# See the Securing Rails Applications Guide for more information:
# https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src(:self)
    if Rails.env.development?
      policy.script_src(:self, :unsafe_inline, :unsafe_eval, "https:")
      policy.connect_src(:self, "https://plausible.furry.computer", "ws://localhost:#{ENV.fetch('EXPOSED_WEBPACKER_PORT', 4003)}")
    else
      policy.script_src(:self, "https://www.google.com/recaptcha/", "https://www.gstatic.com/recaptcha/", "https://www.recaptcha.net/", "https://cdnjs.cloudflare.com", "https://plausible.furry.computer")
      policy.connect_src(:self, "https://plausible.furry.computer")
    end
    policy.style_src(:self, :unsafe_inline, "https://cdnjs.cloudflare.com")
    policy.object_src(:self, GayFurCity.config.cdn_domain)
    policy.media_src(:self, GayFurCity.config.cdn_domain)
    policy.frame_ancestors(:self)
    policy.frame_src(:self, "https://www.google.com/recaptcha/", "https://www.recaptcha.net/")
    policy.font_src(:self)
    policy.img_src(:self, :data, :blob, GayFurCity.config.cdn_domain)
    policy.child_src(:none)
    policy.form_action(:self, "discord.gayfur.city", "discord.com")
    # Specify URI for violation reports
    # policy.report_uri "/csp-violation-report-endpoint"
  end

  # Generate session nonces for permitted importmap and inline scripts
  unless Rails.env.development?
    config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
    config.content_security_policy_nonce_directives = %w[script-src]
  end

  # Report violations without enforcing the policy.
  config.content_security_policy_report_only = false
end
